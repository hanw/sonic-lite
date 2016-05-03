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

interface Ingress;
   interface MemWriteClient#(`DataBusWidth) writeClient;
   interface PipeOut#(MetadataRequest) eventPktSend;
   method Action datapath_id_reg_write(Bit#(DatapathSize) datapath);
   method Action instance_reg_write(Bit#(InstanceSize) instance_);
   method Action role_reg_write(Role r);
   method Action vround_reg_write(Bit#(TLog#(InstanceCount)) inst, Bit#(RoundSize) vround);
   method Action round_reg_write(Bit#(TLog#(InstanceCount)) inst, Bit#(RoundSize) round);
   method Action value_reg_write(Bit#(TLog#(InstanceCount)) inst, Vector#(8, Bit#(32)) value);
   method Action sequenceTable_add_entry(Bit#(16) msgtype, SequenceTblActionT action_);
   method Action acceptorTable_add_entry(Bit#(16) msgtype, AcceptorTblActionT action_);
   method Action dmacTable_add_entry(Bit#(48) mac, Bit#(9) port);
   // Debug
   method IngressDbgRec read_debug_info;
endinterface

module mkIngress#(Vector#(numClients, MetadataClient) mdc)(Ingress);
   let verbose = True;
   Reg#(LUInt) fwdCount <- mkReg(0);
   FIFOF#(MetadataRequest) currPacketFifo <- mkFIFOF;
   FIFO#(MetadataRequest) inReqFifo <- mkFIFO;
   FIFO#(MetadataResponse) outRespFifo <- mkFIFO;

   Vector#(numClients, MetadataServer) metadataServers = newVector;
   for (Integer i=0; i<valueOf(numClients); i=i+1) begin
      metadataServers[i] = (interface MetadataServer;
         interface Put request = toPut(inReqFifo);
         interface Get response = toGet(outRespFifo);
      endinterface);
   end
   mkConnection(mdc, metadataServers);

   // Request/Response Fifos
   FIFO#(MetadataRequest) dmacReqFifo <- mkFIFO;
   FIFO#(MetadataRequest) roleReqFifo <- mkFIFO;
   FIFO#(MetadataRequest) roundReqFifo <- mkFIFO;
   FIFO#(MetadataRequest) sequenceReqFifo <- mkFIFO;
   FIFO#(MetadataRequest) acceptorReqFifo <- mkFIFO;
   // FIFO#(MetadataRequest) dropRequestFifo <- mkFIFO;
   FIFO#(MetadataResponse) dmacRespFifo <- mkFIFO;
   FIFO#(MetadataResponse) roleRespFifo <- mkFIFO;
   FIFO#(MetadataResponse) roundRespFifo <- mkFIFO;
   FIFO#(MetadataResponse) sequenceRespFifo <- mkFIFO;
   FIFO#(MetadataResponse) acceptorRespFifo <- mkFIFO;
   // FIFO#(MetadataResponse) dropResponseFifo <- mkFIFO;

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

   RegisterIfc#(1, SizeOf#(Role)) roleReg <- mkP4Register(vec(bb_read_role.regClient, toGPClient(roleRegReqFifo, roleRegRespFifo)));
   RegisterIfc#(1, DatapathSize) datapathIdReg <- mkP4Register(vec(bb_handle_2a.regClient_datapath_id, bb_handle_1a.regClient_datapath_id, toGPClient(datapathIdRegReqFifo, datapathIdRegRespFifo)));
   RegisterIfc#(1, InstanceSize) instanceReg <- mkP4Register(vec(bb_increase_instance.regClient, toGPClient(instanceRegReqFifo, instanceRegRespFifo)));
   RegisterIfc#(TLog#(InstanceCount), RoundSize) roundReg <- mkP4Register(vec(bb_read_round.regClient, bb_handle_2a.regClient_round, bb_handle_1a.regClient_round, toGPClient(roundRegReqFifo, roundRegRespFifo)));
   RegisterIfc#(TLog#(InstanceCount), RoundSize) vroundReg <- mkP4Register(vec(bb_handle_1a.regClient_vround, bb_handle_2a.regClient_vround, toGPClient(vroundRegReqFifo, vroundRegRespFifo)));
   RegisterIfc#(TLog#(InstanceCount), ValueSize) valueReg <- mkP4Register(vec(bb_handle_1a.regClient_value, bb_handle_2a.regClient_value, toGPClient(valueRegReqFifo, valueRegRespFifo)));

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
   rule start_control_state if (inReqFifo.first matches tagged DefaultRequest {pkt: .pkt, meta: .meta});
      inReqFifo.deq;
   //   if (isValid(meta.valid_ipv4)) begin
   //      MetadataRequest req = tagged DstMacLookupRequest {pkt: pkt, meta: meta};
   //      dmacReqFifo.enq(req);
   //   end
   //endrule

   //rule dmac_tbl_next_control_state if (dmacRespFifo.first matches tagged DstMacResponse {pkt: .pkt, meta: .meta});
   //   dmacRespFifo.deq;
      if (isValid(meta.valid_paxos)) begin
         MetadataRequest req = tagged RoleLookupRequest {pkt: pkt, meta: meta};
         roleReqFifo.enq(req);
      end
      $display("(%0d) Ingress: dmac_tbl next control state", $time);
   endrule

   rule role_tbl_next_control_state if (roleRespFifo.first matches tagged RoleResponse {pkt: .pkt, meta: .meta});
      roleRespFifo.deq;
      if (meta.switch_metadata$role matches tagged Valid .role) begin
         case (role) matches
            ACCEPTOR: begin
               $display("(%0d) Role: Acceptor %h", $time, pkt.id);
               MetadataRequest req = tagged RoundTblRequest {pkt: pkt, meta: meta};
               roundReqFifo.enq(req);
            end
            COORDINATOR: begin
               $display("(%0d) Role: Coordinator %h", $time, pkt.id);
               MetadataRequest req = tagged SequenceTblRequest {pkt: pkt, meta: meta};
               sequenceReqFifo.enq(req);
            end
         endcase
      end
   endrule

   rule sequence_tbl_next_control_state if (sequenceRespFifo.first matches tagged SequenceTblResponse {pkt: .pkt, meta: .meta});
      sequenceRespFifo.deq;
      $display("(%0d) Sequence: fwd %h", $time, pkt.id);
      //FIXME: check action
      MetadataRequest req = tagged ForwardQueueRequest {pkt: pkt, meta: meta};
      currPacketFifo.enq(req);
   endrule

   rule round_tbl_next_control_state if (roundRespFifo.first matches tagged RoundTblResponse {pkt: .pkt, meta: .meta});
      roundRespFifo.deq;
      $display("(%0d) round table response", $time);
      if (meta.paxos_packet_meta$round matches tagged Valid .round) begin
         if (round <= fromMaybe(?, meta.paxos$rnd)) begin
            $display("(%0d) Round: Acceptor %h, round=%h, rnd=%h", $time, pkt.id, round, fromMaybe(?, meta.paxos$rnd));
            MetadataRequest req = tagged AcceptorTblRequest {pkt: pkt, meta: meta};
            acceptorReqFifo.enq(req);
         end
      end
   endrule

   rule acceptor_tbl_next_control_state if (acceptorRespFifo.first matches tagged AcceptorTblResponse {pkt: .pkt, meta: .meta});
      acceptorRespFifo.deq;
      $display("(%0d) Acceptor: fwd ", $time, fshow(meta));
      MetadataRequest req = tagged ForwardQueueRequest {pkt: pkt, meta: meta};
      currPacketFifo.enq(req);
   endrule

   interface writeClient = dstMacTable.writeClient;
   interface eventPktSend = toPipeOut(currPacketFifo);
   method IngressDbgRec read_debug_info();
      return IngressDbgRec {
         fwdCount: fwdCount,
         accTbl: acceptorTable.read_debug_info,
         seqTbl: sequenceTable.read_debug_info,
         dmacTbl: dstMacTable.read_debug_info
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
   method sequenceTable_add_entry = sequenceTable.add_entry;
   method acceptorTable_add_entry = acceptorTable.add_entry;
   method dmacTable_add_entry = dstMacTable.add_entry;
endmodule
