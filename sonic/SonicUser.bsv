
// Copyright (c) 2015 Cornell University.

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

import FIFO ::*;
import FIFOF ::*;
import SpecialFIFOs ::*;
import Vector ::*;
import Arith ::*;
import BuildVector::*;
import Pipe ::*;
import GetPut ::*;
import ClientServer::*;
import MemTypes::*;
import MemreadEngine::*;
import MemwriteEngine::*;
import HostInterface::*;
import ConfigCounter::*;

//interface SonicIfc;
//endinterface

typedef 128    TxCredTotal;
typedef 32     TxCredThres;
typedef 100000 TxCredTimeout;

typedef 128    RxCredTotal;
typedef 32     RxCredThres;

typedef TDiv#(DataBusWidth,32) DataBusWords;
typedef struct {
   SGLId sglId;
   Bit#(MemOffsetSize) offset;
   Bit#(32) len;
   Bit#(BurstLenSize) burstLen;
   Bit#(32) nDesc;
} TxDesc deriving (Eq, Bits);

typedef struct {
   SGLId sglId;
   Bit#(MemOffsetSize) offset;
   Bit#(32) len;
   Bit#(BurstLenSize) burstLen;
   Bit#(32) nDesc;
} RxDesc deriving (Eq, Bits);

interface SonicUserRequest;
   method Action sonic_read_version();
   method Action startRead(Bit#(32) pointer, Bit#(32) offset, Bit#(32) numBytes, Bit#(32) burstLen);
   method Action startWrite(Bit#(32) pointer, Bit#(32) offset, Bit#(32) numWords, Bit#(32) burstLen, Bit#(32) iterCnt);
endinterface

interface SonicUserIndication;
   method Action sonic_read_version_resp(Bit#(32) version);
   method Action readDone(Bit#(32) mismatchCnt);
   method Action writeDone(Bit#(32) v);
   method Action writeTxCred(UInt#(32) v);
   method Action writeRxCred(UInt#(32) v);
endinterface

interface SonicUser;
   interface SonicUserRequest request;
   interface Vector#(1, MemWriteClient#(DataBusWidth)) dmaWriteClient;
   interface Vector#(1, MemReadClient#(DataBusWidth)) dmaReadClient;
//   interface SonicIfc sonicifc;
endinterface

typedef 12 NumOutstandingRequests;
typedef TMul#(NumOutstandingRequests, TMul#(32, 4)) BufferSizeBytes;
module mkSonicUser#(SonicUserIndication indication)(SonicUser);
   Clock defaultClock <- exposeCurrentClock();

   let verbose = True;

   Reg#(Bit#(32)) cycle <- mkReg(0);
   Reg#(TxDesc) newTxDesc <- mkReg(unpack(0));
   FIFOF#(TxDesc) txDescQueue <- mkSizedFIFOF(valueof(TxCredTotal));
   ConfigCounter#(32) txCredFreed <- mkConfigCounter(0);
   FIFOF#(UInt#(32)) txCredCf <- mkSizedFIFOF(8);

   MemreadEngine#(DataBusWidth,NumOutstandingRequests,1) re <- mkMemreadEngineBuff(valueOf(BufferSizeBytes));

   rule everyCycle;
      cycle <= cycle + 1;
   endrule

   // Tx Path
   rule enqTxDesc (txDescQueue.notFull && newTxDesc.nDesc > 0);
      if (verbose) $display("Test: Enqueue TxDesc %d %d", newTxDesc.offset, newTxDesc.len);
      txDescQueue.enq(newTxDesc);
      newTxDesc.nDesc <= newTxDesc.nDesc-1;
   endrule

   // Credit Writeback is triggered by either timeout or threshold.
   rule txCreditWritebackTimeout ((cycle % fromInteger(valueOf(TxCredTimeout)) == 0) && !txCredCf.notEmpty);
      if (txCredFreed.read != 0) begin
         indication.writeTxCred(txCredFreed.read);
         txCredFreed.decrement(txCredFreed.read);
      end
   endrule

   rule txCreditWritebackThreshold;
      let v <- toGet(txCredCf).get;
      indication.writeTxCred(v);
   endrule

   rule dmaRead;
      let v <- toGet(txDescQueue).get;
      re.readServers[0].request.put(MemengineCmd{tag:0,
                                                 sglId:v.sglId,
                                                 base:v.offset,
                                                 len:v.len,
                                                 burstLen:v.burstLen});
      txCredFreed.increment(1);
      // tigger writeback is freed txcred is more than threshold
      if ((txCredFreed.read>=fromInteger(valueOf(TxCredThres))) && txCredCf.notFull) begin
          txCredCf.enq(txCredFreed.read);
          txCredFreed.decrement(txCredFreed.read);
      end
   endrule

   rule readData;
      // first pipeline stage
      if (re.dataPipes[0].notEmpty()) begin
         let v <- toGet(re.dataPipes[0]).get;
         // send to MAC
      end
   endrule

   rule finish;
      let rv <- re.readServers[0].response.get;
      // Not Used
   endrule

   // Rx Path
   FIFOF#(RxDesc) rxDescQueue <- mkSizedFIFOF(valueof(RxCredTotal));
   Reg#(RxDesc) newRxDesc <- mkReg(unpack(0));
   Reg#(Bit#(32)) totalRxDesc <- mkReg(0);

   Reg#(Bit#(32)) wrSrcGens <- mkReg(0);
   FIFOF#(Bit#(32)) wrCfs <- mkSizedFIFOF(1);
   FIFOF#(Bool) finishFifo <- mkFIFOF;

   MemwriteEngine#(DataBusWidth,2,1) we <- mkMemwriteEngine;
   rule enqRxDesc(rxDescQueue.notFull && newRxDesc.nDesc>0);
      $display("Test: PacketGen %d", newRxDesc.nDesc);
      rxDescQueue.enq(newRxDesc);
      newRxDesc.nDesc <= newRxDesc.nDesc-1;
   endrule
   rule dmaWriteStart;
      let v <- toGet(rxDescQueue).get;
      we.writeServers[0].request.put(MemengineCmd{tag:0,
                                                  sglId:v.sglId,
                                                  base:extend(v.offset*4),
                                                  len:v.len*4,
                                                  burstLen:truncate(v.burstLen*4)});
      Bit#(32) srcGen = truncate(v.offset/4);
      wrSrcGens <= srcGen;
      $display("start %d, %h 0x%x %h", 1, srcGen, newRxDesc.nDesc, v.offset);
      wrCfs.enq(srcGen);
   endrule
   rule dmaWriteFinish;
      $display("finished");
      let rv <- we.writeServers[0].response.get;
      finishFifo.enq(rv);
   endrule
   rule dmaSrcGen if (wrCfs.notEmpty);
      Vector#(DataBusWords, Bit#(32)) v;
      for (Integer j=0; j<valueof(DataBusWords); j=j+1)
         v[j] = wrSrcGens+fromInteger(j);
      let new_srcGen = wrSrcGens + fromInteger(valueOf(DataBusWords));
      wrSrcGens <= new_srcGen;
      we.dataPipes[0].enq(pack(v));
      if (new_srcGen == wrCfs.first)
         wrCfs.deq;
   endrule
   rule dmaSendIndication;
      let rv <- toGet(finishFifo).get();
      indication.writeDone(0);
   endrule

   interface dmaWriteClient = vec(we.dmaClient);
   interface dmaReadClient = vec(re.dmaClient);
   interface SonicUserRequest request;
      method Action sonic_read_version();
         let v = `SonicVersion; //Defined in Makefile as time of compilation.
         indication.sonic_read_version_resp(v);
      endmethod
      method Action startRead(Bit#(32) rp, Bit#(32) off, Bit#(32) nb, Bit#(32) bl);
         newTxDesc <= TxDesc{sglId:rp, offset:extend(off), len:nb, burstLen:truncate(bl), nDesc:1};
      endmethod
      method Action startWrite(Bit#(32) rp, Bit#(32) off, Bit#(32) nw, Bit#(32) bl, Bit#(32) ic);
         newRxDesc <= RxDesc{sglId:rp, offset:extend(off), len:nw, burstLen:truncate(bl), nDesc:1};
       endmethod
   endinterface
endmodule
