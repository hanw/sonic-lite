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
import Ethernet::*;
import GetPut::*;
import FIFO::*;
import MemMgmt::*;
import MemTypes::*;
import PacketBuffer::*;
import PacketTypes::*;
import StoreAndForward::*;

interface ModifyMac;
   interface Client#(MetadataRequest, MetadataResponse) next;
   interface MemWriteClient#(`DataBusWidth) writeClient;
endinterface

module mkModifyMac#(Client#(MetadataRequest, MetadataResponse) md)(ModifyMac);
   let verbose = True;
   Reg#(Bit#(64)) modifyMacCnt <- mkReg(0);
   FIFO#(MetadataRequest) outReqFifo <- mkFIFO;
   FIFO#(MetadataResponse) inRespFifo <- mkFIFO;
   FIFO#(PacketInstance) currPacketFifo <- mkFIFO;

   // Memory Client
   FIFO#(MemRequest) writeReqFifo <- mkSizedFIFO(4);
   FIFO#(MemData#(`DataBusWidth)) writeDataFifo <- mkSizedFIFO(16);
   FIFO#(Bit#(MemTagSize)) writeDoneFifo <- mkSizedFIFO(4);
   MemWriteClient#(`DataBusWidth) dmaWriteClient = (interface MemWriteClient;
   interface Get writeReq = toGet(writeReqFifo);
   interface Get writeData = toGet(writeDataFifo);
   interface Put writeDone = toPut(writeDoneFifo);
   endinterface);

   rule modifyMacAddress;
      let v <- md.request.get;
      case (v) matches
         tagged ModifyMacRequest {pkt: .pkt, mac: .mac} : begin
            if(verbose) $display("ModifyMac: id %h ", pkt.id);
            // FIXME: busrtLen must be multiple of 16..
            writeReqFifo.enq(MemRequest {sglId: extend(pkt.id), offset: 0, 
                                         burstLen: 'h10, tag: 0
`ifdef BYTE_ENABLES
                                         , firstbe: 'hffff, lastbe: 'h003f
`endif
                                        });
            writeDataFifo.enq(MemData{data: extend(mac), tag:0, last: True});
            currPacketFifo.enq(pkt);
         end
      endcase
   endrule

   rule insertQueue;
      let v <- toGet(writeDoneFifo).get;
      let pkt <- toGet(currPacketFifo).get;
      MetadataRequest nextReq = tagged QueueRequest {pkt: pkt, queue: 0, port: 0};
      outReqFifo.enq(nextReq);
      if (verbose) $display("ModifyMac: writeDone size=%h", pkt.size);
   endrule

   interface next = (interface Client#(MetadataRequest, MetadataResponse);
      interface request = toGet(outReqFifo);
      interface response = toPut(inRespFifo);
   endinterface);
   interface writeClient = dmaWriteClient;
endmodule
