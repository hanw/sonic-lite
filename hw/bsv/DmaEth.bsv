// Copyright (c) 2015 Connectal Project

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


// Copyright (c) 2016 Cornell

import Clocks::*;
import Vector::*;
import BuildVector::*;
import FIFO::*;
import FIFOF::*;
import GetPut::*;
import Connectable::*;
import Probe::*;

import ConnectalConfig::*;
import Pipe::*;
import MemTypes::*;
import MemReadEngine::*;
import MemWriteEngine::*;
import HostInterface::*;
import DefaultValue::*;

import Ethernet::*;
import PacketBuffer::*;
`include "ConnectalProjectConfig.bsv"

interface DmaRequest;
   //
   // Configures burstLen used by DMA transfers. Only needed for performance tuning if default value does not perform well.
   //
   method Action writeRequestSize(Bit#(16) burstLenBytes);
   //
   // Sets the DMA read request size. May be larger than writeRequestSize, depending on the host system chipset and configuration.
   //
   method Action readRequestSize(Bit#(16) readRequestBytes);
   //
   // Requests a transferToFpga of system memory, streaming the data to the toFpga PipeOut
   // @param objId the reference to the memory object allocated by portalAlloc
   // @param base  offset, in bytes, from which to start reading
   // @param bytes number of bytes to read, must be a multiple of the buswidth in bytes
   // @param tag   identifier for the request
   method Action transferToFpga(Bit#(32) objId, Bit#(32) base, Bit#(32) bytes, Bit#(8) tag);
   // 
   method Action objTransferFromFpga(Bit#(8) id, Bit#(32) objId);
endinterface

interface DmaIndication;
   // Indicates completion of transferToFpga request, identified by tag, from offset base of objId
   method Action transferToFpgaDone(Bit#(32) objId, Bit#(32) base, Bit#(8) tag, Bit#(32) cycles);
   // Indicates completion of transferFromFpga request, identified by tag, to offset base of objId
   method Action transferFromFpgaDone(Bit#(32) objId, Bit#(32) base, Bit#(8) tag, Bit#(32) cycles);
endinterface

//
// DmaController controls multiple channels of DMA to/from system memory
// @param numChannels: the maximum number of simultaneous transferToFpga and transferFromFpga streams
interface DmaController#(numeric type numChannels);
   // request from software
   interface Vector#(numChannels,DmaRequest) request;
   // data out to application logic
   interface Vector#(numChannels,PktWriteClient) networkWriteClient;
   // data in from application logic
   interface Vector#(numChannels,PktReadClient) networkReadClient;
   // memory interfaces connected to MemServer
   interface Vector#(1,MemReadClient#(DataBusWidth))      readClient;
   interface Vector#(1,MemWriteClient#(DataBusWidth))     writeClient;
endinterface

typedef 15 NumOutstandingRequests;
typedef TMul#(NumOutstandingRequests,TMul#(32,4)) BufferSizeBytes;

function Bit#(dsz) memdatafToData(MemDataF#(dsz) mdf); return mdf.data; endfunction

module mkDmaController#(Vector#(numChannels,DmaIndication) indication, Clock txClock, Reset txReset)(DmaController#(numChannels))
   provisos (Add#(1, a__, numChannels),
             Add#(b__, TLog#(numChannels), TAdd#(1, TLog#(TMul#(NumOutstandingRequests, numChannels)))),
             Add#(c__, TLog#(numChannels), MemTagSize), // from MemReadEngine
             Add#(d__, TLog#(numChannels), TLog#(TMul#(NumOutstandingRequests, numChannels))),
             FunnelPipesPipelined#(1, numChannels, MemTypes::MemData#(DataBusWidth), 2),
             FunnelPipesPipelined#(1, numChannels, MemTypes::MemRequest, 2),
             FunnelPipesPipelined#(1, numChannels, Bit#(6), 2)
             );

   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();
   let verbose = True;

   MemReadEngine#(DataBusWidth,DataBusWidth,NumOutstandingRequests,numChannels)  re <- mkMemReadEngineBuff(valueOf(BufferSizeBytes));
   MemWriteEngine#(DataBusWidth,DataBusWidth,NumOutstandingRequests,numChannels) we <- mkMemWriteEngineBuff(valueOf(BufferSizeBytes));

   Vector#(numChannels, FIFO#(MemengineCmd)) readCmds <- replicateM(mkSizedFIFO(valueOf(NumOutstandingRequests)));
   Vector#(numChannels, FIFO#(MemengineCmd)) writeCmds <- replicateM(mkSizedFIFO(valueOf(NumOutstandingRequests)));

   Vector#(numChannels, FIFO#(Tuple3#(Bit#(32),Bit#(32),Bit#(32)))) readReqs <- replicateM(mkSizedFIFO(valueOf(NumOutstandingRequests)));
   Vector#(numChannels, FIFO#(Tuple3#(Bit#(32),Bit#(32),Bit#(32)))) writeReqs <- replicateM(mkSizedFIFO(valueOf(NumOutstandingRequests)));

   Vector#(numChannels, FIFOF#(EtherData)) transferToFpgaFifo <- replicateM(mkFIFOF());

   Vector#(numChannels, FIFO#(Bit#(8))) writeTags <- replicateM(mkSizedFIFO(valueOf(NumOutstandingRequests)));
   Vector#(numChannels, FIFO#(Bit#(8))) readTags <- replicateM(mkSizedFIFO(valueOf(NumOutstandingRequests)));

   Vector#(numChannels, SyncFIFOIfc#(EtherData)) dmaToRing <- replicateM(mkSyncFIFO(8, defaultClock, defaultReset, txClock));
   Vector#(numChannels, FIFO#(Bit#(32))) readLens <- replicateM(mkSizedFIFO(valueOf(NumOutstandingRequests)));

   Vector#(numChannels, SyncFIFOIfc#(EtherData)) ringToDma <- replicateM(mkSyncFIFO(8, txClock, txReset, defaultClock));
   Vector#(numChannels, FIFO#(EtherData)) ringToDmaData <- replicateM(mkFIFO(clocked_by txClock, reset_by txReset));
   Vector#(numChannels, FIFO#(Bit#(EtherLen))) ringToDmaLen <- replicateM(mkFIFO(clocked_by txClock, reset_by txReset));
   Vector#(numChannels, FIFO#(EtherReq)) ringToDmaReq <- replicateM(mkFIFO(clocked_by txClock, reset_by txReset));
   Vector#(numChannels, SyncFIFOIfc#(Bit#(32)))   writeLens <- replicateM(mkSyncFIFO(valueOf(NumOutstandingRequests), txClock, txReset, defaultClock));
   Vector#(numChannels, Vector#(4, Reg#(Bit#(32)))) writeObjs <- replicateM(replicateM(mkReg(0)));
   Vector#(numChannels, Reg#(Bit#(8))) writeObjsCurIdx <- replicateM(mkReg(0));

   Reg#(Bit#(BurstLenSize)) writeRequestSizeReg <- mkReg(64);
   Reg#(Bit#(BurstLenSize)) readRequestSizeReg <- mkReg(256);
   Reg#(Bit#(32)) cyclesReg <- mkReg(0);

   rule countCycles;
      cyclesReg <= cyclesReg + 1;
   endrule

   Vector#(numChannels, Probe#(Bit#(MemTagSize))) probe_readReq <- replicateM(mkProbe);
   Vector#(numChannels, Probe#(Bool)) probe_readLast <- replicateM(mkProbe);
   Vector#(numChannels, Probe#(Bit#(8))) probe_readDone <- replicateM(mkProbe);
   Vector#(numChannels, Probe#(Bit#(32))) probe_readCount <- replicateM(mkProbe);

   function Bit#(16) generateBitMask(Bit#(32) bytes);
      let x = 'hffff;
      let mask = bytes == 0 ? 0 : x << (16 - bytes);
      return mask;
   endfunction
   // a must be multiple of 2
   function Bit#(32) findNearestMultiple(Bit#(32) num, Bit#(32) a);
      let x = num & (a-1);
      return num - x  + ((x + a-1) & a );
   endfunction

   for (Integer channel = 0; channel < valueOf(numChannels); channel = channel + 1) begin
      Reg#(Bit#(32)) readCount <- mkReg(0);
      Reg#(Bool) readProcessing <- mkReg(False);
      Reg#(Bool) writeProcessing <- mkReg(False);

      rule transferToFpgaReqRule (!readProcessing);
         let cmd <- toGet(readCmds[channel]).get();
         if (verbose) $display ("transferToFpgaReqRule [%d / %d]", channel, valueOf(numChannels));
         readLens[channel].enq(cmd.len);
         cmd.len = findNearestMultiple(cmd.len, 16);
         readReqs[channel].enq(tuple3(cmd.sglId, cmd.base, cyclesReg));
         probe_readReq[channel] <= cmd.tag;
         re.readServers[channel].request.put(cmd);
         readProcessing <= True;
      endrule
      rule transferToFpgaDataRule (readProcessing);
         let mdf <- toGet(re.readServers[channel].data).get();
         probe_readLast[channel] <= mdf.last;
         Bit#(32) count = readCount + 1;
         Bit#(32) bytes = 16;
         if (mdf.last) begin
            bytes = readLens[channel].first() & 'hf;
            if (bytes == 0)
               bytes = 16;
            $display ("readDataRule last %d", bytes);
         end
         let mask = generateBitMask(bytes);
         EtherData etherData = defaultValue;
         etherData.sop = (count == 1 ? True : False);//mdf.first;
         etherData.eop = mdf.last;
         etherData.data = mdf.data;
         etherData.mask = mask;

         if (mdf.last) begin
            if (verbose) $display ("readDataRule [%d] mdf.last", channel);
            readTags[channel].enq(extend(mdf.tag));
            readLens[channel].deq();
            count = 0;
         end
         probe_readCount[channel] <= count;
         readCount <= count;
         transferToFpgaFifo[channel].enq(etherData);
      endrule
      rule transferToFpgaDoneRule (readProcessing);
         match { .objId, .base, .cycles} <- toGet(readReqs[channel]).get();
         cycles = cycles - cyclesReg;
`ifdef MEMENGINE_REQUEST_CYCLES
         let tagcycles <- toGet(re.readServers[channel].requestCycles).get();
         cycles = tagcycles.cycles;
