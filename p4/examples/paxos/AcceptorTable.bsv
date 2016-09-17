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
import FIFOF::*;
import GetPut::*;
import MatchTable::*;
import RegFile::*;
import Register::*;
import PaxosTypes::*;
import Utils::*;
import Vector::*;

interface BasicBlockHandle1A;
   interface BBServer prev_control_state;
   interface DatapathIdRegClient regClient_datapath_id;
   interface VRoundRegClient regClient_vround;
   interface ValueRegClient regClient_value;
   interface RoundRegClient regClient_round;
endinterface

module mkBasicBlockHandle1A(BasicBlockHandle1A);
   FIFO#(BBRequest) bb_handle_1a_request_fifo <- mkSizedFIFO(1);
   FIFO#(BBResponse) bb_handle_1a_response_fifo <- mkSizedFIFO(1);
   FIFO#(PacketInstance) curr_packet_fifo <- mkSizedFIFO(1);

   FIFO#(DatapathIdRegRequest) datapathIdReqFifo <- mkSizedFIFO(1);
   FIFO#(DatapathIdRegResponse) datapathIdRespFifo <- mkSizedFIFO(1);
   FIFO#(VRoundRegRequest) vroundReqFifo <- mkSizedFIFO(1);
   FIFO#(VRoundRegResponse) vroundRespFifo <- mkSizedFIFO(1);
   FIFO#(ValueRegRequest) valueReqFifo <- mkSizedFIFO(1);
   FIFO#(ValueRegResponse) valueRespFifo <- mkSizedFIFO(1);
   FIFO#(RoundRegRequest) roundReqFifo <- mkSizedFIFO(1);
   FIFO#(RoundRegResponse) roundRespFifo<- mkSizedFIFO(1);

   rule bb_handle1a;
      let v <- toGet(bb_handle_1a_request_fifo).get;
      case (v) matches
         tagged BBHandle1aRequest {pkt: .pkt, inst: .inst, rnd: .rnd} : begin
            vroundReqFifo.enq(VRoundRegRequest {addr: truncate(inst), data: ?, write: False});
            valueReqFifo.enq(ValueRegRequest {addr: truncate(inst), data: ?, write: False});
            datapathIdReqFifo.enq(DatapathIdRegRequest {addr: 0, data: ?, write: False});
            roundReqFifo.enq(RoundRegRequest {addr: truncate(inst), data: rnd, write: True});
            curr_packet_fifo.enq(pkt);
         end
      endcase
   endrule

   rule reg_resp;
      let datapath <- toGet(datapathIdRespFifo).get;
      let vround <- toGet(vroundRespFifo).get;
      let value <- toGet(valueRespFifo).get;
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
      interface request = toGet(datapathIdReqFifo);
      interface response = toPut(datapathIdRespFifo);
   endinterface);
   interface regClient_vround = (interface VRoundRegClient;
      interface request = toGet(vroundReqFifo);
      interface response = toPut(vroundRespFifo);
   endinterface);
   interface regClient_value = (interface ValueRegClient;
      interface request = toGet(valueReqFifo);
      interface response = toPut(valueRespFifo);
   endinterface);
   interface regClient_round = (interface RoundRegClient;
      interface request = toGet(roundReqFifo);
      interface response = toPut(roundRespFifo);
   endinterface);
endmodule

interface BasicBlockHandle2A;
   interface BBServer prev_control_state;
   interface DatapathIdRegClient regClient_datapath_id;
   interface VRoundRegClient regClient_vround;
   interface ValueRegClient regClient_value;
   interface RoundRegClient regClient_round;
endinterface

