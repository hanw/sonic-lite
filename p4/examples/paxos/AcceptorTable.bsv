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
import ConnectalTypes::*;

interface BasicBlockHandle1A;
   interface BBServer prev_control_state;
   interface DatapathIdRegClient regClient_datapath_id;
   interface VRoundRegClient regClient_vround;
   interface ValueRegClient regClient_value;
   interface RoundRegClient regClient_round;
endinterface

module mkBasicBlockHandle1A(BasicBlockHandle1A);
   FIFO#(BBRequest) bb_handle_1a_request_fifo <- mkFIFO;
   FIFO#(BBResponse) bb_handle_1a_response_fifo <- mkFIFO;
   FIFO#(PacketInstance) curr_packet_fifo <- mkFIFO;

   FIFO#(DatapathIdRegRequest) reg_datapath_request_fifo <- mkFIFO;
   FIFO#(DatapathIdRegResponse) reg_datapath_response_fifo <- mkFIFO;
   FIFO#(VRoundRegRequest) reg_vround_request_fifo <- mkFIFO;
   FIFO#(VRoundRegResponse) reg_vround_response_fifo <- mkFIFO;
   FIFO#(ValueRegRequest) reg_value_request_fifo <- mkFIFO;
   FIFO#(ValueRegResponse) reg_value_response_fifo <- mkFIFO;
   FIFO#(RoundRegRequest) reg_round_request_fifo <- mkFIFO;
   FIFO#(RoundRegResponse) reg_round_response_fifo<- mkFIFO;

   rule bb_handle1a;
      let v <- toGet(bb_handle_1a_request_fifo).get;
      case (v) matches
         tagged BBHandle1aRequest {pkt: .pkt, inst: .inst, rnd: .rnd} : begin
            // register_read
            VRoundRegRequest vround_req;
            vround_req = VRoundRegRequest {addr: inst, data: ?, write: False};
            reg_vround_request_fifo.enq(vround_req);
            // register_read
            ValueRegRequest value_req;
            value_req = ValueRegRequest {addr: inst, data: ?, write: False};
            reg_value_request_fifo.enq(value_req);
            // register_read
            DatapathIdRegRequest datapath_req;
            datapath_req = DatapathIdRegRequest {addr: 0, data: ?, write: False};
            reg_datapath_request_fifo.enq(datapath_req);
            // register_write
            RoundRegRequest round_req;
            round_req = RoundRegRequest {addr: inst, data: rnd, write: True};
            reg_round_request_fifo.enq(round_req);
            // current packet
            curr_packet_fifo.enq(pkt);
         end
      endcase
   endrule

   rule reg_resp;
      let datapath <- toGet(reg_datapath_response_fifo).get;
      let vround <- toGet(reg_vround_response_fifo).get;
      let value <- toGet(reg_value_response_fifo).get;
      let pkt <- toGet(curr_packet_fifo).get;
      BBResponse resp = tagged BBHandle1aResponse {pkt: pkt, datapath: datapath.data,
                                                   vround: vround.data, value: value.data};
      bb_handle_1a_response_fifo.enq(resp);
   endrule

   interface prev_control_state = (interface BBServer;
      interface request = toPut(bb_handle_1a_request_fifo);
      interface response = toGet(bb_handle_1a_response_fifo);
   endinterface);
   interface regClient_datapath_id = (interface DatapathIdRegClient;
      interface request = toGet(reg_datapath_request_fifo);
      interface response = toPut(reg_datapath_response_fifo);
   endinterface);
   interface regClient_vround = (interface VRoundRegClient;
      interface request = toGet(reg_vround_request_fifo);
      interface response = toPut(reg_vround_response_fifo);
   endinterface);
   interface regClient_value = (interface ValueRegClient;
      interface request = toGet(reg_value_request_fifo);
      interface response = toPut(reg_value_response_fifo);
   endinterface);
   interface regClient_round = (interface RoundRegClient;
      interface request = toGet(reg_round_request_fifo);
      interface response = toPut(reg_round_response_fifo);
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
            matchTable.lookupPort.request.put(AcceptorTblReqT { msgtype: fromMaybe(?, meta.paxos$msgtype) });
            if (verbose) $display("(%0d) Acceptor: %h ", $time, pkt.id, fshow(meta.paxos$msgtype));
            currPacketFifo.enq(pkt);
            currMetadataFifo.enq(meta);
         end
      endcase
   endrule

   rule lookup_response;
      let v <- matchTable.lookupPort.response.get;
      let pkt <- toGet(currPacketFifo).get;
      let meta <- toGet(currMetadataFifo).get;
      $display("(%0d) acceptor table lookup ", $time, fshow(v));
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