`endif
         //let done <- re.readServers[channel].done.get();
         let tag <- toGet(readTags[channel]).get();
         probe_readDone[channel] <= tag;
         indication[channel].transferToFpgaDone(objId, base, tag, cycles);
         readProcessing <= False;
      endrule
      // From DMA to packet buffer
      rule transferToNetwork;
         EtherData v <- toGet(transferToFpgaFifo[channel]).get;
         if (v.mask!=0) begin
            dmaToRing[channel].enq(v);
         end
      endrule

      // PktReadClient
      rule transferFromNetworkStart;
         let pktLen <- toGet(ringToDmaLen[channel]).get;
         ringToDmaReq[channel].enq(EtherReq{len: pktLen});
         writeLens[channel].enq(zeroExtend(pktLen));
      endrule
      rule transferFromNetworkData;
         let v <- toGet(ringToDmaData[channel]).get;
         if (verbose) $display ("transferFromNetworkData %x %d %d %h %d", v.data, v.sop, v.eop, ringToDma[channel].notFull(), valueOf(BufferSizeBytes));
         ringToDma[channel].enq(v);
      endrule
      // From Packet buffer to DMA
      rule transferFromNetwork;
         EtherData v <- toGet(ringToDma[channel]).get;
         if (verbose) $display ("writeData %x %d %d", v.data, v.sop, v.eop);
         toPut(we.writeServers[channel].data).put(v.data);
         if (v.sop) begin     // parallalize dma
            let pktLen = findNearestMultiple(writeLens[channel].first, 16);
            let vec = writeObjs[channel];
            let idx = writeObjsCurIdx[channel];
            writeCmds[channel].enq(MemengineCmd {sglId:truncate(vec[idx]),   // TODO
            //writeCmds[channel].enq(MemengineCmd {sglId:0,   // TODO
                        base:0, 
                        burstLen: extend(writeRequestSizeReg),
                        len: pktLen,
                        tag:0
                        });
            writeLens[channel].deq;
            writeObjsCurIdx[channel] <= (writeObjsCurIdx[channel] + 1) & 'h3;
         end
      endrule
      rule transferFromFpgaReqRule (!writeProcessing);
         let cmd <- toGet(writeCmds[channel]).get();
         if (verbose) $display ("transferfromFpgaReqRule [%d]", channel);
         writeReqs[channel].enq(tuple3(cmd.sglId, cmd.base, cyclesReg));
         we.writeServers[channel].request.put(cmd);
         writeTags[channel].enq(extend(cmd.tag));
         writeProcessing <= True;
      endrule
      rule transferFromFpgaDoneRule (writeProcessing);
         match { .objId, .base, .cycles } <- toGet(writeReqs[channel]).get();
         cycles = cycles - cyclesReg;
`ifdef MEMENGINE_REQUEST_CYCLES
         let tagcycles <- toGet(we.writeServers[channel].requestCycles).get();
         cycles = tagcycles.cycles;
