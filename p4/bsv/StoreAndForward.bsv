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

// NOTE:
// Implement a store-and-forward mechanism between ring-buffer and 
// main packet memory. Packets are buffered completely in ring buffer
// before it is sent to main memory and vice versa.

import FIFO::*;
import GetPut::*;
import Ethernet::*;
import SpecialFIFOs::*;
import SharedBuff::*;
import PacketBuffer::*;
import MemTypes::*;

import Malloc::*;
import MemServer::*;
import MemServerInternal::*;

interface StoreAndForwardFromRingToMem;
   interface PktReadClient readClient;
   interface Get#(Bit#(PacketAddrLen)) mallocReq;
   interface Put#(Bool) mallocDone;
   //interface SharedBufferClient memClient;
   interface MemWriteClient#(`DataBusWidth) writeClient;
endinterface

module mkStoreAndFwdFromRingToMem(StoreAndForwardFromRingToMem);

   let verbose = True;

   // RingBuffer Read Client
   FIFO#(EtherData) readDataFifo <- mkFIFO;
   FIFO#(Bit#(EtherLen)) readLenFifo <- mkFIFO;
   FIFO#(EtherReq) readReqFifo <- mkFIFO;

   // Memory Client
   FIFO#(MemRequest) writeReqFifo <- mkSizedFIFO(4);
   FIFO#(MemData#(`DataBusWidth)) writeDataFifo <- mkSizedFIFO(32);
   FIFO#(Bit#(MemTagSize)) writeDoneFifo <- mkSizedFIFO(4);
   MemWriteClient#(`DataBusWidth) dmaWriteClient = (interface MemWriteClient;
   interface Get writeReq = toGet(writeReqFifo);
   interface Get writeData = toGet(writeDataFifo);
   interface Put writeDone = toPut(writeDoneFifo);
   endinterface);

   FIFO#(Bit#(PacketAddrLen)) mallocReqFifo <- mkFIFO;
   FIFO#(Bit#(EtherLen)) pktLenFifo <- mkFIFO;
   FIFO#(Bool) mallocDoneFifo <- mkFIFO;
   Reg#(Bool) readStarted <- mkReg(False);
   Reg#(Bool) mallocd <- mkReg(False);

   Reg#(Bit#(32)) cycle <- mkReg(0);
   rule every1 if (verbose);
      cycle <= cycle + 1;
   endrule

   rule packetReadStart if (!readStarted);
      let pktLen <- toGet(readLenFifo).get;
      if (verbose) $display("%d: ReadLen %d", cycle, pktLen);
      mallocReqFifo.enq(truncate(pktLen));
      pktLenFifo.enq(pktLen);
      readStarted <= True;
   endrule

   rule allocMemory;
      let pktLen <- toGet(pktLenFifo).get;
      let done <- toGet(mallocDoneFifo).get;
      if (done) begin
         mallocd <= True;
         readReqFifo.enq(EtherReq{len: truncate(pktLen)});
         writeReqFifo.enq(MemRequest {sglId: 0, offset: 0, burstLen: truncate(pktLen), tag:0
`ifdef BYTE_ENABLES
                                      , firstbe: 'hff, lastbe: 'hff
`endif
});
         if (verbose) $display("%d: alloc done", cycle);
      end
   endrule

   rule packetReadInProgress if (readStarted && mallocd);
      let v <- toGet(readDataFifo).get;
      if (verbose) $display(fshow(" packet ") + fshow(v));
      if (v.eop) begin
         readStarted <= False;
         mallocd <= False;
         $display("%d: packet finished", cycle);
      end
      $display("StoreAndForward::writeData: data:%h, tag:%h, last:%h", v.data, 0, v.eop);
      writeDataFifo.enq(MemData {data: v.data, tag: 0, last: v.eop});
   endrule

   interface PktReadClient readClient;
      interface readData = toPut(readDataFifo);
      interface readLen = toPut(readLenFifo);
      interface readReq = toGet(readReqFifo);
   endinterface

   interface Get mallocReq = toGet(mallocReqFifo);
   interface Put mallocDone = toPut(mallocDoneFifo);
   interface writeClient = dmaWriteClient;
endmodule

interface StoreAndFwdFromMemToRing;
   interface PktWriteClient portClient;
   //interface SharedBufferClient memClient;
endinterface

module mkStoreAndFwdFromMemToRing(StoreAndFwdFromMemToRing);

   // read data from memory
   rule packetReadStart;
      // get size for packet
      // write to ring
   endrule

   // free memory
   rule packetReadInProgress;

   endrule

endmodule