module mkBasicBlockHandle2A(BasicBlockHandle2A);
   let verbose = False;
   FIFO#(BBRequest) bb_handle_2a_request_fifo <- mkSizedFIFO(1);
   FIFO#(BBResponse) bb_handle_2a_response_fifo <- mkSizedFIFO(1);
   FIFO#(PacketInstance) curr_packet_fifo <- mkSizedFIFO(1);

   FIFO#(DatapathIdRegRequest) datapathIdReqFifo <- mkSizedFIFO(1);
   FIFO#(DatapathIdRegResponse) datapathIdRespFifo <- mkSizedFIFO(1);
   FIFO#(VRoundRegRequest) vroundReqFifo <- mkSizedFIFO(1);
   FIFO#(VRoundRegResponse) vroundRespFifo <- mkSizedFIFO(1);
   FIFO#(ValueRegRequest) valueReqFifo <- mkSizedFIFO(1);
   FIFO#(ValueRegResponse) valueRespFifo <- mkSizedFIFO(1);
   FIFO#(RoundRegRequest) roundReqFifo <- mkSizedFIFO(1);
   FIFO#(RoundRegResponse) roundRespFifo<- mkSizedFIFO(1);

   rule bb_handle2a;
      let v <- toGet(bb_handle_2a_request_fifo).get;
      if (verbose) $display("(%0d) handle_2a bb_request", $time);
      case (v) matches
         tagged BBHandle2aRequest {pkt: .pkt, inst: .inst, rnd: .rnd, paxosval: .paxosval}: begin
            if (verbose) $display("(%0d) handle_2a bb_request %h %h %h", $time, inst, rnd, paxosval);
            roundReqFifo.enq(RoundRegRequest {addr: truncate(inst), data: rnd, write: True});
            vroundReqFifo.enq(VRoundRegRequest {addr: truncate(inst), data: rnd, write: True});
            valueReqFifo.enq(ValueRegRequest {addr: truncate(inst), data: paxosval, write: True});
            datapathIdReqFifo.enq(DatapathIdRegRequest {addr: 0, data: ?, write: False});
            curr_packet_fifo.enq(pkt);
         end
         default: begin
            if (verbose) $display("(%0d) Not valid request", $time);
         end
      endcase
   endrule

   rule reg_resp;
      let pkt <- toGet(curr_packet_fifo).get;
      let datapath <- toGet(datapathIdRespFifo).get;
      BBResponse resp = tagged BBHandle2aResponse {pkt: pkt, datapath: datapath.data};
      if (verbose) $display("(%0d) handle2A response datapath=%h", $time, datapath.data);
      bb_handle_2a_response_fifo.enq(resp);
   endrule

   interface prev_control_state = (interface BBServer;
      interface request = toPut(bb_handle_2a_request_fifo);
      interface response = toGet(bb_handle_2a_response_fifo);
   endinterface);
   interface regClient_datapath_id = (interface DatapathIdRegClient;
      interface request = toGet(datapathIdReqFifo);
      interface response = toPut(datapathIdRespFifo);
   endinterface);
   interface regClient_vround = (interface VRoundRegClient;
      interface request = toGet(vroundReqFifo);
      interface response = toPut(vroundRespFifo);
   endinterface);
   interface regClient_value = (interface ValueRegClient;
      interface request = toGet(valueReqFifo);
      interface response = toPut(valueRespFifo);
   endinterface);
   interface regClient_round = (interface RoundRegClient;
      interface request = toGet(roundReqFifo);
      interface response = toPut(roundRespFifo);
   endinterface);
endmodule

interface BasicBlockDrop;
   interface BBServer prev_control_state;
endinterface

module mkBasicBlockDrop(BasicBlockDrop);
   FIFO#(BBRequest) bb_drop_request_fifo <- mkSizedFIFO(1);
   FIFO#(BBResponse) bb_drop_response_fifo <- mkSizedFIFO(1);

   interface prev_control_state = (interface BBServer;
      interface request = toPut(bb_drop_request_fifo);
      interface response = toGet(bb_drop_response_fifo);
   endinterface);
endmodule

