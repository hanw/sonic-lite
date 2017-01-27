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
import RoundTable::*;
import LearnerTable::*;
import ResetTable::*;
import Vector::*;
`include "ConnectalProjectConfig.bsv"

interface Ingress;
   interface MemWriteClient#(`DataBusWidth) writeClient;
   interface PipeOut#(MetadataRequest) next;
   // interface Get#(Role) role_reg_read_resp;
   method Action datapath_id_reg_write(Bit#(DatapathSize) datapath);
   method Action round_reg_write(Bit#(TLog#(InstanceCount)) inst, Bit#(RoundSize) round);
   method Action value_reg_write(Bit#(TLog#(InstanceCount)) inst, Vector#(8, Bit#(32)) value);
   method Action history2b_reg_write(Bit#(TLog#(InstanceCount)) inst, Bit#(8) history);
   //method Action sequenceTable_add_entry(Bit#(16) msgtype, SequenceTblActionT action_);
   //method Action acceptorTable_add_entry(Bit#(16) msgtype, AcceptorTblActionT action_);
   //method Action dmacTable_add_entry(Bit#(48) mac, Bit#(9) port);
   method Action learnerTable_add_entry(Bit#(16) msgtype, LearnerTblActionT action_);
   // Debug
   method IngressDbgRec read_debug_info;
   method IngressPerfRec read_perf_info;
endinterface

module mkIngress#(Vector#(numClients, PipeOut#(MetadataRequest)) mdc)(Ingress);
   let verbose = True;
   Reg#(LUInt) fwdCount <- mkReg(0);
   FIFOF#(MetadataRequest) currPacketFifo <- mkFIFOF;
   FIFOF#(MetadataRequest) inReqFifo <- mkFIFOF;
   FIFOF#(MetadataResponse) outRespFifo <- mkFIFOF;

   Vector#(numClients, PipeIn#(MetadataRequest)) metadataServers = newVector;
   for (Integer i=0; i<valueOf(numClients); i=i+1) begin
      metadataServers[i] = toPipeIn(inReqFifo);
   end
   mkConnection(mdc, metadataServers);

   FIFOF#(MetadataRequest) dmacReqFifo <- mkFIFOF;
   FIFOF#(MetadataResponse) dmacRespFifo <- mkFIFOF;
   FIFOF#(MetadataRequest) roundReqFifo <- mkFIFOF;
   FIFOF#(MetadataResponse) roundRespFifo <- mkFIFOF;
   FIFOF#(MetadataRequest) learnerReqFifo <- mkFIFOF;
   FIFOF#(MetadataResponse) learnerRespFifo <- mkFIFOF;
   FIFOF#(MetadataRequest) resetReqFifo <- mkFIFOF;
   FIFOF#(MetadataResponse) resetRespFifo <- mkFIFOF;
   FIFOF#(MetadataRequest) forwardReqFifo <- mkFIFOF;
   FIFOF#(MetadataResponse) forwardRespFifo <- mkFIFOF;

   FIFOF#(MetadataRequest) next_req_ff <- mkFIFOF;
   FIFOF#(MetadataResponse) next_rsp_ff <- mkFIFOF;

   Reg#(Bit#(32)) clk_cnt <- mkReg(0);
   Reg#(Bit#(32)) ingress_start_time <- mkReg(0);
   Reg#(Bit#(32)) ingress_end_time <- mkReg(0);
   rule clockrule;
      clk_cnt <= clk_cnt + 1;
   endrule

   // Tables
   DstMacTable dstMacTable <- mkDstMacTable(toGPClient(dmacReqFifo, dmacRespFifo));
   RoundTable roundTable <- mkRoundTable(toGPClient(roundReqFifo, roundRespFifo));
   LearnerTable learnerTable <- mkLearnerTable(toGPClient(learnerReqFifo, learnerRespFifo));
   ResetTable resetTable <- mkResetTable(toGPClient(resetReqFifo, resetRespFifo));
   //DropTable dropTable <- mkDropTable();//roundTable.next1);

   // BasicBlocks
   BasicBlockForward bb_fwd <- mkBasicBlockForward();
   BasicBlockHandle2B bb_handle_2b <- mkBasicBlockHandle2B();
   BasicBlockHandleNewValue bb_handle_new_value <- mkBasicBlockHandleNewValue();
   BasicBlockDrop bb_handle_drop1 <- mkBasicBlockDrop();
   BasicBlockDrop bb_handle_drop2 <- mkBasicBlockDrop();
   BasicBlockRound bb_read_round <- mkBasicBlockRound();

   // Registers
   FIFO#(RoundRegRequest) roundRegReqFifo <- mkFIFO;
   FIFO#(DatapathIdRegRequest) datapathIdRegReqFifo <- mkFIFO;
   FIFO#(ValueRegRequest) valueRegReqFifo <- mkFIFO;
   FIFO#(HistoryRegRequest) historyRegReqFifo <- mkFIFO;

   FIFO#(RoundRegResponse) roundRegRespFifo <- mkFIFO;
   FIFO#(DatapathIdRegResponse) datapathIdRegRespFifo <- mkFIFO;
   FIFO#(ValueRegResponse) valueRegRespFifo <- mkFIFO;
   FIFO#(HistoryRegResponse) historyRegRespFifo <- mkFIFO;

   //Vector#(1, Client#(RoleRegRequest, RoleRegResponse)) role_clients = newVector();
   //role_clients[0] = bb_read_role.regClient;
   //role_clients[1] = toGPClient(roleRegReqFifo, roleRegRespFifo);
   //RegisterIfc#(1, SizeOf#(Role)) roleReg <- mkP4Register(role_clients);
   // zipWithM_(mkConnection, role_clients, roleReg.servers);
   let datapathIdReg <- mkP4Register(vec(toGPClient(datapathIdRegReqFifo, datapathIdRegRespFifo)));
   let roundReg <- mkP4Register(vec(bb_read_round.regClient, bb_handle_2b.regClient_round, toGPClient(roundRegReqFifo, roundRegRespFifo)));
   let valueReg <- mkP4Register(vec(bb_handle_2b.regClient_value, toGPClient(valueRegReqFifo, valueRegRespFifo)));

   // Connect Table with BasicBlock
   mkConnection(dstMacTable.next_control_state_0, bb_fwd.prev_control_state);
   mkConnection(learnerTable.next_control_state_0, bb_handle_2b.prev_control_state);
   mkConnection(learnerTable.next_control_state_1, bb_handle_drop1.prev_control_state);
   mkConnection(resetTable.next_control_state_0, bb_handle_new_value.prev_control_state);
   mkConnection(resetTable.next_control_state_1, bb_handle_drop2.prev_control_state);
   mkConnection(roundTable.next_control_state_0, bb_read_round.prev_control_state);

   // Resolve rule conflicts
   //(* descending_urgency ="sequence_tbl_next_control_state, acceptor_tbl_next_control_state" *)
   // Control Flow
   rule start_control_state if (inReqFifo.notEmpty);
      let _req = inReqFifo.first;
      let pkt = _req.pkt;
      let meta = _req.meta;
      inReqFifo.deq;
      ingress_start_time <= clk_cnt;
      if (isValid(meta.valid_paxos)) begin
         MetadataRequest req = MetadataRequest {pkt: pkt, meta: meta};
         roundReqFifo.enq(req);
      end
      $display("(%0d) Ingress: dmac_tbl next control state", $time);
   endrule

   rule round_tbl_next_control_state if (roundRespFifo.notEmpty);
      let rsp = roundRespFifo.first;
      let meta = rsp.meta;
      let pkt = rsp.pkt;
      roundRespFifo.deq;
      MetadataRequest req = MetadataRequest {pkt: pkt, meta: meta};
      $display("(%0d) round table response", $time);
      if (meta.paxos_packet_meta$round matches tagged Valid .round) begin
         if (fromMaybe(?, meta.paxos$rnd) > round) begin
            $display("(%0d) Round: reset_tbl %h, round=%h, rnd=%h", $time, pkt.id, round, fromMaybe(?, meta.paxos$rnd));
            resetReqFifo.enq(req);
         end
         else if (fromMaybe(?, meta.paxos$rnd) == round) begin
            $display("learner fifo enq");
            learnerReqFifo.enq(req);
         end
         else begin
            $display("FIXME: invalid");
         end
      end
      else begin
         $display("next req");
         next_req_ff.enq(req);
      end
   endrule

   rule learner_tbl_next_control_state if (learnerRespFifo.notEmpty);
      let rsp = learnerRespFifo.first;
      learnerRespFifo.deq;
      let meta = rsp.meta;
      let pkt = rsp.pkt;
      MetadataRequest req = MetadataRequest {pkt: pkt, meta: meta};
      if (meta.paxos_packet_meta$acceptors matches tagged Valid .acceptors) begin
         if (acceptors == 6 || acceptors == 5 || acceptors == 3) begin
            forwardReqFifo.enq(req);
         end
         else begin
            next_req_ff.enq(req);
         end
      end
      else begin
         next_req_ff.enq(req);
      end
   endrule

   rule reset_tbl_next_control_state if (resetRespFifo.notEmpty);
      let rsp = resetRespFifo.first;
      resetRespFifo.deq;
      let meta = rsp.meta;
      let pkt = rsp.pkt;
      MetadataRequest req = MetadataRequest {pkt: pkt, meta: meta};
      if (meta.paxos_packet_meta$acceptors matches tagged Valid .acceptors) begin
         if (acceptors == 6 || acceptors == 5 || acceptors == 3) begin
            forwardReqFifo.enq(req);
         end
         else begin
            next_req_ff.enq(req);
         end
      end
      else begin
         next_req_ff.enq(req);
      end
   endrule

   interface writeClient = dstMacTable.writeClient;
   interface next = toPipeOut(next_req_ff);
   method IngressDbgRec read_debug_info();
      return IngressDbgRec {
         fwdCount: fwdCount,
         //accTbl: acceptorTable.read_debug_info,
         //seqTbl: sequenceTable.read_debug_info,
         dmacTbl: dstMacTable.read_debug_info
      };
   endmethod
   method IngressPerfRec read_perf_info();
      return IngressPerfRec {
         ingress_start_time: ingress_start_time,
         ingress_end_time: ingress_end_time,
         acceptor_start_time: 0,
         acceptor_end_time: 0,
         sequence_start_time: 0,
         sequence_end_time: 0
      };
   endmethod
   method Action round_reg_write(Bit#(TLog#(InstanceCount)) inst, Bit#(RoundSize) round);
      RoundRegRequest req = RoundRegRequest {addr: inst, data: round, write: True};
      roundRegReqFifo.enq(req);
   endmethod
   method Action datapath_id_reg_write(Bit#(DatapathSize) datapath);
      DatapathIdRegRequest req = DatapathIdRegRequest {addr: 0, data: datapath, write: True};
      datapathIdRegReqFifo.enq(req);
   endmethod
   method Action value_reg_write(Bit#(TLog#(InstanceCount)) inst, Vector#(8, Bit#(32)) value);
      ValueRegRequest req = ValueRegRequest {addr: inst, data: pack(value), write: True};
      valueRegReqFifo.enq(req);
   endmethod
   method Action history2b_reg_write(Bit#(TLog#(InstanceCount)) inst, Bit#(8) history);
      HistoryRegRequest req = HistoryRegRequest {addr: inst, data: pack(history), write: True};
      historyRegReqFifo.enq(req);
   endmethod
   method learnerTable_add_entry = learnerTable.add_entry;
   //method dmacTable_add_entry = dstMacTable.add_entry;
endmodule
