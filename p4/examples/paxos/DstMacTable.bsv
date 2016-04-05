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
import FIFO::*;
import GetPut::*;

import Ethernet::*;
import MemTypes::*;
import PaxosTypes::*;
import MatchTable::*;

interface BasicBlockForward;
   // Register Access
   // Memory Access
endinterface

module mkBasicBlockForward(BasicBlockForward);

   rule bb_forward;
      // let v <- toGet(bb_forward_request_fifo).get;
      // meta.egress <- v.port; # modify_field
      // MetadataResponse resp = tagged {egress: egress};
      // bb_forward_response_fifo.enq();
   endrule

endmodule

interface DstMacTable;
   interface MetadataClient next_control_state_0;
   interface MemWriteClient#(`DataBusWidth) writeClient;
endinterface

module mkDstMacTable#(MetadataClient md)(DstMacTable);

   // internal bcam match table
   MatchTable#(256, DmacTblReqT, DmacTblRespT) matchTable <- mkMatchTable_256_dmacTable();

   FIFO#(MetadataRequest) outReqFifo <- mkFIFO;
   FIFO#(MetadataResponse) inRespFifo <- mkFIFO;
   //FIFO#(PacketInstance) currPacketFifo <- mkFIFO;

   // memory client
   FIFO#(MemRequest) writeReqFifo <- mkSizedFIFO(4);
   FIFO#(MemData#(`DataBusWidth)) writeDataFifo <- mkSizedFIFO(16);
   FIFO#(Bit#(MemTagSize)) writeDoneFifo <- mkSizedFIFO(4);
   MemWriteClient#(`DataBusWidth) dmaWriteClient = (interface MemWriteClient;
      interface Get writeReq = toGet(writeReqFifo);
      interface Get writeData = toGet(writeDataFifo);
      interface Put writeDone = toPut(writeDoneFifo);
   endinterface);

   rule dmac_lookup;
      let v <- md.request.get;
      case (v) matches
         tagged DstMacLookupRequest {pkt: .pkt, dstMac: .dstMac} : begin
            matchTable.lookupPort.request.put(DmacTblReqT{dstAddr: dstMac, padding: 0});
            //currPacketFifo.enq(pkt);
         end
      endcase
   endrule

   rule dmac_resp;
      let v <- matchTable.lookupPort.response.get;
      $display("dmac response", fshow(v));
      // MetadataRequest req = tagged {port: v.port};
      // outReqFifo.enq(req);
   endrule

   rule bb_forward_resp;
      let v <- toGet(inRespFifo).get;
      // MetadataResponse resp = tagged {};
      // md.response.put();
   endrule

   // interface to basic block
   interface next_control_state_0 = (interface MetadataClient;
      interface request = toGet(outReqFifo);
      interface response = toPut(inRespFifo);
   endinterface);
   interface writeClient = dmaWriteClient;
endmodule

