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

// Generate Top.bsv
typedef struct {
   Bit#(32) param1;
   Bit#(32) param2;
} MatchTableParam deriving (Bits, Eq);

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

   method Action portmapping_add_entry(Bit#(32) table_name, MatchTableParam match_field);
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
      // Generate fixed standard set of API function
      // In software, we should hide the details of match table different behind api
      // expose thrift-server to software to take advantage of existing thrift infra.
      // expose raw connectal cpp generated interface to test application.
      method Action table_name_add_entry(Bit#(32) table_name, MatchTableParam match_field);

      endmethod
      // -- Internal of API depends on P4 program.
      // -- Use dispatcher to send table info to corresponding table.
      // -- Invalid table tag will result in error.
   endinterface
   interface P4Pins pins;
   endinterface
endmodule
