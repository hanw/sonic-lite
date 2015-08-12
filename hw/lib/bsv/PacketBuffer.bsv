// Copyright (c) 2015 Cornell University.

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

package PacketBuffer;

import BRAM::*;
import Clocks::*;
import Connectable::*;
import FShow::*;
import FIFO::*;
import FIFOF::*;
import GetPut::*;
import Pipe::*;
import SpecialFIFOs::*;
import Vector::*;

import Ethernet::*;

interface PktWriteServer;
   interface Put#(EtherData) writeData;
endinterface

interface PktReadServer;
   interface Get#(EtherData) readData;
   interface Get#(Bit#(EtherLen)) readLen;
   interface Put#(EtherReq) readReq;
endinterface

interface PacketBuffer;
   interface PktWriteServer writeServer;
   interface PktReadServer readServer;
endinterface

module mkPacketBuffer(PacketBuffer);
   Clock current_clock <- exposeCurrentClock;
   Reset current_reset <- exposeCurrentReset;

   let verbose = False;

   Reg#(Bit#(32))  cycle <- mkReg(0);
   // Mac
   Wire#(Bit#(64))              data        <- mkWire;
   Wire#(Bool)                  valid       <- mkWire;
   Wire#(Bool)                  sop         <- mkWire;
   Wire#(Bool)                  eop         <- mkWire;
   Wire#(Bool)                  goodFrame   <- mkWire;
   Wire#(Bool)                  badFrame    <- mkWire;

   Reg#(Bit#(PktAddrWidth))     wrCurrPtr   <- mkReg(0);
   Reg#(Bit#(EtherLen))         packetLen   <- mkReg(0);
   Reg#(Bool)                   inPacket    <- mkReg(False);

   // Memory
   BRAM_Configure bramConfig = defaultValue;
   bramConfig.latency = 1;
   BRAM2Port#(Bit#(PktAddrWidth), EtherData) memBuffer <- mkBRAM2Server(bramConfig);

   FIFO#(EtherData) fifoWriteData <- mkFIFO;
   FIFOF#(Bit#(EtherLen)) fifoEop <- mkFIFOF;
   FIFO#(ReqTup) incomingReqs     <- mkFIFO;

   // Client
   Reg#(Bit#(PktAddrWidth))     rdCurrPtr   <- mkReg(0);
   Reg#(Bool)                   outPacket   <- mkReg(False);

   FIFOF#(Bit#(EtherLen))    fifoLen     <- mkSizedFIFOF(16);
   FIFOF#(Bit#(EtherLen))    fifoReadReq <- mkSizedFIFOF(4);
   FIFOF#(EtherData)         fifoReadData <- mkBypassFIFOF();

   rule every1;
      cycle <= cycle + 1;
   endrule

   rule enq_stage1;
      EtherData d <- toGet(fifoWriteData).get;
      incomingReqs.enq(ReqTup{addr: wrCurrPtr, data:d});
      wrCurrPtr <= wrCurrPtr + 1;
      Bit#(EtherLen) newPacketLen = packetLen + 1;
      if (d.eop) begin
         fifoEop.enq(newPacketLen);
         packetLen <= 0;
      end
      else begin
         packetLen <= newPacketLen;
      end
   endrule

   rule enqueue_first_beat(!inPacket);
      ReqTup req <- toGet(incomingReqs).get;
      if (verbose) $display("PacketBuffer::enqueue_first_beat %d", cycle, fshow(req));
      memBuffer.portA.request.put(BRAMRequest{write:True, responseOnWrite:False,
         address:req.addr, datain:req.data});
      inPacket <= True;
   endrule

   rule enqueue_next_beat(!fifoEop.notEmpty && inPacket);
      ReqTup req <- toGet(incomingReqs).get;
      if (verbose) $display("PacketBuffer::enqueue_next_beat %d", cycle, fshow(req));
      memBuffer.portA.request.put(BRAMRequest{write:True, responseOnWrite:False,
         address:req.addr, datain:req.data});
   endrule

   rule commit_packet(fifoEop.notEmpty && inPacket);
      ReqTup req <- toGet(incomingReqs).get;
      if (verbose) $display("PacketBuffer::commit_packet %d", cycle, fshow(req));
      memBuffer.portA.request.put(BRAMRequest{write:True, responseOnWrite:False,
         address:req.addr, datain:req.data});
      let v <- toGet(fifoEop).get;
      fifoLen.enq(v << 4); // beats to bytes
      inPacket <= False;
   endrule

   rule dequeue_first_beat(!outPacket);
      let v <- toGet(fifoReadReq).get;
      if (verbose) $display("PacketBuffer::dequeue_first_beat %d: %x %x", cycle, rdCurrPtr, v);
      memBuffer.portB.request.put(BRAMRequest{write:False, responseOnWrite:False,
         address:truncate(rdCurrPtr), datain:?});
      outPacket <= True;
      rdCurrPtr <= rdCurrPtr + 1;
   endrule

   rule dequeue_next_beat(outPacket);
      let d <- memBuffer.portB.response.get;
      fifoReadData.enq(d);
      if (d.eop) begin
         outPacket <= False;
      end
      else begin
         memBuffer.portB.request.put(BRAMRequest{write:False, responseOnWrite:False,
            address:truncate(rdCurrPtr), datain:?});
         rdCurrPtr <= rdCurrPtr + 1;
      end
      if (verbose) $display("PacketBuffer::dequeue_next_beat %d: %x %x", cycle, rdCurrPtr, d);
   endrule

   interface PktWriteServer writeServer;
      interface Put writeData;
         method Action put(EtherData d);
            if (verbose) $display("PacketBuffer::writeData %d: Packet data %x", cycle, d.data);
            fifoWriteData.enq(d);
         endmethod
      endinterface
   endinterface
   interface PktReadServer readServer;
      interface Get readData;
         method ActionValue#(EtherData) get if (fifoReadData.notEmpty);
            let v = fifoReadData.first;
            fifoReadData.deq;
            return v;
         endmethod
      endinterface
      interface Get readLen;
         method ActionValue#(Bit#(EtherLen)) get if (fifoLen.notEmpty);
            let v = fifoLen.first;
            fifoLen.deq;
            return v;
         endmethod
      endinterface
      interface Put readReq;
         method Action put(EtherReq r);
            fifoReadReq.enq(r.len);
         endmethod
      endinterface
   endinterface
endmodule

endpackage: PacketBuffer
