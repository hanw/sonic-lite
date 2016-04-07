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
import PaxosTypes::*;
import RegFile::*;
import DefaultValue::*;

interface BasicBlockRound;
   interface BBServer prev_control_state;
endinterface

module mkBasicBlockRound(BasicBlockRound);
   FIFO#(BBRequest) bb_round_request_fifo <- mkFIFO;
   FIFO#(BBResponse) bb_round_response_fifo <- mkFIFO;

   rule bb_round;
      let v <- toGet(bb_round_request_fifo).get;
      case (v) matches
         tagged BBRoundRequest {pkt: .pkt, paxos$inst: .inst}: begin
            IngressMetadataT d = defaultValue;
            // use inst to read round register.
            BBResponse resp = tagged BBRoundResponse {pkt: pkt, ingress_metadata: d};
            bb_round_response_fifo.enq(resp);
         end
      endcase
   endrule
endmodule

interface RoundTable;
   interface Client#(RoundRegRequest, RoundRegResponse) regAccess;
   interface BBClient next_control_state;
endinterface

module mkRoundTable#(MetadataClient md)(RoundTable);
   FIFO#(BBRequest) outReqFifo <- mkFIFO;
   FIFO#(BBResponse) inRespFifo <- mkFIFO;
   FIFO#(PacketInstance) currPacketFifo <- mkFIFO;
   FIFO#(MetadataT) currMetadataFifo <- mkFIFO;

   rule readRound;
      let v <- md.request.get;
      case (v) matches
         tagged RoundTblRequest {pkt: .pkt, meta: .meta}: begin
            BBRequest req;
            req = tagged BBRoundRequest {pkt: pkt, paxos$inst: meta.paxos$inst};
            outReqFifo.enq(req);
            currPacketFifo.enq(pkt);
            currMetadataFifo.enq(meta);
         end
      endcase
   endrule

   rule readRoundResp;
      let v <- toGet(inRespFifo).get;
      let meta <- toGet(currMetadataFifo).get;
      let pkt <- toGet(currPacketFifo).get;
      // update metadata
      MetadataResponse resp;
      resp = tagged RoundTblResponse {pkt: pkt, meta: meta};
      md.response.put(resp);
   endrule
endmodule

