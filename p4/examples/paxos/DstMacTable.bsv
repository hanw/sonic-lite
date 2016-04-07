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
   interface BBServer prev_control_state;
endinterface

module mkBasicBlockForward(BasicBlockForward);
   FIFO#(BBRequest) bb_forward_request_fifo <- mkFIFO;
   FIFO#(BBResponse) bb_forward_response_fifo <- mkFIFO;

   rule bb_forward;
      let v <- toGet(bb_forward_request_fifo).get;
      case (v) matches
         tagged BBForwardRequest { pkt: .pkt, port: .port}: begin
            BBResponse resp = tagged BBForwardResponse {egress: port};
            bb_forward_response_fifo.enq(resp);
         end
      endcase
   endrule

   interface prev_control_state = (interface BBServer;
      interface request = toPut(bb_forward_request_fifo);
      interface response = toGet(bb_forward_response_fifo);
   endinterface);
endmodule

interface DstMacTable;
   interface BBClient next_control_state_0;
   interface MemWriteClient#(`DataBusWidth) writeClient;
endinterface

module mkDstMacTable#(MetadataClient md)(DstMacTable);

   // internal bcam match table
   MatchTable#(256, DmacTblReqT, DmacTblRespT) matchTable <- mkMatchTable_256_dmacTable();

   FIFO#(BBRequest) outReqFifo <- mkFIFO;
   FIFO#(BBResponse) inRespFifo <- mkFIFO;
   FIFO#(PacketInstance) currPacketFifo <- mkFIFO;
   FIFO#(MetadataT) currMetadataFifo <- mkFIFO;

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
         tagged DstMacLookupRequest { pkt: .pkt, meta: .meta } : begin
            matchTable.lookupPort.request.put(DmacTblReqT{dstAddr: meta.dstAddr, padding: 0});
            currPacketFifo.enq(pkt);
            currMetadataFifo.enq(meta);
         end
      endcase
   endrule

   rule dmac_resp;
      let v <- matchTable.lookupPort.response.get;
      let pkt <- toGet(currPacketFifo).get;
      if (v matches tagged Valid .resp) begin
         case (resp) matches
            tagged Forward {port: .port}: begin
               $display("dmac response pkt %h(%h) to port %h", pkt.id, pkt.size, port);
               BBRequest req = tagged BBForwardRequest { pkt: pkt, port: port};
               outReqFifo.enq(req);
            end
         endcase
      end
   endrule

   rule bb_forward_resp;
      let v <- toGet(inRespFifo).get;
      let meta <- toGet(currMetadataFifo).get;
      case (v) matches
         tagged BBForwardResponse { pkt: .pkt, egress: .egress } : begin
            $display("update metadata %h", egress);
            MetadataResponse resp = tagged DstMacResponse {pkt: pkt, meta: meta};
            md.response.put(resp);
         end
      endcase
   endrule

   // interface to basic block
   interface next_control_state_0 = (interface BBClient;
      interface request = toGet(outReqFifo);
      interface response = toPut(inRespFifo);
   endinterface);
   interface writeClient = dmaWriteClient;
endmodule

