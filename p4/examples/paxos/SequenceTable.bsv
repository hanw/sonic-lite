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
import ConnectalTypes::*;
import DbgTypes::*;
import DbgDefs::*;
import Ethernet::*;
import FIFO::*;
import GetPut::*;
import MatchTable::*;
import PaxosTypes::*;
import RegFile::*;
import Register::*;

interface BasicBlockIncreaseInstance;
   interface BBServer prev_control_state;
   interface InstanceRegClient regClient;
endinterface

module mkBasicBlockIncreaseInstance(BasicBlockIncreaseInstance);
   let verbose = False;
   FIFO#(BBRequest) bbIncrInstRequest <- mkFIFO;
   FIFO#(BBResponse) bbIncrInstResponse <- mkFIFO;
   FIFO#(PacketInstance) curr_packet_fifo <- mkFIFO;

   FIFO#(InstanceRegRequest) instanceReqFifo <- mkFIFO;
   FIFO#(InstanceRegResponse) instanceRespFifo <- mkFIFO;

   (* descending_urgency ="bb_increase_instance, reg_resp" *)
   rule bb_increase_instance if (bbIncrInstRequest.first matches tagged BBIncreaseInstanceRequest .v);
      bbIncrInstRequest.deq;
      instanceReqFifo.enq(InstanceRegRequest {addr: 0, data: ?, write: False});
      curr_packet_fifo.enq(v.pkt);
   endrule

   rule reg_resp;
      let pkt <- toGet(curr_packet_fifo).get;
      let inst <- toGet(instanceRespFifo).get;
      if (verbose) $display("(%0d) inst = %h", inst.data);
      let next_inst = inst.data + 1;
      instanceReqFifo.enq(InstanceRegRequest {addr: 0, data: next_inst, write:True});
      BBResponse resp = tagged BBIncreaseInstanceResponse {pkt: pkt};
      bbIncrInstResponse.enq(resp);
   endrule

   interface prev_control_state = (interface BBServer;
      interface request = toPut(bbIncrInstRequest);
      interface response = toGet(bbIncrInstResponse);
   endinterface);
   interface regClient = (interface InstanceRegClient;
      interface request = toGet(instanceReqFifo);
      interface response = toPut(instanceRespFifo);
   endinterface);
endmodule

interface SequenceTable;
   interface BBClient next_control_state_0;
   // MetadataClient PipeIn
   //interface PipeIn#(Metadata) md;
   method Action add_entry(Bit#(16) msgtype, SequenceTblActionT action_);
   // Debug
   method TableDbgRec read_debug_info();
endinterface

// FIXME: fix interface to allow synthesis boundary
module mkSequenceTable#(MetadataClient md)(SequenceTable);
   let verbose = True;

   FIFO#(BBRequest) outReqFifo <- mkFIFO;
   FIFO#(BBResponse) inRespFifo <- mkFIFO;
   FIFO#(PacketInstance) currPacketFifo <- mkFIFO;
   FIFO#(MetadataT) currMetadataFifo <- mkFIFO;

   Array #(Reg #(LUInt)) pktIn <- mkCReg(2, 0);
   Array #(Reg #(LUInt)) pktOut <- mkCReg(2, 0);

   MatchTable#(256, SizeOf#(SequenceTblReqT), SizeOf#(SequenceTblRespT)) matchTable <- mkMatchTable_256_sequenceTable();

   rule lookup_request;
      let v <- md.request.get;
      case (v) matches
         tagged SequenceTblRequest { pkt: .pkt, meta: .meta } : begin
            SequenceTblReqT req = SequenceTblReqT {msgtype: fromMaybe(?, meta.paxos$msgtype), padding:0};
            matchTable.lookupPort.request.put(pack(req));
            if (verbose) $display("(%0d) Sequence: %h", $time, pkt.id, fshow(meta.paxos$msgtype));
            currPacketFifo.enq(pkt);
            currMetadataFifo.enq(meta);
            pktIn[0] <= pktIn[0] + 1;
         end
      endcase
   endrule

   rule lookup_response;
      let v <- matchTable.lookupPort.response.get;
      let pkt <- toGet(currPacketFifo).get;
      let meta <- toGet(currMetadataFifo).get;
      if (v matches tagged Valid .data) begin
         SequenceTblRespT resp = unpack(data);
         case (resp.act) matches
            IncreaseInstance: begin
               if (verbose) $display("(%0d) increase instance", $time);
               BBRequest req;
               req = tagged BBIncreaseInstanceRequest {pkt: pkt};
               outReqFifo.enq(req);
            end
            default: begin
               if (verbose) $display("(%0d) nop", $time);
            end
         endcase
      end
      MetadataResponse meta_resp = tagged SequenceTblResponse {pkt: pkt, meta: meta};
      md.response.put(meta_resp);
      pktOut[0] <= pktOut[0] + 1;
   endrule

   rule bb_increase_instance_resp;
      let v <- toGet(inRespFifo).get;
      case (v) matches
         tagged BBIncreaseInstanceResponse {pkt: .pkt}: begin
            if (verbose) $display("(%0d) TODO: increase instance: ", $time);
         end
      endcase
   endrule

   interface next_control_state_0 = (interface BBClient;
      interface request = toGet(outReqFifo);
      interface response = toPut(inRespFifo);
   endinterface);
   method Action add_entry(Bit#(16) msgtype, SequenceTblActionT action_);
      SequenceTblReqT req = SequenceTblReqT {msgtype: msgtype, padding: 0};
      SequenceTblRespT resp = SequenceTblRespT {act: action_};
      matchTable.add_entry.put(tuple2(pack(req), pack(resp)));
   endmethod
   method TableDbgRec read_debug_info;
      return TableDbgRec { pktIn: pktIn[1], pktOut: pktOut[1] };
   endmethod
endmodule
