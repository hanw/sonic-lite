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

interface PaxosIngressPipeline;
   interface MemWriteClient#(`DataBusWidth) writeClient;
   interface PipeOut#(PacketInstance) eventPktSend;
endinterface

module mkPaxosIngressPipeline#(Vector#(numClients, MetaDataCient) mdc)(PaxosIngressPipeline);
   let verbose = True;

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

   DstMacTable dstMacTable <- mkDstMacTable(getMetadataClient());
   RoleTable roleTable <- mkRoleTable(dstMacTable.next);
   RoundTable roundTable <- mkRoundTable(roleTable.next0);
   SequenceTable sequenceTable <- mkSequenceTable(roleTable.next1);
   AcceptorTable acceptorTable <- mkAcceptorTable(roundTable.next0);
   DropTable dropTable <- mkDropTable(roundTable.next1);

   rule acceptTableSend;
      let v <- acceptorTable.next.request.get;
      case (v) matches
         tagged ForwardQueueRequest {pkt: .pkt}: begin
            currPacketFifo.enq(pkt);
         end
      endcase
   endrule

   interface writeClient = dstMacTable.writeClient;
   interface eventPktSend = toPipeOut(currPacketFifo);
endmodule
