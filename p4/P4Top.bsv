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

import Ethernet::*;
import IngressPipeline::*;
import PacketBuffer::*;
import Parser::*;
import Types::*;

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
   method Action ipv4_table_add_with_on_miss(Bit#(16) data);
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

   Reg#(Bit#(EtherLen)) pktLen <- mkReg(0);
   FIFOF#(void) readInProgress <- mkFIFOF;

   rule packetParseStart;
      let pktLen <- rxPktBuff.readServer.readLen.get;
      rxPktBuff.readServer.readReq.put(EtherReq{len: truncate(pktLen)});
      readInProgress.enq(?);
      $display("readPacket %d: pktLen %x", cycle, pktLen);
   endrule

   //FIXME: instead of sending entire packet to parser, only send header to parser.
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
      method Action ipv4_table_add_with_on_miss(Bit#(16) data);
         $display("table add on miss");
         MatchEntry entry = defaultValue;
         entry.dlEtherType = data;
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
