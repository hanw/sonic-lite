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

import Ethernet::*;
import PacketBuffer::*;

interface SonicPins;
   method Action osc_50(Bit#(1) b3b, Bit#(1) b3d, Bit#(1) b4a, Bit#(1) b4d, Bit#(1) b7a, Bit#(1) b7d, Bit#(1) b8a, Bit#(1) b8d);
   (* prefix="" *)
   method Action pcie_perst_n(Bit#(1) pcie_perst_n);
   method Action user_reset_n(Bit#(1) user_reset_n);
endinterface

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

interface SonicTopRequest;
   method Action sonic_read_version();
   method Action startRead(Bit#(32) pointer, Bit#(32) offset, Bit#(32) numBytes, Bit#(32) burstLen);
   method Action startWrite(Bit#(32) pointer, Bit#(32) offset, Bit#(32) numWords, Bit#(32) burstLen);
   method Action writePacketData(Bit#(64) upper, Bit#(64) lower, Bit#(1) sop, Bit#(1) eop);
endinterface

interface SonicTopIndication;
   method Action sonic_read_version_resp(Bit#(32) version);
   method Action readDone(Bit#(32) mismatchCnt);
   method Action writeDone(Bit#(32) v);
   method Action writeTxCred(UInt#(32) v);
   method Action writeRxCred(UInt#(32) v);
endinterface

interface SonicTop;
   interface SonicTopRequest request;
   interface Vector#(1, MemWriteClient#(DataBusWidth)) dmaWriteClient;
   interface Vector#(1, MemReadClient#(DataBusWidth)) dmaReadClient;
   interface SonicPins pins;
endinterface

typedef 12 NumOutstandingRequests;
typedef TMul#(NumOutstandingRequests, TMul#(32, 4)) BufferSizeBytes;
module mkSonicTop#(SonicTopIndication indication)(SonicTop);
   Clock defaultClock <- exposeCurrentClock();

   let verbose = True;

   // Tx Path
   Reg#(Bit#(32)) cycle <- mkReg(0);
   Reg#(TxDesc) newTxDesc <- mkReg(unpack(0));
   FIFOF#(TxDesc) txDescQueue <- mkSizedFIFOF(valueof(TxCredTotal));
   ConfigCounter#(32) txCredFreed <- mkConfigCounter(0);
   FIFOF#(UInt#(32)) txCredCf <- mkSizedFIFOF(8);

   FIFOF#(void) txMacCfs <- mkSizedFIFOF(1);

   MemreadEngine#(DataBusWidth,NumOutstandingRequests,1) re <- mkMemreadEngineBuff(valueOf(BufferSizeBytes));
   PacketBuffer txPktBuff <- mkPacketBuffer();

   rule everyCycle;
      cycle <= cycle + 1;
   endrule

   rule enqTxDesc (txDescQueue.notFull && newTxDesc.nDesc > 0);
      if (verbose) $display("Test: Enqueue TxDesc %x %d", newTxDesc.offset, newTxDesc.len);
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
      if (verbose) $display("Write back cred %d", v);
   endrule

   rule dmaRead;
      let v <- toGet(txDescQueue).get;
      //FIXME: burstlen
      re.read_servers[0].cmdServer.request.put(MemengineCmd{tag:0, sglId:v.sglId, base:v.offset, len:v.len,
                                               burstLen:truncate(v.len)});
   endrule

   rule readData;
      if (re.read_servers[0].memDataPipe.notEmpty()) begin
         let v <- toGet(re.read_servers[0].memDataPipe).get;
         txPktBuff.writeServer.writeData.put(EtherData{sop: v.first, eop: v.last, data:v.data});
      end
   endrule

   rule txMacStart;
      let pktLen <- txPktBuff.readServer.readLen.get;
      txPktBuff.readServer.readReq.put(EtherReq{len: pktLen});
      txMacCfs.enq(?);
   endrule

   rule txMacInProgress if (txMacCfs.notEmpty);
      let v <- txPktBuff.readServer.readData.get;
      if (verbose) $display("Send: data=%x sop=%x eop=%x", v.data, v.sop, v.eop);
      // rule to read 128 bit packet from buffer, and enqueue 64 bit twice to txfifo


      if (v.eop) begin
         txCredFreed.increment(1);
         // tigger writeback is freed txcred is more than threshold
         if ((txCredFreed.read>=fromInteger(valueOf(TxCredThres))) && txCredCf.notFull) begin
            txCredCf.enq(txCredFreed.read);
            txCredFreed.decrement(txCredFreed.read);
         end
         txMacCfs.deq;
      end
   endrule

   // rule to clock crossing txfifo to 156.25MHz domain, and output MAC interface.

   rule dmaReadFinish;
      // clear cmdServer response
      let rv <- re.read_servers[0].cmdServer.response.get;
   endrule

   // Rx Path
   FIFOF#(RxDesc)            rxDescQueue <- mkSizedFIFOF(valueof(RxCredTotal));
   Reg#(RxDesc)              newRxDesc   <- mkReg(unpack(0));
   Reg#(Bit#(32))            totalRxDesc <- mkReg(0);

   FIFOF#(Bit#(EtherLen)) wrCfs       <- mkSizedFIFOF(1);
   FIFOF#(Bool)              finishFifo  <- mkFIFOF;
   Reg#(Bit#(EtherLen))   currDmaWrLen <- mkReg(0);

   PacketBuffer                rxPktBuff <- mkPacketBuffer();

   MemwriteEngine#(DataBusWidth,2,1) we <- mkMemwriteEngine;
   rule enqRxDesc(rxDescQueue.notFull && newRxDesc.nDesc>0);
      rxDescQueue.enq(newRxDesc);
      newRxDesc.nDesc <= newRxDesc.nDesc-1;
      totalRxDesc <= totalRxDesc+1;
      $display("SonicTop::enqRxDesc PacketGen %d", totalRxDesc);
   endrule
   rule dmaWriteStart;
      let rxDesc <- toGet(rxDescQueue).get;
      let pktLen <- rxPktBuff.readServer.readLen.get;
      we.write_servers[0].cmdServer.request.put(MemengineCmd{tag:0, sglId:rxDesc.sglId,
                                                base:extend(rxDesc.offset), len:extend(pktLen),
                                                burstLen:truncate(pktLen)});
      $display("SonicTop::dmaWriteStart offset=%x pktlen=%d", rxDesc.offset, pktLen);
      rxPktBuff.readServer.readReq.put(EtherReq{len: pktLen});
      wrCfs.enq(pktLen);
   endrule
   rule dmaWriteInProgress if (wrCfs.notEmpty);
      let v <- rxPktBuff.readServer.readData.get;
      we.write_servers[0].dataPipe.enq(extend(v.data));
   endrule
   rule dmaWriteFinish;
      $display("SonicTop::dmaWriteFinish");
      let rv <- we.write_servers[0].cmdServer.response.get;
      wrCfs.deq;
      indication.writeDone(0);
   endrule

   // rule to clock crossing from 156.25MHz to 250MHz with 64bit
   // rule to pack 2x64 read from MAC interface to 128bit, and write to rxbuff

   // Network MAC and PHY

   Reg#(Bit#(32)) tx_cnt <- mkReg(0);
   interface pins = (interface SonicPins;
      // Clocks
      // Resets
      // SFP+
   endinterface);
   interface dmaWriteClient = vec(we.dmaClient);
   interface dmaReadClient = vec(re.dmaClient);
   interface SonicTopRequest request;
      method Action sonic_read_version();
         let v = `SonicVersion; //Defined in Makefile as time of compilation.
         indication.sonic_read_version_resp(v);
      endmethod
      method Action startRead(Bit#(32) rp, Bit#(32) off, Bit#(32) nb, Bit#(32) bl);
         $display("rp=%x offset=%x len=%x burstLen=%x, tx_cnt=%d", rp, off, nb, bl, tx_cnt);
         newTxDesc <= TxDesc{sglId:rp, offset:extend(off), len:nb, burstLen:truncate(bl), nDesc:1};
         tx_cnt <= tx_cnt + 1;
      endmethod
      method Action startWrite(Bit#(32) rp, Bit#(32) off, Bit#(32) nb, Bit#(32) bl);
         $display("rp=%x offset=%x len=%x burstLen=%x", rp, off, nb, bl);
         newRxDesc <= RxDesc{sglId:rp, offset:extend(off), len:nb, burstLen:truncate(bl), nDesc:1};
      endmethod
      method Action writePacketData(Bit#(64) upper, Bit#(64) lower, Bit#(1) sop, Bit#(1) eop);
         let d = EtherData{data: {upper, lower}, sop: unpack(sop), eop: unpack(eop)};
         rxPktBuff.writeServer.writeData.put(d);
      endmethod
   endinterface
endmodule
