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
import ConnectalTypes::*;
import Register::*;

interface BasicBlockForward;
   interface BBServer prev_control_state;
endinterface

module mkBasicBlockForward(BasicBlockForward);
   FIFO#(BBRequest) bb_forward_request_fifo <- mkFIFO;
   FIFO#(BBResponse) bb_forward_response_fifo <- mkFIFO;

   rule bb_forward;
      let v <- toGet(bb_forward_request_fifo).get;
      case (v) matches
         tagged BBForwardRequest { pkt: .pkt, port: .port}: begin
            BBResponse resp = tagged BBForwardResponse {pkt: pkt, egress: port};
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
   //method Action add_entry (Bit#(48) dstAddr, DmacTblActionT action_, Bit#(9) port);
   method Action add_entry (Bit#(48) dstAddr, Bit#(9) port);
endinterface

module mkDstMacTable#(MetadataClient md)(DstMacTable);
   let verbose = True;
   // internal bcam match table
   MatchTable#(256, SizeOf#(DmacTblReqT), SizeOf#(DmacTblRespT)) matchTable <- mkMatchTable_256_dmacTable();

   FIFO#(BBRequest) outReqFifo <- mkFIFO;
   FIFO#(BBResponse) inRespFifo <- mkFIFO;
   FIFO#(PacketInstance) currPacketFifo <- mkFIFO;
   FIFO#(MetadataT) currMetadataFifo <- mkFIFO;

   // memory client
   FIFO#(MemRequest) writeReqFifo <- mkSizedFIFO(1);
   FIFO#(MemData#(`DataBusWidth)) writeDataFifo <- mkSizedFIFO(1);
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
            DmacTblReqT req = DmacTblReqT {dstAddr: fromMaybe(?, meta.dstAddr), padding: 0};
            matchTable.lookupPort.request.put(pack(req));
            currPacketFifo.enq(pkt);
            currMetadataFifo.enq(meta);
         end
         default: begin
            if (verbose) $display("(%0d) DstMacTable: unknown request type");
         end
      endcase
   endrule

   rule dmac_resp;
      let v <- matchTable.lookupPort.response.get;
      let pkt <- toGet(currPacketFifo).get;
      if (v matches tagged Valid .data) begin
         DmacTblRespT resp = unpack(data);
         $display("(%0d) DstMacTable: pkt %h to port %h", $time, pkt.id, resp.param.port);
         BBRequest req = tagged BBForwardRequest { pkt: pkt, port: resp.param.port};
         outReqFifo.enq(req);
      end
      else begin
         if (verbose) $display("(%0d) DstMacTable: Invalid table response");
      end
   endrule

   rule bb_forward_resp;
      let v <- toGet(inRespFifo).get;
      let meta <- toGet(currMetadataFifo).get;
      case (v) matches
         tagged BBForwardResponse { pkt: .pkt, egress: .egress } : begin
            $display("(%0d) DstMacTable: fwd egress %h", $time, egress);
            MetadataResponse resp = tagged DstMacResponse {pkt: pkt, meta: meta};
            md.response.put(resp);
         end
         default: begin
            if (verbose) $display("(%0d) DstMacTable: unknown BB response");
         end
      endcase
   endrule

   // interface to basic block
   interface next_control_state_0 = (interface BBClient;
      interface request = toGet(outReqFifo);
      interface response = toPut(inRespFifo);
   endinterface);
   interface writeClient = dmaWriteClient;
   //method Action add_entry (Bit#(48) dstAddr, DmacTblActionT action_, Bit#(9) port);
   method Action add_entry (Bit#(48) dstAddr, Bit#(9) port);
      DmacTblReqT req = DmacTblReqT {dstAddr: dstAddr, padding: 0};
      DmacTblParamT param = DmacTblParamT {port: port};
      DmacTblRespT resp = DmacTblRespT {act: FORWARD, param: param};
      $display("(%0d) add_entry %h, %h", $time, pack(req), pack(resp));
      matchTable.add_entry.put(tuple2(pack(req), pack(resp)));
   endmethod
endmodule

