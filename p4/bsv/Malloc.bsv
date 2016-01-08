import BuildVector::*;
import Cntrs::*;
import GetPut::*;
import ClientServer::*;
import StmtFSM::*;
import FIFO::*;
import FIFOF::*;
import Pipe::*;
import Vector::*;
import ConnectalMemory::*;
import ConfigCounter::*;

typedef 12 PacketAddrLen;
typedef 8  PageAddrLen;
typedef 16 MemoryAddrLen;
typedef TExp#(PageAddrLen) PageSize;
typedef TSub#(MemoryAddrLen, PageAddrLen) PageIdx;
typedef TExp#(PageIdx) FreeQueueDepth;

Integer pageSize = valueOf(PageSize);
Integer pageIdx = valueOf(PageIdx);
Integer freeQueueDepth = valueOf(FreeQueueDepth);

interface MallocIndication;
   method Action id_resp(Bit#(32) id);
endinterface

interface Malloc;
   method Action init_mem();
   method Action alloc_mem(Bit#(PacketAddrLen) v);
   method Action free_mem(Bit#(PageIdx) v);
   interface PipeOut#(Tuple2#(Bit#(32), Bit#(PageIdx))) pageAllocated;
   interface PipeOut#(Tuple2#(Bit#(32), Bit#(64))) regionAllocated;
   interface MMUIndication mmuIndication;
endinterface

module mkMalloc#(MallocIndication indication)(Malloc);
   Reg#(Bool) started <- mkReg(False);
   Reg#(Bool) inited <- mkReg(False);
   FIFOF#(Bit#(PacketAddrLen)) mallocReqs <- mkFIFOF;
   FIFOF#(Bit#(32)) incomingIds <- mkSizedFIFOF(2);
   FIFOF#(Bit#(PageIdx)) free_list <- mkSizedFIFOF(freeQueueDepth);
   FIFOF#(Tuple2#(Bit#(32), Bit#(PageIdx))) page_fifo <- mkFIFOF;
   FIFOF#(Tuple2#(Bit#(32), Bit#(64))) region_fifo <- mkFIFOF;
   Count#(Bit#(PageIdx)) pageRequested <- mkCount(0);
   Count#(Bit#(PageIdx)) pageAvail <- mkCount(0);
   Reg#(Bit#(32)) packetId <- mkReg(0);
   Reg#(Bit#(64)) barr0 <- mkReg(0);

   let verbose = True;
   Reg#(Bit#(32)) cycle <- mkReg(0);
   rule cycleRule if (verbose);
      cycle <= cycle + 1;
   endrule

   rule init_mem_allocator if (!inited);
      free_list.enq(pageAvail._read);
      if (pageAvail._read == fromInteger(freeQueueDepth-1)) begin
         inited <= True;
      end
      else begin
         // NOTE: maximum freeQueueDepth-1
         pageAvail.incr(1);
         //$display("free_list enq %d/%d", pageAvail._read, freeQueueDepth);
      end
   endrule

   rule handle_malloc;
      let v <- toGet(mallocReqs).get;
      let id <- toGet(incomingIds).get;
      $display("Allocating pages for packet id %d packet size %d", id, v);
      // Mask 'hF00 must be equal to PacketAddrLen
      // Corner case when v is close to 4kb.
      Bit#(PageIdx) nPages = truncate(((v + 'hFF) & 'hF00) >> valueOf(PageAddrLen));
      if (pageAvail._read < nPages) begin
         $display("%d: Not enough free pages, %d instead of %d", cycle, pageAvail._read, nPages);
      end
      else begin
         pageRequested.update(nPages);
         barr0 <= extend(((v+'hFF) & 'hF00) >> valueOf(PageAddrLen));
         packetId <= id;
      end
   endrule

   rule generate_sglist if (pageRequested._read > 0);
      let v <- toGet(free_list).get;
      page_fifo.enq(tuple2(packetId, v));
      pageAvail.decr(1);
      pageRequested.decr(1);
      if (pageRequested._read == 1) begin
         region_fifo.enq(tuple2(packetId, barr0));
      end
      $display("%d: allocate free page id=%d", cycle, v);
   endrule

   method Action init_mem();
      free_list.clear;
      pageAvail._write(0);
      inited <= False;
   endmethod
   method Action alloc_mem(Bit#(PacketAddrLen) sz);
      mallocReqs.enq(sz);
      $display("malloc %d: allocate memory available page=%d", cycle, pageAvail._read);
   endmethod
   method Action free_mem(Bit#(PageIdx) v);
      if (free_list.notFull) begin
         free_list.enq(v);
      end
   endmethod
   interface PipeOut pageAllocated = toPipeOut(page_fifo);
   interface PipeOut regionAllocated = toPipeOut(region_fifo);
   interface MMUIndication mmuIndication;
      method Action idResponse(Bit#(32) sglId);
         $display("malloc %d: sglid=%d", cycle, sglId);
         incomingIds.enq(sglId);
         indication.id_resp(sglId);
      endmethod
//      method Action configResp(Bit#(32) sglId);
//
//      endmethod
//      method Action error(Bit#(32) code, Bit#(32) sglId, Bit#(64) offset, Bit#(64) extra);
//
//      endmethod
   endinterface
endmodule
