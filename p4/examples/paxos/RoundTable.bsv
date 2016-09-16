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
import RegFile::*;
import DefaultValue::*;
import PaxosTypes::*;
import ConnectalTypes::*;
import Register::*;

interface BasicBlockRound;
   interface BBServer prev_control_state;
   interface Client#(RoundRegRequest, RoundRegResponse) regClient;
endinterface

module mkBasicBlockRound(BasicBlockRound);
   FIFO#(BBRequest) bb_round_request_fifo <- mkFIFO;
   FIFO#(BBResponse) bb_round_response_fifo <- mkFIFO;
   FIFO#(RoundRegRequest) reg_round_request_fifo <- mkFIFO;
   FIFO#(RoundRegResponse) reg_round_response_fifo <- mkFIFO;
   FIFO#(PacketInstance) curr_packet_fifo <- mkFIFO;

   rule bb_round;
      let v <- toGet(bb_round_request_fifo).get;
      case (v) matches
         tagged BBRoundRequest {pkt: .pkt, paxos$inst: .inst}: begin
            RoundRegRequest req;
            req = RoundRegRequest{addr: truncate(inst), data: ?, write: False};
            reg_round_request_fifo.enq(req);
            curr_packet_fifo.enq(pkt);
         end
      endcase
   endrule

   rule reg_resp;
      let v <- toGet(reg_round_response_fifo).get;
      let pkt <- toGet(curr_packet_fifo).get;
      IngressMetadataT d = defaultValue;
      d.rnd = v.data;
      //FIXME: remove pkt??
      BBResponse resp = tagged BBRoundResponse {pkt: pkt, ingress_metadata: d};
      bb_round_response_fifo.enq(resp);
   endrule

   interface prev_control_state = (interface BBServer;
      interface request = toPut(bb_round_request_fifo);
      interface response = toGet(bb_round_response_fifo);
   endinterface);
   interface regClient = (interface Client#(RoundRegRequest, RoundRegResponse);
      interface request = toGet(reg_round_request_fifo);
      interface response = toPut(reg_round_response_fifo);
   endinterface);
endmodule

interface RoundTable;
   interface BBClient next_control_state_0;
endinterface

module mkRoundTable#(MetadataClient md)(RoundTable);
   FIFO#(BBRequest) outReqFifo <- mkFIFO;
   FIFO#(BBResponse) inRespFifo <- mkFIFO;
   FIFO#(MetadataT) currMetadataFifo <- mkFIFO;

   rule readRound;
      let v <- md.request.get;
      let meta = v.meta;
      let pkt = v.pkt;
      BBRequest req = tagged BBRoundRequest {pkt: pkt, paxos$inst: fromMaybe(?, meta.paxos$inst)};
      $display("(%0d) Round: read inst %h", $time, fromMaybe(?, meta.paxos$inst));
      outReqFifo.enq(req);
      currMetadataFifo.enq(meta);
   endrule

   rule readRoundResp;
      let v <- toGet(inRespFifo).get;
      let meta <- toGet(currMetadataFifo).get;
      if (v matches tagged BBRoundResponse {pkt: .pkt, ingress_metadata: .ingress_meta}) begin
         $display("(%0d) Round Response: ", $time, fshow(ingress_meta));
         meta.paxos_packet_meta$rnd = tagged Valid ingress_meta.rnd;
         MetadataResponse resp = MetadataResponse {pkt: pkt, meta: meta};
         md.response.put(resp);
      end
   endrule
   interface next_control_state_0 = (interface BBClient;
      interface request = toGet(outReqFifo);
      interface response = toPut(inRespFifo);
   endinterface);
endmodule

