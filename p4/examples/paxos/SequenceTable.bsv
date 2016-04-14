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

   MatchTable#(256, SequenceTblReqT, SequenceTblRespT) matchTable <- mkMatchTable_256_sequenceTable();

   rule lookup;
      let v <- md.request.get;
      case (v) matches
         tagged SequenceTblRequest { pkt: .pkt, meta: .meta } : begin
            matchTable.lookupPort.request.put(SequenceTblReqT {msgtype: fromMaybe(?, meta.msgtype)});
            if (verbose) $display("(%0d) Sequence: %h", $time, pkt.id, fshow(meta.msgtype));
            currPacketFifo.enq(pkt);
            currMetadataFifo.enq(meta);
         end
      endcase
   endrule

   rule lookup_resp;
      let v <- matchTable.lookupPort.response.get;
      let pkt <- toGet(currPacketFifo).get;
      let meta <- toGet(currMetadataFifo).get;
      if (v matches tagged Valid .resp) begin
         case (resp.act) matches
            IncreaseInstance: begin
               $display("(%0d) increase instance", $time);
               BBRequest req;
               req = tagged BBIncreaseInstanceRequest {pkt: pkt};
               outReqFifo.enq(req);
            end
            default: begin
               $display("(%d) nop", $time);
            end
         endcase
      end
      MetadataResponse resp = tagged SequenceTblResponse {pkt: pkt, meta: meta};
      md.response.put(resp);
   endrule

   rule bb_increase_instance_resp;
      let v <- toGet(inRespFifo).get;
      case (v) matches
         tagged BBIncreaseInstanceResponse {pkt: .pkt}: begin
            $display("(%0d) increase instance: ", $time);
         end
      endcase
   endrule

   interface next_control_state_0 = (interface BBClient;
      interface request = toGet(outReqFifo);
      interface response = toPut(inRespFifo);
   endinterface);
endmodule
