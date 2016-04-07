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

interface BasicBlockIncreaseInstance;
   interface BBServer prev_control_state;
endinterface

module mkBasicBlockIncreaseInstance(BasicBlockIncreaseInstance);
   FIFO#(BBRequest) bb_increase_instance_request_fifo <- mkFIFO;
   FIFO#(BBResponse) bb_increase_instance_response_fifo <- mkFIFO;

   rule bb_increase_instance;
      let v <- toGet(bb_increase_instance_request_fifo).get;
      case (v) matches
         tagged BBIncreaseInstanceRequest {pkt: .pkt}: begin
            // read-modify-write register
            BBResponse resp = tagged BBIncreaseInstanceResponse {pkt: pkt};
            bb_increase_instance_response_fifo.enq(resp);
         end
      endcase
   endrule

   interface prev_control_state = (interface BBServer;
      interface request = toPut(bb_increase_instance_request_fifo);
      interface response = toGet(bb_increase_instance_response_fifo);
   endinterface);
endmodule

interface SequenceTable;
   interface BBClient next_control_state_0;
endinterface

module mkSequenceTable#(MetadataClient md)(SequenceTable);
   let verbose = True;

   FIFO#(BBRequest) outReqFifo <- mkFIFO;
   FIFO#(BBResponse) inRespFifo <- mkFIFO;
   FIFO#(PacketInstance) currPacketFifo <- mkFIFO;
   FIFO#(MetadataT) currMetadataFifo <- mkFIFO;

   // sequence match table?? only one-entry, register will suffice.

   rule lookup;
      let v <- md.request.get;
      case (v) matches
         tagged SequenceTblRequest { pkt: .pkt, meta: .meta } : begin
            BBRequest req;
            req = tagged BBIncreaseInstanceRequest {pkt: pkt};
            outReqFifo.enq(req);
            currMetadataFifo.enq(meta);
            currPacketFifo.enq(pkt);
         end
      endcase
   endrule

   rule lookup_resp;
      let v <- toGet(inRespFifo).get;
      let pkt <- toGet(currPacketFifo).get;
      let meta <- toGet(currMetadataFifo).get;
      MetadataResponse resp = tagged SequenceTblResponse {pkt: pkt, meta: meta};
      md.response.put(resp);
   endrule

   interface next_control_state_0 = (interface BBClient;
      interface request = toGet(outReqFifo);
      interface response = toPut(inRespFifo);
   endinterface);
endmodule
