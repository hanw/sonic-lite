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

import ClientServer::*;
import DbgTypes::*;
import Ethernet::*;
import FIFO::*;
import GetPut::*;
import GenericMatchTable::*;
import PacketTypes::*;
import TdmTypes::*;

interface IPv4Route;
   interface Client#(MetadataRequest, MetadataResponse) next;
   interface Put#(TableEntry) add_entry;
   interface Put#(FlowId) delete_entry;
   interface Put#(Tuple2#(FlowId, ActionArg)) modify_entry;
   interface Get#(FlowId) entry_added;
   method IPv4RouteDbgRec dbg;
   method MatchTableDbgRec mdbg;
endinterface

module mkIPv4Route#(Client#(MetadataRequest, MetadataResponse) md)(IPv4Route);
   let verbose = True;

   Reg#(Bit#(64)) lookupCnt <- mkReg(0);
   Reg#(Bit#(64)) matchCnt <- mkReg(0);
   Reg#(Bit#(64)) missCnt <- mkReg(0);
   MatchTable#(256, 36) matchTable <- mkMatchTable();

   FIFO#(MetadataRequest) outReqFifo <- mkFIFO;
   FIFO#(MetadataResponse) inRespFifo <- mkFIFO;
   FIFO#(PacketInstance) currPacketFifo <- mkFIFO;

   rule tableLookupRequest;
      let v <- md.request.get;
      case (v) matches
         tagged RouteLookupRequest {pkt: .pkt, dstip: .ipv4}: begin
            matchTable.lookupPort.request.put(MatchField{dstip:ipv4});
            currPacketFifo.enq(pkt);
            lookupCnt <= lookupCnt + 1;
            if (verbose) $display("TDM:: enqueuePkt: %h %h %h", pkt.id, ipv4);
         end
         default: begin
            $display ("IPv4Route: Unhandled Packet, drop or punt!");
         end
      endcase
   endrule

   rule tableLookupResponse;
      let v <- matchTable.lookupPort.response.get;
      let pkt <- toGet(currPacketFifo).get;
      $display("TDM:: bcam matches %h", v);
      MetadataRequest nextReq = tagged ModifyMacRequest {pkt: pkt, mac: 'h123456789abc}; // mac lookup
      outReqFifo.enq(nextReq);
   endrule

   interface add_entry = matchTable.add_entry;
   interface delete_entry = matchTable.delete_entry;
   interface modify_entry = matchTable.modify_entry;
   interface entry_added = matchTable.entry_added;
   interface next = (interface Client#(MetadataRequest, MetadataResponse);
      interface request = toGet(outReqFifo);
      interface response = toPut(inRespFifo);
   endinterface);
   method IPv4RouteDbgRec dbg;
      return IPv4RouteDbgRec {lookupCnt: lookupCnt};
   endmethod
   method mdbg = matchTable.dbg;
endmodule
