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

interface Ingress;
   interface MemWriteClient#(`DataBusWidth) writeClient;
   interface PipeOut#(PacketInstance) eventPktSend;
   method IngressPipelineDbgRec dbg;
endinterface

module mkIngress#(Vector#(numClients, MetaDataCient) mdc)(Ingress);
   let verbose = True;

   Reg#(Bit#(64)) fwdCount <- mkReg(0);

   // Out
   FIFO#(MetadataRequest) outReqFifo <- mkFIFO;
   FIFO#(MetadataResponse) inRespFifo <- mkFIFO;
   FIFOF#(PacketInstance) currPacketFifo <- mkFIFOF;

   // In
   FIFO#(MetadataRequest) inReqFifo <- mkFIFO;
   FIFO#(MetadataResponse) outRespFifo <- mkFIFO;

   Vector#(numClients, MetaDataServer) metadataServers = newVector;
   for (Integer i=0; i<valueOf(numClients); i=i+1) begin
      metadataServers[i] = (interface MetaDataServer;
         interface Put request = toPut(inReqFifo);
         interface Get response = toGet(outRespFifo);
      endinterface);
   end
   mkConnection(mdc, metadataServers);

   function MetaDataCient getMetadataClient();
      MetaDataCient ret_ifc;
      ret_ifc = (interface MetaDataCient;
         interface Get request = toGet(inReqFifo);
         interface Put response = toPut(outRespFifo);
      endinterface);
      return ret_ifc;
   endfunction

   // Tables
   DstMacTable dstMacTable <- mkDstMacTable(getMetadataClient());
   RoleTable roleTable <- mkRoleTable(dstMacTable.next);
   RoundTable roundTable <- mkRoundTable(roleTable.next0);
   SequenceTable sequenceTable <- mkSequenceTable(roleTable.next1);
   AcceptorTable acceptorTable <- mkAcceptorTable(roundTable.next0);
   DropTable dropTable <- mkDropTable(roundTable.next1);

   // BasicBlocks
   BasicBlockForward bb_fwd <- mkBasicBlockForward;
   BasicBlockIncreaseInstance bb_increase_instance <- mkBasicBlockIncreaseInstance;
   BasicBlockHandle1A bb_handle_1a <- mkBasicBlockHandle1A;
   BasicBlockHandle2A bb_handle_2a <- mkBasicBlockHandle2A;
   BasicBlockDrop bb_handle_drop <- mkBasicBlockDrop;

   // Control Flow
   rule dmac_tbl_next_control_state;
      // check paxos_valid
      // if True, MetadataRequest to RoleTable
      // else: drop
   endrule

   rule role_tbl_next_control_state;
      // check role
      // if role == 1, MetadataRequest to SequenceTable
      // if role == 2, MetadataRequest to RoundTable
   endrule

   rule sequence_tbl_next_control_state;
      // check output
      // if p4_action == 1, MetadataRequest to Done
   endrule

   rule round_tbl_next_control_state;
      // check meta.round
      // if <= round_reg, MetadataRequest to AcceptorTable
   endrule

   rule acceptor_tbl_next_control_state;
      // done
   endrule

   rule acceptTableSend;
      let v <- acceptorTable.next.request.get;
      case (v) matches
         tagged ForwardQueueRequest {pkt: .pkt}: begin
            currPacketFifo.enq(pkt);
            fwdCount <= fwdCount + 1;
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
endmodule