`endif
         let done <- we.writeServers[channel].done.get();
         let tag <- toGet(writeTags[channel]).get();
         if (verbose) $display ("transferFromFpgaDoneRule done");
         indication[channel].transferFromFpgaDone(objId, base, tag, cycles);
         writeProcessing <= False;
      endrule
   end

   function DmaRequest dmaRequestInterface(Integer channel);
      return (interface DmaRequest;
         method Action writeRequestSize(Bit#(16) burstLenBytes);
            writeRequestSizeReg <= truncate(burstLenBytes);
         endmethod
         method Action readRequestSize(Bit#(16) burstLenBytes);
            readRequestSizeReg <= truncate(burstLenBytes);
         endmethod
         method Action transferToFpga(Bit#(32) objId, Bit#(32) base, Bit#(32) bytes, Bit#(8) tag);
            readCmds[channel].enq(MemengineCmd {sglId: truncate(objId),
                                                base: extend(base),
                                                burstLen: extend(readRequestSizeReg),
                                                len: bytes,
                                                tag: truncate(tag)
                                                });
         endmethod
         method Action objTransferFromFpga(Bit#(8) id, Bit#(32) objId);
            if (id < 4) writeObjs[channel][id] <= objId;
         endmethod
         endinterface);
   endfunction
   function PipeIn#(Bit#(dsz)) writeServerData(MemWriteEngineServer#(dsz) s); return s.data; endfunction

   Vector#(numChannels, PktWriteClient) pktWriteClient = newVector;
   for (Integer i = 0 ; i < valueOf(numChannels) ; i = i + 1)
      pktWriteClient[i] = (interface PktWriteClient;
         interface writeData = toGet(dmaToRing[i]);
      endinterface);
   Vector#(numChannels, PktReadClient) pktReadClient = newVector;
   for (Integer i = 0 ; i < valueOf(numChannels); i = i + 1)
      pktReadClient[i] = (interface PktReadClient;
         interface readData = toPut(ringToDmaData[i]);
         interface readLen = toPut(ringToDmaLen[i]);
         interface readReq = toGet(ringToDmaReq[i]);
      endinterface);

   interface Vector request = genWith(dmaRequestInterface);
   interface readClient = vec(re.dmaClient);
   interface writeClient = vec(we.dmaClient);
   interface networkWriteClient = pktWriteClient; 
   interface networkReadClient = pktReadClient;
endmodule
