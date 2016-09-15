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

import AcceptorTable::*;
import BuildVector::*;
import ClientServer::*;
import Connectable::*;
import ConnectalTypes::*;
import DbgTypes::*;
import DbgDefs::*;
import DstMacTable::*;
import DropTable::*;
import Ethernet::*;
import FIFO::*;
import FIFOF::*;
import GetPut::*;
import MemTypes::*;
import PaxosTypes::*;
import Pipe::*;
import RegFile::*;
import Register::*;
import RoleTable::*;
import RoundTable::*;
import SequenceTable::*;
import Vector::*;
`include "ConnectalProjectConfig.bsv"

interface Ingress;
   interface MemWriteClient#(`DataBusWidth) writeClient;
   interface Client#(MetadataRequest, MetadataResponse) next;
   interface Get#(Role) role_reg_read_resp;
   method Action datapath_id_reg_write(Bit#(DatapathSize) datapath);
   method Action instance_reg_write(Bit#(InstanceSize) instance_);
   method Action role_reg_write(Role r);
   method Action role_reg_read();
   method Action vround_reg_write(Bit#(TLog#(InstanceCount)) inst, Bit#(RoundSize) vround);
   method Action round_reg_write(Bit#(TLog#(InstanceCount)) inst, Bit#(RoundSize) round);
   method Action value_reg_write(Bit#(TLog#(InstanceCount)) inst, Vector#(8, Bit#(32)) value);
   method Action sequenceTable_add_entry(Bit#(16) msgtype, SequenceTblActionT action_);
   method Action acceptorTable_add_entry(Bit#(16) msgtype, AcceptorTblActionT action_);
   method Action dmacTable_add_entry(Bit#(48) mac, Bit#(9) port);
   // Debug
   method IngressDbgRec read_debug_info;
   method IngressPerfRec read_perf_info;
endinterface

module mkIngress#(Vector#(numClients, MetadataClient) mdc)(Ingress);
   let verbose = True;
   Reg#(LUInt) fwdCount <- mkReg(0);
   FIFOF#(MetadataRequest) currPacketFifo <- mkFIFOF;
   FIFOF#(MetadataRequest) inReqFifo <- mkFIFOF;
   FIFOF#(MetadataResponse) outRespFifo <- mkFIFOF;

   Vector#(numClients, MetadataServer) metadataServers = newVector;
   for (Integer i=0; i<valueOf(numClients); i=i+1) begin
      metadataServers[i] = (interface MetadataServer;
         interface Put request = toPut(inReqFifo);
         interface Get response = toGet(outRespFifo);
      endinterface);
   end
   mkConnection(mdc, metadataServers);

   // Request/Response Fifos
   FIFOF#(MetadataRequest) dmacReqFifo <- mkFIFOF;
   FIFOF#(MetadataRequest) roleReqFifo <- mkFIFOF;
   FIFOF#(MetadataRequest) roundReqFifo <- mkFIFOF;
   FIFOF#(MetadataRequest) sequenceReqFifo <- mkFIFOF;
   FIFOF#(MetadataRequest) acceptorReqFifo <- mkFIFOF;
   FIFOF#(MetadataResponse) dmacRespFifo <- mkFIFOF;
   FIFOF#(MetadataResponse) roleRespFifo <- mkFIFOF;
   FIFOF#(MetadataResponse) roundRespFifo <- mkFIFOF;
   FIFOF#(MetadataResponse) sequenceRespFifo <- mkFIFOF;
   FIFOF#(MetadataResponse) acceptorRespFifo <- mkFIFOF;

   FIFOF#(MetadataRequest) next_req_ff <- mkFIFOF;
   FIFOF#(MetadataResponse) next_rsp_ff <- mkFIFOF;

   Reg#(Bit#(32)) clk_cnt <- mkReg(0);
   Reg#(Bit#(32)) ingress_start_time <- mkReg(0);
   Reg#(Bit#(32)) ingress_end_time <- mkReg(0);
   Reg#(Bit#(32)) acceptor_start_time <- mkReg(0);
   Reg#(Bit#(32)) acceptor_end_time <- mkReg(0);
   Reg#(Bit#(32)) sequence_start_time <- mkReg(0);
   Reg#(Bit#(32)) sequence_end_time <- mkReg(0);
   rule clockrule;
      clk_cnt <= clk_cnt + 1;
   endrule

   // Tables
   DstMacTable dstMacTable <- mkDstMacTable(toGPClient(dmacReqFifo, dmacRespFifo));
   RoleTable roleTable <- mkRoleTable(toGPClient(roleReqFifo, roleRespFifo));
   RoundTable roundTable <- mkRoundTable(toGPClient(roundReqFifo, roundRespFifo));
   SequenceTable sequenceTable <- mkSequenceTable(toGPClient(sequenceReqFifo, sequenceRespFifo));
   AcceptorTable acceptorTable <- mkAcceptorTable(toGPClient(acceptorReqFifo, acceptorRespFifo));
   //DropTable dropTable <- mkDropTable();//roundTable.next1);

   // BasicBlocks
   BasicBlockForward bb_fwd <- mkBasicBlockForward();
   BasicBlockIncreaseInstance bb_increase_instance <- mkBasicBlockIncreaseInstance();
   BasicBlockHandle1A bb_handle_1a <- mkBasicBlockHandle1A();
   BasicBlockHandle2A bb_handle_2a <- mkBasicBlockHandle2A();
   BasicBlockDrop bb_handle_drop <- mkBasicBlockDrop();
   BasicBlockRound bb_read_round <- mkBasicBlockRound();
   BasicBlockRole bb_read_role <- mkBasicBlockRole();

   // Registers
   FIFO#(RoundRegRequest) roundRegReqFifo <- mkFIFO;
   FIFO#(RoleRegRequest) roleRegReqFifo <- mkFIFO;
   FIFO#(DatapathIdRegRequest) datapathIdRegReqFifo <- mkFIFO;
   FIFO#(InstanceRegRequest) instanceRegReqFifo <- mkFIFO;
   FIFO#(VRoundRegRequest) vroundRegReqFifo <- mkFIFO;
   FIFO#(ValueRegRequest) valueRegReqFifo <- mkFIFO;

   FIFO#(RoundRegResponse) roundRegRespFifo <- mkFIFO;
   FIFO#(RoleRegResponse) roleRegRespFifo <- mkFIFO;
   FIFO#(DatapathIdRegResponse) datapathIdRegRespFifo <- mkFIFO;
   FIFO#(InstanceRegResponse) instanceRegRespFifo <- mkFIFO;
   FIFO#(VRoundRegResponse) vroundRegRespFifo <- mkFIFO;
   FIFO#(ValueRegResponse) valueRegRespFifo <- mkFIFO;

   FIFO#(Role) roleRegReadFifo <- mkFIFO;
   rule readRole;
      let v <- toGet(roleRegRespFifo).get;
      roleRegReadFifo.enq(unpack(v.data));
   endrule

   //Vector#(1, Client#(RoleRegRequest, RoleRegResponse)) role_clients = newVector();
   //role_clients[0] = bb_read_role.regClient;
   //role_clients[1] = toGPClient(roleRegReqFifo, roleRegRespFifo);
   //RegisterIfc#(1, SizeOf#(Role)) roleReg <- mkP4Register(role_clients);
   // zipWithM_(mkConnection, role_clients, roleReg.servers);
   let roleReg <- mkP4Register(vec(bb_read_role.regClient, toGPClient(roleRegReqFifo, roleRegRespFifo)));
   let datapathIdReg <- mkP4Register(vec(bb_handle_2a.regClient_datapath_id, bb_handle_1a.regClient_datapath_id, toGPClient(datapathIdRegReqFifo, datapathIdRegRespFifo)));
   let instanceReg <- mkP4Register(vec(bb_increase_instance.regClient, toGPClient(instanceRegReqFifo, instanceRegRespFifo)));
   let roundReg <- mkP4Register(vec(bb_read_round.regClient, bb_handle_2a.regClient_round, bb_handle_1a.regClient_round, toGPClient(roundRegReqFifo, roundRegRespFifo)));
   let vroundReg <- mkP4Register(vec(bb_handle_1a.regClient_vround, bb_handle_2a.regClient_vround, toGPClient(vroundRegReqFifo, vroundRegRespFifo)));
   let valueReg <- mkP4Register(vec(bb_handle_1a.regClient_value, bb_handle_2a.regClient_value, toGPClient(valueRegReqFifo, valueRegRespFifo)));

   // Connect Table with BasicBlock
   mkConnection(dstMacTable.next_control_state_0, bb_fwd.prev_control_state);
   mkConnection(sequenceTable.next_control_state_0, bb_increase_instance.prev_control_state);
   mkConnection(acceptorTable.next_control_state_0, bb_handle_1a.prev_control_state);
   mkConnection(acceptorTable.next_control_state_1, bb_handle_2a.prev_control_state);
   mkConnection(acceptorTable.next_control_state_2, bb_handle_drop.prev_control_state);
   mkConnection(roundTable.next_control_state_0, bb_read_round.prev_control_state);
   mkConnection(roleTable.next_control_state_0, bb_read_role.prev_control_state);

   // Resolve rule conflicts
   (* descending_urgency ="sequence_tbl_next_control_state, acceptor_tbl_next_control_state" *)

   // Control Flow
   rule start_control_state if (inReqFifo.notEmpty);
      let _req = inReqFifo.first;
      let pkt = _req.pkt;
      let meta = _req.meta;
      inReqFifo.deq;
      ingress_start_time <= clk_cnt;
   //   if (isValid(meta.valid_ipv4)) begin
   //      MetadataRequest req = tagged DstMacLookupRequest {pkt: pkt, meta: meta};
   //      dmacReqFifo.enq(req);
   //   end
   //endrule

   //rule dmac_tbl_next_control_state if (dmacRespFifo.first matches tagged DstMacResponse {pkt: .pkt, meta: .meta});
   //   dmacRespFifo.deq;
      if (isValid(meta.valid_paxos)) begin
         MetadataRequest req = MetadataRequest {pkt: pkt, meta: meta};
         roleReqFifo.enq(req);
      end
      $display("(%0d) Ingress: dmac_tbl next control state", $time);
   endrule

   rule role_tbl_next_control_state if (roleRespFifo.notEmpty);
      let rsp = roleRespFifo.first;
      let meta = rsp.meta;
      let pkt = rsp.pkt;
      roleRespFifo.deq;
      if (meta.switch_metadata$role matches tagged Valid .role) begin
         case (role) matches
            ACCEPTOR: begin
               $display("(%0d) Role: Acceptor %h", $time, pkt.id);
               MetadataRequest req = MetadataRequest {pkt: pkt, meta: meta};
               roundReqFifo.enq(req);
               acceptor_start_time <= clk_cnt;
            end
            COORDINATOR: begin
               $display("(%0d) Role: Coordinator %h", $time, pkt.id);
               MetadataRequest req = MetadataRequest {pkt: pkt, meta: meta};
               sequenceReqFifo.enq(req);
               sequence_start_time <= clk_cnt;
            end
            FORWARDER: begin
               $display("(%0d) Role: Forwarder %h", $time, pkt.id);
               MetadataRequest req = MetadataRequest {pkt: pkt, meta: meta};
               currPacketFifo.enq(req);
            end
         endcase
      end
   endrule

   rule sequence_tbl_next_control_state if (sequenceRespFifo.notEmpty);
      let rsp = sequenceRespFifo.first;
      let meta = rsp.meta;
      let pkt = rsp.pkt;
      sequenceRespFifo.deq;
      sequence_end_time <= clk_cnt;
      $display("(%0d) Sequence: fwd %h", $time, pkt.id);
      //FIXME: check action
      MetadataRequest req = MetadataRequest {pkt: pkt, meta: meta};
      currPacketFifo.enq(req);
   endrule

   rule round_tbl_next_control_state if (roundRespFifo.notEmpty);
      let rsp = roundRespFifo.first;
      let meta = rsp.meta;
      let pkt = rsp.pkt;
      roundRespFifo.deq;
      $display("(%0d) round table response", $time);
      if (meta.paxos_packet_meta$round matches tagged Valid .round) begin
         if (round <= fromMaybe(?, meta.paxos$rnd)) begin
            $display("(%0d) Round: Acceptor %h, round=%h, rnd=%h", $time, pkt.id, round, fromMaybe(?, meta.paxos$rnd));
            MetadataRequest req = MetadataRequest {pkt: pkt, meta: meta};
            acceptorReqFifo.enq(req);
         end
      end
   endrule

   rule acceptor_tbl_next_control_state if (acceptorRespFifo.notEmpty);
      let rsp = acceptorRespFifo.first;
      acceptorRespFifo.deq;
      let meta = rsp.meta;
      let pkt = rsp.pkt;
      acceptor_end_time <= clk_cnt;
      $display("(%0d) Acceptor: fwd ", $time, fshow(meta));
      MetadataRequest req = MetadataRequest {pkt: pkt, meta: meta};
      next_req_ff.enq(req);
   endrule

   interface writeClient = dstMacTable.writeClient;
   interface next = (interface Client#(MetadataRequest, MetadataResponse);
      interface request = toGet(next_req_ff);
      interface response = toPut(next_rsp_ff);
   endinterface);
   method IngressDbgRec read_debug_info();
      return IngressDbgRec {
         fwdCount: fwdCount,
         accTbl: acceptorTable.read_debug_info,
         seqTbl: sequenceTable.read_debug_info,
         dmacTbl: dstMacTable.read_debug_info
      };
   endmethod
   method IngressPerfRec read_perf_info();
      return IngressPerfRec {
         ingress_start_time: ingress_start_time,
         ingress_end_time: ingress_end_time,
         acceptor_start_time: acceptor_start_time,
         acceptor_end_time: acceptor_end_time,
         sequence_start_time: sequence_start_time,
         sequence_end_time: sequence_end_time
      };
   endmethod
   method Action round_reg_write(Bit#(TLog#(InstanceCount)) inst, Bit#(RoundSize) round);
      RoundRegRequest req = RoundRegRequest {addr: inst, data: round, write: True};
      roundRegReqFifo.enq(req);
   endmethod
   method Action vround_reg_write(Bit#(TLog#(InstanceCount)) inst, Bit#(RoundSize) round);
      VRoundRegRequest req = VRoundRegRequest {addr: inst, data: round, write: True};
      vroundRegReqFifo.enq(req);
   endmethod
   method Action role_reg_write(Role role);
      RoleRegRequest req = RoleRegRequest {addr: 0, data: pack(role), write: True};
      roleRegReqFifo.enq(req);
   endmethod
   method Action datapath_id_reg_write(Bit#(DatapathSize) datapath);
      DatapathIdRegRequest req = DatapathIdRegRequest {addr: 0, data: datapath, write: True};
      datapathIdRegReqFifo.enq(req);
   endmethod
   method Action instance_reg_write(Bit#(InstanceSize) instance_);
      InstanceRegRequest req = InstanceRegRequest {addr: 0, data: instance_, write: True};
      instanceRegReqFifo.enq(req);
   endmethod
   method Action value_reg_write(Bit#(TLog#(InstanceCount)) inst, Vector#(8, Bit#(32)) value);
      ValueRegRequest req = ValueRegRequest {addr: inst, data: pack(value), write: True};
      valueRegReqFifo.enq(req);
   endmethod
   method Action role_reg_read();
      RoleRegRequest req = RoleRegRequest {addr: 0, data: ?, write: False};
      roleRegReqFifo.enq(req);
   endmethod
   interface role_reg_read_resp = toGet(roleRegReadFifo);
   method sequenceTable_add_entry = sequenceTable.add_entry;
   method acceptorTable_add_entry = acceptorTable.add_entry;
   method dmacTable_add_entry = dstMacTable.add_entry;
endmodule
