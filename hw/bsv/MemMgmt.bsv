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

// MemMgmt module handles memory allocation and memory translation

import BuildVector::*;
import Cntrs::*;
import GetPut::*;
import ClientServer::*;
import ConfigCounter::*;
import StmtFSM::*;
import FIFO::*;
import FIFOF::*;
import Pipe::*;
import Vector::*;
import BRAMFIFO::*;
import BRAM::*;
import ConnectalBram::*;
import ConnectalMemory::*;
import MMU::*;
import Ethernet::*;
import SharedBuffMMU::*;
import DbgTypes::*;

typedef enum {
   MemMgmtErrorNone,
   MemMgmtErrorInvalidPacketId
} MemMgmtErrorType deriving (Bits);

typedef struct {
   MemMgmtErrorType errorType;
   Bit#(32) id;
} MemMgmtError deriving (Bits);

interface MemMgmtIndication;
   method Action memory_allocated(Bit#(32) id);
   method Action packet_committed(Bit#(32) tag);
   method Action packet_freed(Bit#(32) tag);
   method Action error(Bit#(32) errorType, Bit#(32) id);
endinterface

typedef 8  PageAddrLen; // 2^8 = 256 byte page
typedef 16 MemoryAddrLen; // 2^16 = 65536 byte packet buffer
typedef TExp#(PageAddrLen) PageSize; // 256
typedef TSub#(MemoryAddrLen, PageAddrLen) PageIdx; // 8-bit index
typedef TExp#(PageIdx) FreeQueueDepth; // 256 pages

Integer pageIdx = valueOf(PageIdx);
Integer freeQueueDepth = valueOf(FreeQueueDepth);

/* Terminate MMUIndication.idResponse, because sending it to sw is slow*/
interface MMUIndicationProxy;
   interface MMUIndication mmuInd;
   interface Get#(Bit#(32)) idResponse;
endinterface
module mkMMUIndicationProxy
`ifdef DEBUG
                           #(MMUIndication mmuInd)
`endif
                           (MMUIndicationProxy);
   FIFO#(Bit#(32)) idresponse_fifo <- mkFIFO;
   interface MMUIndication mmuInd;
      method Action idResponse(Bit#(32) sglId);
         idresponse_fifo.enq(sglId);
      endmethod
`ifdef DEBUG
      method configResp = mmuInd.configResp;
      method error = mmuInd.error;
`endif
   endinterface
   interface Get idResponse = toGet(idresponse_fifo);
endmodule

interface MemMgmt#(numeric type addrWidth);
   method Action init_mem();
   interface MMU#(addrWidth) mmu;
   interface Put#(Bit#(EtherLen)) mallocReq;
   interface Get#(Maybe#(Bit#(32))) mallocDone;
   interface Put#(Bit#(32)) freeReq;
   interface Get#(Bool) freeDone;
   method MemMgmtDbgRec dbg;
endinterface
module mkMemMgmt
`ifdef DEBUG
                #(MemMgmtIndication indication, MMUIndication mmuInd)
`endif
                (MemMgmt#(addrWidth))
   provisos(Add#(a__, addrWidth, 44));
   let verbose = True;

   Reg#(Bit#(32)) cycle <- mkReg(0);
   rule cycleRule if (verbose);
      cycle <= cycle + 1;
   endrule

   Reg#(Bit#(64)) allocCnt <- mkReg(0);
   Reg#(Bit#(64)) freeCnt <- mkReg(0);

   Reg#(Bool) inited <- mkReg(False);
   FIFOF#(Bit#(EtherLen)) outstanding_malloc <- mkFIFOF;
   FIFOF#(Bit#(32)) outstanding_free <- mkFIFOF;

   FIFOF#(Bit#(PageIdx)) freePageList <- mkSizedFIFOF(freeQueueDepth);

   BRAM_Configure bramConfig = defaultValue;
   bramConfig.latency        = 2;
   // Store mapping from packetId to first page in linked list
   // PortA
   BRAM2Port#(Bit#(32), Maybe#(Bit#(PageIdx))) idmap <- ConnectalBram::mkBRAM2Server(bramConfig);
   // Pack linked list of pages into BRAM for free operation
   // BRAM is indiced with pageIdx, and each entry in BRAM stores
   // a Maybe#(pageIdx) for next entry in the same list.
   // Entry is Invalid for last entry in a list
   BRAM2Port#(Bit#(PageIdx), Maybe#(Bit#(PageIdx))) pagemap <- ConnectalBram::mkBRAM2Server(bramConfig);

   Count#(Bit#(PageIdx)) reqBurstLen <- mkCount(0);
   Count#(Bit#(PageIdx)) reqSglIndex<- mkCount(0);
   ConfigCounter#(PageIdx) freePageCount <- mkConfigCounter(0);
   Reg#(Bool) free_started <- mkReg(False);
   Reg#(Maybe#(Bit#(PageIdx))) lastSegment <- mkReg(tagged Invalid);
   Reg#(Bit#(32)) idToFree <- mkReg(0);
   Reg#(Bit#(PageIdx)) currSegement <- mkReg(0);

   Reg#(Bit#(32)) packetId <- mkReg(0);
   Reg#(Bit#(64)) barr0 <- mkReg(0);

   FIFO#(Maybe#(Bit#(32))) mallocDoneFifo <- mkFIFO;
   FIFO#(Bool) freeDoneFifo <- mkFIFO;
   FIFO#(MemMgmtError) memMgmtErrorFifo <- mkFIFO;
   FIFO#(Bit#(PageIdx)) pagePointerFifo <- mkFIFO;

   MMUIndicationProxy proxy <- mkMMUIndicationProxy(
`ifdef DEBUG
                                                    mmuInd
`endif
                                                   );
   MMU#(addrWidth) iommu <- mkSharedBuffMMU(0, proxy.mmuInd);

   function BRAMServer#(a,b) portsel(BRAM2Port#(a,b) x, Integer i);
      if(i==0) return x.portA;
      else return x.portB;
   endfunction

   rule initialization if (!inited);
      freePageList.enq(pack(freePageCount.read));
      if (freePageCount.read == fromInteger(freeQueueDepth-1)) begin
         inited <= True;
         $display("Init: freePageCount %h", freePageCount.read);
      end
      else begin
         // NOTE: maximum freeQueueDepth-1
         freePageCount.increment(1);
      end
   endrule

   // assign available pages to packet id.
   rule handle_alloc_req;
      let v <- toGet(outstanding_malloc).get;
      let id <- proxy.idResponse.get;
      $display("MemMgmt:: Allocating pages for packet id %d packet size %d", id, v);
      // Corner case when v is close to 4kb.
      let mask = (1 << valueOf(PageAddrLen)) - 1;
      Bit#(PageIdx) nPages = truncate(((v + mask) & (~mask)) >> valueOf(PageAddrLen));
      $display("MemMgmt::handle_malloc allocate nPage=%d", nPages);
      let hasSpace <- freePageCount.maybeDecrement(unpack(nPages));
      if (hasSpace) begin
         reqBurstLen.update(nPages);
         reqSglIndex.update(0);
         lastSegment <= tagged Invalid;
         barr0 <= extend(((v+mask) & (~mask)) >> valueOf(PageAddrLen));
         packetId <= id;
      end
      else begin
         $display("Error:: insufficient space %d instead of %d", freePageCount.read, nPages);
         mallocDoneFifo.enq(tagged Invalid);
      end
   endrule

   rule generate_sglist if (reqBurstLen._read > 0 && !free_started);
      let segment <- toGet(freePageList).get;
      // assume fixed page size of 256 bytes
      iommu.request.sglist(packetId, extend(reqSglIndex._read), extend(segment), 256);
      // add current page(segment) to the front of a linked list
      portsel(pagemap, 0).request.put(BRAMRequest{write:True, responseOnWrite:False, address:segment, datain: lastSegment});
      reqBurstLen.decr(1);
      reqSglIndex.incr(1);
      lastSegment <= tagged Valid segment;
      if (reqBurstLen._read == 1) begin
         iommu.request.region(packetId, 0, 0, 0, 0, 0, 0, barr0, 0);
         // map id to linked-list of pages
         portsel(idmap, 0).request.put(BRAMRequest{write:True, responseOnWrite:False, address:packetId, datain:tagged Valid segment});
         mallocDoneFifo.enq(tagged Valid packetId);
`ifdef DEBUG
         indication.memory_allocated(packetId);
`endif
      end
      $display("MemMgmt:: id=%d, segmentIdx=%x", packetId, segment);
   endrule

   rule handle_free_req if (!free_started);
      let sglId <- toGet(outstanding_free).get;
      free_started <= True;
      portsel(idmap, 1).request.put(BRAMRequest{write:False, responseOnWrite:False, address:sglId, datain:?});
      idToFree <= sglId;
      if (verbose) $display("MemMgmt::start_free_sglist %h", sglId);
   endrule

   rule report_error;
      let v <- toGet(memMgmtErrorFifo).get;
`ifdef DEBUG
      indication.error(extend(pack(v.errorType)), v.id);
`endif
      if (verbose) $display("MemMgmt::free_error: memMgmt error");
   endrule

   rule del_id_metadata if (free_started);
      Maybe#(Bit#(PageIdx)) segment <- portsel(idmap, 1).response.get;
      case (segment) matches
         tagged Valid .page: begin
            portsel(idmap, 1).request.put(BRAMRequest{write:True, responseOnWrite:False, address: idToFree, datain: tagged Invalid});
            portsel(pagemap, 1).request.put(BRAMRequest{write:False, responseOnWrite:False, address: page, datain:?});
            $display("MemMgmt::free_idmap ", fshow(page));
            currSegement <= page;
         end
         tagged Invalid:
            memMgmtErrorFifo.enq(MemMgmtError{errorType: MemMgmtErrorInvalidPacketId, id: idToFree});
      endcase
   endrule

   rule del_page_metadata if (free_started);
      Maybe#(Bit#(PageIdx)) segment <- portsel(pagemap, 1).response.get;
      case (segment) matches
         tagged Valid .page: begin
            currSegement <= page;
            pagePointerFifo.enq(page);
         end
         tagged Invalid: begin
            free_started <= False;
`ifdef DEBUG
            indication.packet_freed(idToFree);
`endif
         end
      endcase
      // return current page to free page list
      portsel(pagemap, 1).request.put(BRAMRequest{write:True, responseOnWrite:False, address: currSegement, datain: tagged Invalid});
      freePageList.enq(currSegement);
      freePageCount.increment(1);
      if (verbose) $display("MemMgmt:: segment ", fshow(segment));
   endrule

   rule read_next_page_metadata if (free_started);
      let page <- toGet(pagePointerFifo).get;
      portsel(pagemap, 1).request.put(BRAMRequest{write:False, responseOnWrite:False, address:page, datain:?});
      if (verbose) $display("MemMgmt:: read next page ", fshow(page));
   endrule

   method Action init_mem();
      freePageList.clear;
      freePageCount.decrement(freePageCount.read);
      inited <= False;
   endmethod
   interface Put mallocReq;
      method Action put(Bit#(EtherLen) sz);
         $display("MemMgmt:: %d: req page=%d", cycle, freePageCount.read);
         outstanding_malloc.enq(sz);
         iommu.request.idRequest(0);
         allocCnt <= allocCnt + 1;
      endmethod
   endinterface
   interface Get mallocDone = toGet(mallocDoneFifo);
   interface Put freeReq;
      method Action put(Bit#(32) id);
         $display("MemMgmt:: free request %h", id);
         iommu.request.idReturn(id);
         outstanding_free.enq(id);
         freeCnt <= freeCnt + 1;
      endmethod
   endinterface
   interface Get freeDone = toGet(freeDoneFifo);
   interface MMU mmu = iommu;
   method MemMgmtDbgRec dbg;
      return MemMgmtDbgRec { allocCnt: allocCnt, freeCnt: freeCnt };
   endmethod
endmodule

