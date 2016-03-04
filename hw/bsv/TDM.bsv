// Copyright (c) 2016 Cornell University.

// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Vector::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import BRAM::*;
import GetPut::*;
import DefaultValue::*;
import Clocks::*;

import DbgTypes::*;
import Ethernet::*;
import GenericMatchTable::*;
import MemTypes::*;
import PacketTypes::*;
import PacketBuffer::*;
import Pipe::*;
import SharedBuff::*;
import SharedBuffMMU::*;
import StoreAndForward::*;
import TdmTypes::*;
import TxChannel::*;

`ifndef SIMULATION
import AlteraMacWrap::*;
import EthMac::*;
import AlteraEthPhy::*;
import DE5Pins::*;
`else
import Sims::*;
`endif

typedef 16 NumOfHosts;
typedef 8 SlotLen;

typedef struct {
   Bit#(TLog#(NumOfHosts)) host;
   PktId id;
   Bit#(32) dstip;
   Bit#(EtherLen) size;
} FQWriteRequest deriving(Bits, Eq);

typedef struct {
   Bit#(TLog#(NumOfHosts)) host;
} FQReadRequest deriving(Bits, Eq);

typedef struct {
   PktId id;
   Bit#(32) dstip;
   Bit#(EtherLen) size;
} FQReadResp deriving(Bits, Eq);

typedef struct {
   PktId id;
   Bool ready;
} FQReady deriving(Bits, Eq);

interface TimeSlot;
   interface Get#(Bit#(TLog#(NumOfHosts))) currSlot;
endinterface

module mkTimeSlot(TimeSlot);
   Reg#(Bit#(32)) global_count <- mkReg(0);
   Reg#(Bit#(TLog#(NumOfHosts))) last_slot <- mkReg(0);
   FIFO#(Bit#(TLog#(NumOfHosts))) slot_fifo <- mkFIFO;

   rule increment;
      global_count <= global_count + 1;
   endrule

   function Bit#(TLog#(NumOfHosts)) get_slot (Bit#(32) v);
      let l = fromInteger(valueOf(TLog#(SlotLen)));
      Vector#(TLog#(NumOfHosts), Bit#(1)) slot = takeAt(l, unpack(v));
      return pack(slot);
   endfunction

   rule genNewSlot;
      let v = get_slot(global_count);
      if (v != last_slot) begin
         slot_fifo.enq(v);
         last_slot <= v;
      end
   endrule

   interface Get currSlot = toGet(slot_fifo);
endmodule

// Write stores packet id to per-host queue for scheduling
// Read returns packet id to be transmitted immediately
interface ForwardQ;
   interface Put#(FQWriteRequest) req_w;
   interface Put#(FQReadRequest) req_r;
   interface Get#(FQReadResp) resp_r;
endinterface

module mkForwardQ(ForwardQ);
   // Forward queue as name implies
   Vector#(NumOfHosts, FIFOF#(FQReadResp)) fwdFifo <- replicateM(mkSizedFIFOF(16));
   // ReadyFifo marks fwdFifo as ready to dequeue
   // It serves as synchronization between queueing and packet modification pipeline
   Vector#(NumOfHosts, FIFOF#(FQReady)) readyFifo <- replicateM(mkSizedFIFOF(16));
   FIFO#(FQReadResp) resp_fifo <- mkFIFO;

   interface Put req_w;
      method Action put(FQWriteRequest req);
         let hostIdx = req.host;
         fwdFifo[hostIdx].enq(FQReadResp{id: req.id, dstip: req.dstip, size: req.size});
      endmethod
   endinterface
   interface Put req_r;
      method Action put(FQReadRequest req);
         let hostIdx = req.host;
         if (fwdFifo[hostIdx].notEmpty) begin
            let v = fwdFifo[hostIdx].first;
            resp_fifo.enq(FQReadResp{id: v.id, dstip: v.dstip, size: v.size});
            fwdFifo[hostIdx].deq;
         end
         else begin
            if (fwdFifo[0].notEmpty) begin
               let v = fwdFifo[0].first;
               resp_fifo.enq(FQReadResp{id: v.id, dstip: v.dstip, size: v.size});
               fwdFifo[0].deq;
            end
         end
      endmethod
   endinterface
   interface Get resp_r = toGet(resp_fifo);
endmodule

interface TDM;
   // input egress
   method TDMDbgRec dbg;
endinterface

module mkTDM#(Client#(MetadataRequest, MetadataResponse) md, TxChannel tx)(TDM);
// TDM with packetEgress
   let verbose = False;

   Reg#(Bit#(32)) cycle <- mkReg(0);
   rule cycleRule if (verbose);
      cycle <= cycle + 1;
   endrule

   Reg#(Bit#(64)) fwdReqCnt <- mkReg(0);
   Reg#(Bit#(64)) sendCnt <- mkReg(0);

   TimeSlot timeSlot <- mkTimeSlot();
   ForwardQ fwdq <- mkForwardQ();

   rule insertQueue;
      let v <- md.request.get;
      case (v) matches
         tagged QueueRequest {pkt: .pkt, queue: .queue, port: .port} : begin
            if (verbose) $display("TDM: id=%h, size=%d, queue=%h, port=%h", pkt.id, pkt.size, queue, port);
            FQWriteRequest req = FQWriteRequest {host: 0, id: pkt.id, size: pkt.size, dstip: 0};
            fwdq.req_w.put(req);
            fwdReqCnt <= fwdReqCnt + 1;
         end
      endcase
   endrule

   rule slotRequest;
      let slot <- timeSlot.currSlot.get;
      fwdq.req_r.put(FQReadRequest{host:slot});
   endrule

   rule dequeuePacketInstance;
      let resp <- fwdq.resp_r.get;
      tx.eventPktSend.enq(PacketInstance{id: resp.id, size: resp.size});
      if (verbose) $display("TDM:: %d dequeuePkt: %h %h", cycle, resp.id, resp.size);
      if (verbose) $display("TDM:: %d dequeuePkt: %h", cycle, resp.dstip);
      sendCnt <= sendCnt + 1;
   endrule

   method TDMDbgRec dbg;
      return TDMDbgRec{fwdReqCnt: fwdReqCnt, sendCnt: sendCnt};
   endmethod
endmodule


