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

module mkIngress#(Vector#(numClients, MetadataClient) mdc)(Ingress);
   let verbose = True;

   Reg#(Bit#(64)) fwdCount <- mkReg(0);

   FIFOF#(PacketInstance) currPacketFifo <- mkFIFOF;

   // In
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
   // FIFO#(MetadataRequest) roleRequestFifo <- mkFIFO;
   // FIFO#(MetadataRequest) roundRequestFifo <- mkFIFO;
   // FIFO#(MetadataRequest) sequenceRequestFifo <- mkFIFO;
   // FIFO#(MetadataRequest) acceptorRequestFifo <- mkFIFO;
   // FIFO#(MetadataRequest) dropRequestFifo <- mkFIFO;
   FIFO#(MetadataResponse) dmacRespFifo <- mkFIFO;
   // FIFO#(MetadataResponse) roleResponseFifo <- mkFIFO;
   // FIFO#(MetadataResponse) roundResponseFifo <- mkFIFO;
   // FIFO#(MetadataResponse) sequenceResponseFifo <- mkFIFO;
   // FIFO#(MetadataResponse) acceptorResponseFifo <- mkFIFO;
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
   //RoleTable roleTable <- mkRoleTable();//dstMacTable.next);
   //RoundTable roundTable <- mkRoundTable();//roleTable.next0);
   //SequenceTable sequenceTable <- mkSequenceTable();//roleTable.next1);
   //AcceptorTable acceptorTable <- mkAcceptorTable();//roundTable.next0);
   //DropTable dropTable <- mkDropTable();//roundTable.next1);

   // Registers

   // BasicBlocks
   BasicBlockForward bb_fwd <- mkBasicBlockForward();
   //BasicBlockIncreaseInstance bb_increase_instance <- mkBasicBlockIncreaseInstance;
   //BasicBlockHandle1A bb_handle_1a <- mkBasicBlockHandle1A;
   //BasicBlockHandle2A bb_handle_2a <- mkBasicBlockHandle2A;
   //BasicBlockDrop bb_handle_drop <- mkBasicBlockDrop;

   // Connect Table with BasicBlock
   // mkConnection(dstMacTable.next_control_state_0, bb_fwd.prev_control_state)
   // mkConnection(sequenceTable.next_control_state_0, bb_increase_instance.prev_control_state)
   // mkConnection(acceptorTable.next_control_state_0, bb_handle_1a.prev_control_state)
   // mkConnection(acceptorTable.next_control_state_1, bb_handle_2a.prev_control_state)
   // mkConnection(acceptorTable.next_control_state_2, bb_handle_drop.prev_control_state)

   // Control Flow
   rule start_control_state;
      // let v <- toGet(inReqFifo).get;
      // case (v) matches
      //    tagged {pkt: .pkt, meta: .meta} : begin
      //       if (meta.valid_ipv4) begin
      //          MetadataRequest req = tagged DstMacLookupRequest {dstMac: 0};
      //          dmacReqFifo.enq(req);
      //       end
      //    end
      // endcase
   endrule

   rule dmac_tbl_next_control_state;
      // let v <- toGet(dstMacMetaRespFifo).get;
      // let meta <- toGet(dmacMetaFifo).get;
      // case (v) matches
      // meta.egress = v.egress
      // if meta.valid_paxos
      //    tagged RoleLookupRequest {}
      //    roleRequestFifo
      // else: drop
      // endcase
   endrule

   rule role_tbl_next_control_state;
      // let v <- toGet(roleResponseFifo).get;
      // if (v.role == 1) begin
      //    MetadataRequest req = tagged SequenceTableRequest {};
      //    sequenceRequestFifo.enq(req);
      // end
      // if (v.role == 2) begin
      //    MetadataRequest req = tagged RoundTableRequest {};
      //    roundRequestFifo.enq(req);
      // end
   endrule

   rule sequence_tbl_next_control_state;
      // let v <- toGet(sequenceTableResponseFifo).get;
      // if (v.p4_action == 1) begin
      //    MetadataRequest req = tagged ForwardQueueRequest {};
      // end
      // else begin
      //    free
      // end
   endrule

   rule round_tbl_next_control_state;
      // let v <- toGet(roundTableResponseFifo).get;
      // if (meta.round <= v.round) begin
      //    MetadataRequest req = tagged AcceptorTableRequest {}
      //    acceptorRequestFifo.enq(req);
      // end
      // else begin
      //    free
      // end
   endrule

   rule acceptor_tbl_next_control_state;
      // let v <- toGet(acceptorResponseFifo).get;
      // MetadataRequest req = tagged ForwardQueueRequest {};
      // done
   endrule

   //rule acceptTableSend;
   //   let v <- acceptorTable.next.request.get;
   //   case (v) matches
   //      tagged ForwardQueueRequest {pkt: .pkt}: begin
   //         currPacketFifo.enq(pkt);
   //         fwdCount <= fwdCount + 1;
   //      end
   //   endcase
   //endrule

   interface writeClient = dstMacTable.writeClient;
   interface eventPktSend = toPipeOut(currPacketFifo);
   method IngressPipelineDbgRec dbg();
      return IngressPipelineDbgRec {
         fwdCount: fwdCount
      };
   endmethod
endmodule
