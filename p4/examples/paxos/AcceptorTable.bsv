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
import MatchTable::*;
import RegFile::*;
import PaxosTypes::*;

interface BasicBlockHandle1A;
   interface BBServer prev_control_state;
endinterface

module mkBasicBlockHandle1A(BasicBlockHandle1A);
   FIFO#(BBRequest) bb_handle_1a_request_fifo <- mkFIFO;
   FIFO#(BBResponse) bb_handle_1a_response_fifo <- mkFIFO;

   interface prev_control_state = (interface BBServer;
      interface request = toPut(bb_handle_1a_request_fifo);
      interface response = toGet(bb_handle_1a_response_fifo);
   endinterface);
endmodule

interface BasicBlockHandle2A;
   interface BBServer prev_control_state;
endinterface

module mkBasicBlockHandle2A(BasicBlockHandle2A);
   FIFO#(BBRequest) bb_handle_2a_request_fifo <- mkFIFO;
   FIFO#(BBResponse) bb_handle_2a_response_fifo <- mkFIFO;

   interface prev_control_state = (interface BBServer;
      interface request = toPut(bb_handle_2a_request_fifo);
      interface response = toGet(bb_handle_2a_response_fifo);
   endinterface);
endmodule

interface BasicBlockDrop;
   interface BBServer prev_control_state;
endinterface

module mkBasicBlockDrop(BasicBlockDrop);
   FIFO#(BBRequest) bb_drop_request_fifo <- mkFIFO;
   FIFO#(BBResponse) bb_drop_response_fifo <- mkFIFO;

   interface prev_control_state = (interface BBServer;
      interface request = toPut(bb_drop_request_fifo);
      interface response = toGet(bb_drop_response_fifo);
   endinterface);
endmodule

interface AcceptorTable;
   interface BBClient next_control_state_0;
   interface BBClient next_control_state_1;
   interface BBClient next_control_state_2;
endinterface

module mkAcceptorTable#(MetadataClient md)(AcceptorTable);
   let verbose = True;

   MatchTable#(256, AcceptorTblReqT, AcceptorTblRespT) matchTable <- mkMatchTable_256_acceptorTable();

   FIFO#(BBRequest) outReqFifo0 <- mkFIFO;
   FIFO#(BBResponse) inRespFifo0 <- mkFIFO;
   FIFO#(BBRequest) outReqFifo1 <- mkFIFO;
   FIFO#(BBResponse) inRespFifo1 <- mkFIFO;
   FIFO#(BBRequest) outReqFifo2 <- mkFIFO;
   FIFO#(BBResponse) inRespFifo2 <- mkFIFO;
   FIFO#(PacketInstance) currPacketFifo <- mkFIFO;
   FIFO#(MetadataT) currMetadataFifo <- mkFIFO;

   rule lookup_request;
      let v <- md.request.get;
      case (v) matches
         tagged AcceptorTblRequest {pkt: .pkt, meta: .meta} : begin
            matchTable.lookupPort.request.put(AcceptorTblReqT { msgtype: fromMaybe(?, meta.msgtype) });
            if (verbose) $display("(%0d) Acceptor: %h", $time, pkt.id, fshow(meta.msgtype));
            currPacketFifo.enq(pkt);
            currMetadataFifo.enq(meta);
         end
      endcase
   endrule

   rule lookup_response;
      let v <- matchTable.lookupPort.response.get;
      let pkt <- toGet(currPacketFifo).get;
      let meta <- toGet(currMetadataFifo).get;
      $display("(%0d) acceptor table lookup", $time);
      if (v matches tagged Valid .resp) begin
         case (resp.act) matches
            Handle1A: begin
               $display("(%0d) execute handle_1a", $time);
               BBRequest req;
               req = tagged BBHandle1aRequest {pkt: pkt};
               outReqFifo0.enq(req);
            end
            Handle2A: begin
               $display("(%0d) execute handle_2a", $time);
               BBRequest req;
               req = tagged BBHandle2aRequest {pkt: pkt};
               outReqFifo1.enq(req);
            end
            Drop: begin
               $display("(%0d) execute drop", $time);
               BBRequest req;
               req = tagged BBDropRequest {pkt: pkt};
               outReqFifo2.enq(req);
            end
            default: begin
               $display("(%0d) not valid action", $time);
            end
         endcase
      end
      MetadataResponse resp = tagged AcceptorTblResponse {pkt: pkt, meta: meta};
      md.response.put(resp);
   endrule

   rule bb_handle_1a_resp;
      let v <- toGet(inRespFifo0).get;
      case (v) matches
         tagged BBHandle1aResponse {pkt: .pkt}: begin
            $display("(%0d) handle_1a: read/write register", $time);
         end
      endcase
   endrule

   rule bb_handle_2a_resp;
      let v <- toGet(inRespFifo1).get;
      case (v) matches
         tagged BBHandle2aResponse {pkt: .pkt}: begin
            $display("(%0d) handle_2a: read/write register", $time);
         end
      endcase
   endrule

   rule bb_drop;
      let v <- toGet(inRespFifo2).get;
      case (v) matches
         tagged BBDropResponse {pkt: .pkt}: begin
            $display("(%0d) drop", $time);
         end
      endcase
   endrule

   interface next_control_state_0 = (interface BBClient;
      interface request = toGet(outReqFifo0);
      interface response = toPut(inRespFifo0);
   endinterface);
   interface next_control_state_1 = (interface BBClient;
      interface request = toGet(outReqFifo1);
      interface response = toPut(inRespFifo1);
   endinterface);
   interface next_control_state_2 = (interface BBClient;
      interface request = toGet(outReqFifo2);
      interface response = toPut(inRespFifo2);
   endinterface);
endmodule