interface AcceptorTable;
   interface BBClient next_control_state_0;
   interface BBClient next_control_state_1;
   interface BBClient next_control_state_2;
   method Action add_entry(Bit#(16) msgtype, AcceptorTblActionT action_);
   // Debug
   method TableDbgRec read_debug_info();
endinterface

module mkAcceptorTable#(MetadataClient md)(AcceptorTable);
   let verbose = True;

   MatchTable#(0, 256, SizeOf#(AcceptorTblReqT), SizeOf#(AcceptorTblRespT)) matchTable <- mkMatchTable_256_acceptorTable();

   Vector#(3, FIFOF#(BBRequest)) bbReqFifo <- replicateM(mkFIFOF());
   Vector#(3, FIFOF#(BBResponse)) bbRespFifo <- replicateM(mkFIFOF());
   Vector#(3, Bool) readyBits = map(fifoNotEmpty, bbRespFifo);
   Bool interruptStatus = False;
   Bit#(16) readyChannel = -1;

   for (Integer i = 2; i>=0; i=i-1) begin
      if (readyBits[i]) begin
         interruptStatus = True;
         readyChannel = fromInteger(i);
      end
   end

   FIFO#(PacketInstance) currPacketFifo <- mkFIFO;
   FIFO#(MetadataT) currMetadataFifo <- mkFIFO;
   FIFO#(MetadataT) bbMetadataFifo <- mkFIFO;

   ConfigCounter#(64) pktIn <- mkConfigCounter(0);
   ConfigCounter#(64) pktOut <- mkConfigCounter(0);

   let learner_addr = 'hE0031D49; // 224.3.29.73
   let learner_port = 'h8889;     // 34953

    function Bit#(48) mac_from_ip(Bit#(32) ip_addr);
        Bit#(23) bits_ip = ip_addr[22:0];
        Bit#(24) lower_part = zeroExtend(bits_ip);
        Bit#(24) upper_part = 'h01005E;
        return {upper_part, lower_part};
    endfunction

   rule lookup_request;
      let v <- md.request.get;
      let meta = v.meta;
      // Update address and port
      // meta.dstIP = tagged Valid learner_addr;
      // meta.dstAddr = tagged Valid mac_from_ip(learner_addr);
      meta.dstPort = tagged Valid learner_port;

      let pkt = v.pkt;
      AcceptorTblReqT req = AcceptorTblReqT {msgtype: fromMaybe(?, meta.paxos$msgtype), padding:0};
      matchTable.lookupPort.request.put(pack(req));
      if (verbose) $display("(%0d) Acceptor: %h ", $time, pkt.id, fshow(meta.paxos$msgtype));
      currPacketFifo.enq(pkt);
      currMetadataFifo.enq(meta);
      pktIn.increment(1);
   endrule

   rule lookup_response;
      let v <- matchTable.lookupPort.response.get;
      let pkt <- toGet(currPacketFifo).get;
      let meta <- toGet(currMetadataFifo).get;
      if (verbose) $display("(%0d) acceptor table lookup ", $time, fshow(v));
      if (v matches tagged Valid .data) begin
         AcceptorTblRespT resp = unpack(data);
         case (resp.act) matches
            Handle1A: begin
               if (verbose) $display("(%0d) execute handle_1a", $time);
               BBRequest req;
               req = tagged BBHandle1aRequest {pkt: pkt,
                                               inst: fromMaybe(?, meta.paxos$inst),
                                               rnd: fromMaybe(?, meta.paxos$rnd)};
               bbReqFifo[0].enq(req);
            end
            Handle2A: begin
               if (verbose) $display("(%0d) execute handle_2a", $time);
               BBRequest req;
               req = tagged BBHandle2aRequest {pkt: pkt,
                                               inst: fromMaybe(?, meta.paxos$inst),
                                               rnd: fromMaybe(?, meta.paxos$rnd),
                                               valuelen: fromMaybe(?, meta.paxos$valuelen),
                                               paxosval: fromMaybe(?, meta.paxos$paxosval)};
               bbReqFifo[1].enq(req);
            end
            Drop: begin
               if (verbose) $display("(%0d) execute drop", $time);
               BBRequest req;
               req = tagged BBDropRequest {pkt: pkt};
               bbReqFifo[2].enq(req);
            end
            default: begin
               if (verbose) $display("(%0d) not valid action %h", $time, resp.act);
            end
         endcase
         bbMetadataFifo.enq(meta);
      end
      else begin
         //FIXME: handle exception, punt or drop?
      end
   endrule

   rule bb_handle_resp if (interruptStatus);
      let v <- toGet(bbRespFifo[readyChannel]).get;
      let meta <- toGet(bbMetadataFifo).get;
      case (v) matches
         tagged BBHandle1aResponse {pkt: .pkt, datapath: .dp, vround: .vrnd, value: .value}: begin
            if (verbose) $display("(%0d) handle_1a: read/write register", $time);
            meta.paxos$msgtype = tagged Valid zeroExtend(pack(PAXOS_1B));
            meta.paxos$vrnd = tagged Valid vrnd;
            meta.paxos$paxosval = tagged Valid value;
            meta.paxos$acptid = tagged Valid dp;
            MetadataResponse meta_resp = MetadataResponse {pkt: pkt, meta: meta};
            md.response.put(meta_resp);
            pktOut.increment(1);
         end
         tagged BBHandle2aResponse {pkt: .pkt, datapath: .dp}: begin
            if (verbose) $display("(%0d) handle_2a: read/write register", $time);
            meta.paxos$msgtype = tagged Valid zeroExtend(pack(PAXOS_2B));
            meta.paxos$acptid = tagged Valid dp;
            MetadataResponse meta_resp = MetadataResponse {pkt: pkt, meta: meta};
            md.response.put(meta_resp);
            pktOut.increment(1);
         end
         tagged BBDropResponse {pkt: .pkt}: begin
            if (verbose) $display("(%0d) drop", $time);
            MetadataResponse meta_resp = MetadataResponse {pkt: pkt, meta: meta};
            md.response.put(meta_resp);
            pktOut.increment(1);
         end
         default: begin
            $display("(%0d) Unexpected response type on channel %h ", $time, readyChannel, fshow(v));
         end
      endcase
   endrule

   interface next_control_state_0 = (interface BBClient;
      interface request = toGet(bbReqFifo[0]);
      interface response = toPut(bbRespFifo[0]);
   endinterface);
   interface next_control_state_1 = (interface BBClient;
      interface request = toGet(bbReqFifo[1]);
      interface response = toPut(bbRespFifo[1]);
   endinterface);
   interface next_control_state_2 = (interface BBClient;
      interface request = toGet(bbReqFifo[2]);
      interface response = toPut(bbRespFifo[2]);
   endinterface);
   method Action add_entry(Bit#(16) msgtype, AcceptorTblActionT action_);
      AcceptorTblReqT req = AcceptorTblReqT {msgtype: msgtype, padding: 0};
      AcceptorTblRespT resp = AcceptorTblRespT {act: action_};
      if (verbose) $display("(%0d) acceptor resp=%h", $time, pack(resp));
      matchTable.add_entry.put(tuple2(pack(req), pack(resp)));
   endmethod
   method TableDbgRec read_debug_info();
      return TableDbgRec {
         pktIn: pktIn.read(),
         pktOut: pktOut.read()
      };
   endmethod
endmodule
