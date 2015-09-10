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

import BRAMFIFO::*;
import Clocks::*;
import DefaultValue::*;
import FIFO::*;
import FIFOF::*;
import GetPut::*;
import Vector::*;
import Connectable::*;
import StmtFSM::*;
import Pipe::*;

import Ethernet::*;
import IngressPipeline::*;
import PacketBuffer::*;
import Parser::*;
import Types::*;

import Bcam::*;
import M20k::*;

interface P4Pins;
   method Action osc_50(Bit#(1) b3d, Bit#(1) b4a, Bit#(1) b4d, Bit#(1) b7a, Bit#(1) b7d, Bit#(1) b8a, Bit#(1) b8d);
   (* prefix="" *)
   method Action user_reset_n(Bit#(1) user_reset_n);
endinterface

interface P4TopIndication;
   method Action sonic_read_version_resp(Bit#(32) version);
endinterface

interface P4TopRequest;
   method Action sonic_read_version();
   method Action writePacketData(Vector#(2, Bit#(64)) data, Bit#(1) sop, Bit#(1) eop);
   method Action write_m20k(Bit#(12) wAddr, Bit#(5) wData);
   method Action read_m20k_addr(Bit#(9) rAddr);
   method Action read_clear();
endinterface

interface P4Top;
   interface P4TopRequest request;
   interface P4Pins pins;
endinterface

module mkP4Top#(Clock derivedClock, Reset derivedReset, P4TopIndication indication)(P4Top);
   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

   Reg#(Bit#(32)) cycle <- mkReg(0);

   rule every1;
      cycle <= cycle + 1;
   endrule

   PacketBuffer rxPktBuff <- mkPacketBuffer();
   Parser parser <- mkParser();
   Pipeline_port_mapping ingress_port_mapping <- mkIngressPipeline_port_mapping();

   Bcam#(1, 1) bcam <- mkBcam_internal();

   M20k#(5, 40, 4096) m20k <- mkM20k();

   Reg#(Bit#(EtherLen)) pktLen <- mkReg(0);
   FIFOF#(void) readInProgress <- mkFIFOF;
   Reg#(Bit#(9)) rAddr_wires <- mkReg(0);

   rule packetParseStart;
      let pktLen <- rxPktBuff.readServer.readLen.get;
      rxPktBuff.readServer.readReq.put(EtherReq{len: truncate(pktLen)});
      readInProgress.enq(?);
      $display("readPacket %d: pktLen %x", cycle, pktLen);
   endrule

   rule packetParseInProgress if (readInProgress.notEmpty);
      let v <- rxPktBuff.readServer.readData.get;
      $display("inprogress %d:", cycle);
      parser.enqPacketData(v);
      if (v.eop) begin
         $display("eop %d:", cycle);
         readInProgress.deq;
      end
   endrule

   rule matchTableStart;
      let v <- toGet(parser.parseDone).get;
      $display("Parse Done");
      parser.parserReset();
   endrule

   rule forwardPayload;
      let v <- toGet(parser.payloadOut).get;
   endrule

   mkConnection(parser.phvOut, ingress_port_mapping.phvIn);

   Stmt readStmt=
   seq
      action
         m20k.rAddr.enq(rAddr_wires);
      endaction
      action
         let v <- toGet(m20k.rData).get;
         $display("%x: %x", cycle, v);
      endaction
   endseq;

   FSM fsm <- mkFSM(readStmt);
   Once readOnce <- mkOnce(fsm.start);

   interface P4TopRequest request;
      method Action sonic_read_version();
         let v= `NicVersion;
         indication.sonic_read_version_resp(v);
      endmethod
      method Action writePacketData(Vector#(2, Bit#(64)) data, Bit#(1) sop, Bit#(1) eop);
         EtherData beat = defaultValue;
         beat.data = pack(reverse(data));
         beat.sop = unpack(sop);
         beat.eop = unpack(eop);
         rxPktBuff.writeServer.writeData.put(beat);
      endmethod
      // Generate api for each table, meter, etc.
      method Action write_m20k(Bit#(12) wAddr, Bit#(5) wData);
         $display("%x: %x %x", cycle, wAddr, wData);
         m20k.wEnb.enq(True);
         m20k.wAddr.enq(wAddr);
         m20k.wData.enq(wData);
      endmethod
      method Action read_m20k_addr(Bit#(9) rAddr);
         rAddr_wires <= rAddr;
         readOnce.start;
      endmethod
      method Action read_clear();
         readOnce.clear;
      endmethod
      // table entry modify
      // table entry delete
      // get first entry
      // table set default action
      // indirect action data and match select
      // clean all
      // clean table state
      // global table counter
      // meters
      // mirroring api
   endinterface
   interface P4Pins pins;
   endinterface
endmodule
