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
import ConfigCounter::*;
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
   let verbose = True;
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
      if (verbose) $display("(%0d) inst = %h", $time, inst.data);
      let next_inst = inst.data + 1;
      instanceReqFifo.enq(InstanceRegRequest {addr: 0, data: next_inst, write:True});
      if (verbose) $display("(%0d) resp = %h", $time, next_inst);
      BBResponse resp = tagged BBIncreaseInstanceResponse {pkt: pkt, inst: next_inst};
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
   FIFO#(MetadataT) bbMetadataFifo <- mkFIFO;

   ConfigCounter#(64) pktIn <- mkConfigCounter(0);
   ConfigCounter#(64) pktOut <- mkConfigCounter(0);

   MatchTable#(0, 256, SizeOf#(SequenceTblReqT), SizeOf#(SequenceTblRespT)) matchTable <- mkMatchTable_256_sequenceTable();

   let acceptor_addr = 'hE0031D48; // 224.3.29.72
   let acceptor_port = 'h8888;     // 34952

    function Bit#(48) mac_from_ip(Bit#(32) ip_addr);
        Bit#(23) bits_ip = ip_addr[22:0];
        Bit#(24) lower_part = zeroExtend(bits_ip);
        Bit#(24) upper_part = 'h01005E;
        return {upper_part, lower_part};
    endfunction

   rule lookup_request;
      let v <- md.request.get;
      let meta = v.meta;
      let pkt = v.pkt;
      // Update address and port
      meta.dstIP = tagged Valid acceptor_addr;
      meta.dstPort = tagged Valid acceptor_port;
      meta.dstAddr = tagged Valid mac_from_ip(acceptor_addr);

      SequenceTblReqT req = SequenceTblReqT {msgtype: fromMaybe(?, meta.paxos$msgtype), padding:0};
      matchTable.lookupPort.request.put(pack(req));
      if (verbose) $display("(%0d) Sequence: %h", $time, pkt.id, fshow(meta.paxos$msgtype));
      currPacketFifo.enq(pkt);
      currMetadataFifo.enq(meta);
      pktIn.increment(1);
   endrule

   rule lookup_response;
      let v <- matchTable.lookupPort.response.get;
      let pkt <- toGet(currPacketFifo).get;
      let meta <- toGet(currMetadataFifo).get;
      if (verbose) $display("(%0d) sequence table lookup ", $time, fshow(v));
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
         bbMetadataFifo.enq(meta);
      end
      else begin
         if(verbose) $display("(%0d) invalid lookup sequence table", $time);
      end
   endrule

   rule bb_increase_instance_resp;
      let v <- toGet(inRespFifo).get;
      let meta <- toGet(bbMetadataFifo).get;
      case (v) matches
         tagged BBIncreaseInstanceResponse {pkt: .pkt, inst: .inst}: begin
            if (verbose) $display("(%0d) increase instance: %h", $time, inst);
            meta.paxos$inst = tagged Valid inst;
            MetadataResponse meta_resp = MetadataResponse {pkt: pkt, meta: meta};
            $display("(%0d) seq metadata", $time, fshow(meta));
            md.response.put(meta_resp);
            pktOut.increment(1);
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
      return TableDbgRec { pktIn: pktIn.read(), pktOut: pktOut.read() };
   endmethod
endmodule
