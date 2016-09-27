package TbTop;

import BuildVector::*;
import GetPut::*;
import ClientServer::*;
import DefaultValue::*;
import StmtFSM::*;
import FIFO::*;
import Pipe::*;
import Vector::*;
import ConnectalMemory::*;

import MemTypes::*;
import MemServerIndication::*;
import MMUIndication::*;
import SharedBuff::*;
import Ethernet::*;
import PacketBuffer::*;

import Malloc::*;

typedef 12 PktSize; // maximum 4096b
typedef TDiv#(`DataBusWidth, 32) WordsPerBeat;

interface TbIndication;
   method Action read_version_resp(Bit#(32) version);
   method Action malloc_resp(Bit#(32) sglId);
endinterface

interface TbRequest;
   method Action read_version();
   method Action allocPacketBuff(Bit#(PktSize) sz);
   method Action readPacketBuff(Bit#(16) addr);
   method Action writePacketBuff(Bit#(16) addr, Bit#(64) data);
   method Action freePacketBuff(Bit#(32) id);
   method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
endinterface

interface TbTop;
   interface TbRequest request;
endinterface
module mkTbTop#(TbIndication indication, ConnectalMemory::MemServerIndication memServerIndication)(TbTop);

   let verbose = True;
   // read client interface
   FIFO#(MemRequest) readReqFifo <-mkSizedFIFO(4);
   FIFO#(MemData#(`DataBusWidth)) readDataFifo <- mkSizedFIFO(32);
   MemReadClient#(`DataBusWidth) dmaReadClient = (interface MemReadClient;
   interface Get readReq = toGet(readReqFifo);
   interface Put readData = toPut(readDataFifo);
   endinterface);

   // write client interface
   FIFO#(MemRequest) writeReqFifo <- mkSizedFIFO(4);
   FIFO#(MemData#(`DataBusWidth)) writeDataFifo <- mkSizedFIFO(32);
   FIFO#(Bit#(MemTagSize)) writeDoneFifo <- mkSizedFIFO(4);
   MemWriteClient#(`DataBusWidth) dmaWriteClient = (interface MemWriteClient;
   interface Get writeReq = toGet(writeReqFifo);
   interface Get writeData = toGet(writeDataFifo);
   interface Put writeDone = toPut(writeDoneFifo);
   endinterface);

   SharedBuffer#(12, 128, 1) buff <- mkSharedBuffer(vec(dmaReadClient), vec(dmaWriteClient), memServerIndication);
   PacketBuffer ring_buff <- mkPacketBuffer();

   interface TbRequest request;
      method Action read_version();
         let v= `NicVersion;
         indication.read_version_resp(v);
      endmethod

      method Action allocPacketBuff(Bit#(PktSize) sz);
         if (verbose) $display("TbTop allocPacketBuff: %d", sz);
         buff.malloc(sz);
      endmethod

      method Action readPacketBuff(Bit#(16) addr);
         Bit#(ByteEnableSize) firstbe = 'hffff;
         Bit#(ByteEnableSize) lastbe = 'hffff;
         readReqFifo.enq(MemRequest {sglId: 0, offset: 0, burstLen: 16, tag:0, firstbe: firstbe, lastbe: lastbe});
      endmethod

      method Action writePacketBuff(Bit#(16) addr, Bit#(64) data);
         Bit#(ByteEnableSize) firstbe = 'hffff;
         Bit#(ByteEnableSize) lastbe = 'hffff;
         writeReqFifo.enq(MemRequest {sglId: 0, offset:0, burstLen: 16, tag:0, firstbe: firstbe, lastbe: lastbe});

         function Bit#(8) plusi(Integer i); return fromInteger(i); endfunction
         Vector#(TMul#(4, WordsPerBeat), Bit#(8)) v = genWith(plusi);
         $display("TbTop writePacketBuff: %x", v);
         writeDataFifo.enq(MemData {data: pack(v), tag:0, last:True});
      endmethod

      method Action freePacketBuff(Bit#(32) id);

      endmethod

      method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
         ByteStream#(16) beat = defaultValue;
         beat.data = pack(reverse(data));
         beat.mask = pack(reverse(mask));
         beat.sop = unpack(sop);
         beat.eop = unpack(eop);
         ring_buff.writeServer.writeData.put(beat);
      endmethod

   endinterface
endmodule: mkTbTop

endpackage: TbTop
