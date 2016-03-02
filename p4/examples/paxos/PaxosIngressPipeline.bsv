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
import PaxosTypes::*;
import RegFile::*;
import DstMacTable::*;
import RoleTable::*;
import RoundTable::*;
import AcceptorTable::*;
import SequenceTable::*;
import DropTable::*;
import MemTypes::*;

interface PaxosIngressPipeline;
   interface MemWriteClient#(`DataBusWidth) writeClient;
   interface Get#(PacketInstance) eventPktSend;
endinterface

module mkPaxosIngressPipeline#(Client#(MetadataRequest, MetadataResponse) md)(PaxosIngressPipeline);
   let verbose = True;

   FIFO#(MetadataRequest) outReqFifo <- mkFIFO;
   FIFO#(MetadataResponse) inRespFifo <- mkFIFO;
   FIFO#(PacketInstance) currPacketFifo <- mkFIFO;

   DstMacTable dstMacTable <- mkDstMacTable(md);
   RoleTable roleTable <- mkRoleTable(dstMacTable.next);
   RoundTable roundTable <- mkRoundTable(roleTable.next0);
   SequenceTable sequenceTable <- mkSequenceTable(roleTable.next1);
   AcceptorTable acceptorTable <- mkAcceptorTable(roundTable.next0);
   DropTable dropTable <- mkDropTable(roundTable.next1);

//   rule checkValidPaxos;
//      let v <- md.request.get;
//      case (v) matches
//         tagged ValidPaxosRequest { pkt: .pkt }: begin
//            // enqueue to role table
//         end
//         default: begin
//            // enqueue to forward queue
//         end
//      endcase
//   endrule

   rule acceptTableSend;
      let v <- acceptorTable.next.request.get;
      case (v) matches
         tagged ForwardQueueRequest {pkt: .pkt}: begin
            currPacketFifo.enq(pkt);
         end
      endcase
   endrule

   interface writeClient = dstMacTable.writeClient;
   interface eventPktSend = toGet(currPacketFifo);
endmodule
