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
import ClientServer::*;
import Connectable::*;
import DbgTypes::*;
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
import RoleTable::*;
import RoundTable::*;
import SequenceTable::*;
import Vector::*;
import BuildVector::*;
import ConnectalTypes::*;

interface Ingress;
   interface MemWriteClient#(`DataBusWidth) writeClient;
   interface PipeOut#(PacketInstance) eventPktSend;
   method IngressPipelineDbgRec dbg;
   method Action datapath_id_reg_write(Bit#(64) datapath);
   method Action instance_reg_write(Bit#(16) instance_);
   method Action vround_reg_write(Bit#(InstanceSize) inst, Bit#(RoundSize) round);
   method Action round_reg_write(Bit#(16) r);
   method Action role_reg_write(Role r);
   method Action sequenceTable_add_entry(Bit#(16) msgtype, SequenceTblActionT action_);
   method Action acceptorTable_add_entry(Bit#(16) msgtype, AcceptorTblActionT action_);
   method Action dmacTable_add_entry(Bit#(48) mac, Bit#(9) port);
endinterface

module mkIngress#(Vector#(numClients, MetadataClient) mdc)(Ingress);
   let verbose = True;
   Reg#(Bit#(64)) fwdCount <- mkReg(0);
   FIFOF#(PacketInstance) currPacketFifo <- mkFIFOF;
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

   // MetadataClients
   function MetadataClient toMetadataClient(FIFO#(MetadataRequest) reqFifo,
                                            FIFO#(MetadataResponse) respFifo);
      MetadataClient ret_ifc;
      ret_ifc = (interface MetadataClient;
         interface Get request = toGet(reqFifo);
         interface Put response = toPut(respFifo);
      endinterface);
      return ret_ifc;
   endfunction

   // Tables
   DstMacTable dstMacTable <- mkDstMacTable(toMetadataClient(dmacReqFifo, dmacRespFifo));
   RoleTable roleTable <- mkRoleTable(toMetadataClient(roleReqFifo, roleRespFifo));
   RoundTable roundTable <- mkRoundTable(toMetadataClient(roundReqFifo, roundRespFifo));
   SequenceTable sequenceTable <- mkSequenceTable(toMetadataClient(sequenceReqFifo, sequenceRespFifo));
   AcceptorTable acceptorTable <- mkAcceptorTable(toMetadataClient(acceptorReqFifo, acceptorRespFifo));
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

   function RoundRegClient toRoundRegClient(FIFO#(RoundRegRequest) reqFifo,
                                            FIFO#(RoundRegResponse) respFifo);
      RoundRegClient ret_ifc;
      ret_ifc = (interface RoundRegClient;
         interface Get request = toGet(reqFifo);
         interface Put response = toPut(respFifo);
      endinterface);
      return ret_ifc;
   endfunction

   function RoleRegClient toRoleRegClient(FIFO#(RoleRegRequest) reqFifo,
                                          FIFO#(RoleRegResponse) respFifo);
      RoleRegClient ret_ifc;
      ret_ifc = (interface RoleRegClient;
         interface Get request = toGet(reqFifo);
         interface Put response = toPut(respFifo);
      endinterface);
      return ret_ifc;
   endfunction

   Client#(RoundRegRequest, RoundRegResponse) round2 = toGPClient(roundRegReqFifo, roundRegRespFifo);

   RegIfc#(Bit#(InstanceSize), Bit#(RoundSize)) roundReg <- mkP4Reg(vec(bb_read_round.regClient, toRoundRegClient(roundRegReqFifo, roundRegRespFifo)));
   RegIfc#(Bit#(1), Role) roleReg <- mkP4Reg(vec(bb_read_role.regClient, toRoleRegClient(roleRegReqFifo, roleRegRespFifo)));
   RegIfc#(Bit#(1), Bit#(64)) datapathIdReg <- mkP4Reg(vec(bb_handle_1a.regClient_datapath_id, bb_handle_2a.regClient_datapath_id));
   RegIfc#(Bit#(1), Bit#(16)) instanceReg <- mkP4Reg(vec(bb_increase_instance.regClient));
   RegIfc#(Bit#(InstanceSize), Bit#(RoundSize)) vroundReg <- mkP4Reg(vec(bb_handle_1a.regClient_vround, bb_handle_2a.regClient_vround));
   RegIfc#(Bit#(InstanceSize), Bit#(ValueSize)) valueReg <- mkP4Reg(vec(bb_handle_1a.regClient_value, bb_handle_2a.regClient_value));

   // Connect Table with BasicBlock
   mkConnection(dstMacTable.next_control_state_0, bb_fwd.prev_control_state);
   mkConnection(sequenceTable.next_control_state_0, bb_increase_instance.prev_control_state);
   mkConnection(acceptorTable.next_control_state_0, bb_handle_1a.prev_control_state);
   mkConnection(acceptorTable.next_control_state_1, bb_handle_2a.prev_control_state);
   mkConnection(acceptorTable.next_control_state_2, bb_handle_drop.prev_control_state);
   mkConnection(roundTable.next_control_state_0, bb_read_round.prev_control_state);
   mkConnection(roleTable.next_control_state_0, bb_read_role.prev_control_state);

   // Control Flow
   rule start_control_state;
      let v <- toGet(inReqFifo).get;
      case (v) matches
         tagged DefaultRequest {pkt: .pkt, meta: .meta} : begin
            if (isValid(meta.valid_ipv4)) begin
               MetadataRequest req = tagged DstMacLookupRequest {pkt: pkt, meta: meta};
               dmacReqFifo.enq(req);
            end
         end
      endcase
   endrule

   rule dmac_tbl_next_control_state;
      let v <- toGet(dmacRespFifo).get;
      $display("(%0d) dmac_tbl next control state", $time);
      case (v) matches
         tagged DstMacResponse {pkt: .pkt, meta: .meta}: begin
            if (isValid(meta.valid_paxos)) begin
               MetadataRequest req = tagged RoleLookupRequest {pkt: pkt, meta: meta};
               roleReqFifo.enq(req);
            end
         end
      endcase
   endrule

   rule role_tbl_next_control_state;
      let v <- toGet(roleRespFifo).get;
      case (v) matches
         tagged RoleResponse {pkt: .pkt, meta: .meta}: begin
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
         end
      endcase
   endrule

   rule sequence_tbl_next_control_state;
      let v <- toGet(sequenceRespFifo).get;
      $display("(%0d) sequence tbl response", $time);
      case (v) matches
         tagged SequenceTblResponse {pkt: .pkt, meta: .meta}: begin
            currPacketFifo.enq(pkt);
            $display("(%0d) Sequence: fwd %h", $time, pkt.id);
            //if (v.p4_action == 1) begin
            //   MetadataRequest req = tagged ForwardQueueRequest {};
            //end
         end
      endcase
   endrule

   rule round_tbl_next_control_state;
      let v <- toGet(roundRespFifo).get;
      $display("(%0d) round table response", $time);
      case (v) matches
         tagged RoundTblResponse {pkt: .pkt, meta: .meta}: begin
            if (meta.paxos_packet_meta$round matches tagged Valid .round) begin
               if (round <= fromMaybe(?, meta.paxos$rnd)) begin
                  $display("(%0d) Round: Acceptor %h, round=%h, rnd=%h", $time, pkt.id, round, meta.paxos$rnd);
                  MetadataRequest req = tagged AcceptorTblRequest {pkt: pkt, meta: meta};
                  acceptorReqFifo.enq(req);
               end
            end
            else
               $display("(%0d) Invalid round", $time);
         end
      endcase
   endrule

   rule acceptor_tbl_next_control_state;
      let v <- toGet(acceptorRespFifo).get;
      $display("(%0d) acceptor table response", $time);
      case (v) matches
         tagged AcceptorTblResponse {pkt: .pkt, meta: .meta}: begin
            //MetadataRequest req = tagged ForwardQueueRequest {};
            currPacketFifo.enq(pkt);
         end
      endcase
   endrule

   interface writeClient = dstMacTable.writeClient;
   interface eventPktSend = toPipeOut(currPacketFifo);
   method IngressPipelineDbgRec dbg();
      return IngressPipelineDbgRec {
         fwdCount: fwdCount
      };
   endmethod
   method Action round_reg_write(Bit#(16) round);
      RoundRegRequest req = RoundRegRequest {addr: 0, data: round, write: True};
      roundRegReqFifo.enq(req);
   endmethod
   method Action role_reg_write(Role role);
      RoleRegRequest req = RoleRegRequest {addr: 0, data: role, write: True};
      roleRegReqFifo.enq(req);
   endmethod
   method Action datapath_id_reg_write(Bit#(64) datapath);
      DatapathIdRegRequest req = DatapathIdRegRequest {addr: 0, data: datapath, write: True};
      datapathIdRegReqFifo.enq(req);
   endmethod
   method Action instance_reg_write(Bit#(16) instance_);
      InstanceRegRequest req = InstanceRegRequest {addr: 0, data: instance_, write: True};
      instanceRegReqFifo.enq(req);
   endmethod
   method Action vround_reg_write(Bit#(InstanceSize) inst, Bit#(RoundSize) round);
      VRoundRegRequest req = VRoundRegRequest {addr: inst, data: round, write: True};
      vroundRegReqFifo.enq(req);
   endmethod
   method sequenceTable_add_entry = sequenceTable.add_entry;
   method acceptorTable_add_entry = acceptorTable.add_entry;
   method dmacTable_add_entry = dstMacTable.add_entry;
endmodule
