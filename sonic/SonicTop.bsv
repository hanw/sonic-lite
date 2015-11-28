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

import Arith ::*;
import BuildVector::*;
import ClientServer::*;
import ConfigCounter::*;
import Connectable::*;
import DefaultValue::*;
import FIFO ::*;
import FIFOF ::*;
import GetPut ::*;
import Gearbox ::*;
import Pipe ::*;
import SpecialFIFOs ::*;
import Vector ::*;
import ConnectalConfig::*;

import Ethernet::*;
import MemTypes::*;
import MemReadEngine::*;
import MemWriteEngine::*;
import PacketBuffer::*;
import HostInterface::*;
import `PinTypeInclude::*;

typedef 512    TxCredTotal;
typedef 32     TxCredThres;
typedef 100000 TxCredTimeout;

typedef 512    RxCredTotal;
typedef 32     RxCredThres;
typedef 100000 RxCredTimeout;

typedef TDiv#(DataBusWidth,32) DataBusWords;
typedef struct {
   SGLId sglId;
   Bit#(32) offset;
   Bit#(32) len;
   Bit#(BurstLenSize) burstLen;
   Bit#(32) nDesc;
} TxDesc deriving (Eq, Bits);

typedef struct {
   SGLId sglId;
   Bit#(32) offset;
   Bit#(32) len;
   Bit#(BurstLenSize) burstLen;
   Bit#(32) nDesc;
} RxDesc deriving (Eq, Bits);

typedef 16 RxMetadataLen;
typedef struct {
   Bit#(32) filled;
   Bit#(32) len;
   Bit#(64) reserved;
} RxMeta deriving (Eq, Bits);

interface SonicTopRequest;
   method Action sonic_read_version();
   method Action startRead(Bit#(32) pointer, Bit#(32) offset, Bit#(32) numBytes, Bit#(32) burstLen);
   method Action startWrite(Bit#(32) pointer, Bit#(32) offset, Bit#(32) numWords, Bit#(32) burstLen);
   method Action writePacketData(Bit#(64) upper, Bit#(64) lower, Bit#(1) sop, Bit#(1) eop);
   method Action writeMacData(Bit#(64) data, Bit#(1) sop, Bit#(1) eop);
   method Action resetWrite(Bit#(32) qid);
endinterface

interface SonicTopIndication;
   method Action sonic_read_version_resp(Bit#(32) version);
   method Action readDone(Bit#(32) mismatchCnt);
   method Action writeDone(Bit#(32) v);
   method Action writeTxCred(UInt#(32) v);
endinterface

interface SonicTop;
   interface SonicTopRequest request;
   interface Vector#(1, MemWriteClient#(DataBusWidth)) dmaWriteClient;
   interface Vector#(1, MemReadClient#(DataBusWidth)) dmaReadClient;
   interface `PinType pins;
endinterface

typedef 12 NumOutstandingRequests;
typedef TMul#(NumOutstandingRequests, TMul#(32, 4)) BufferSizeBytes;
module mkSonicTop#(Clock derivedClock, Reset derivedReset, SonicTopIndication indication)(SonicTop);
   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

   let verbose = True;

   // Tx Path
   Reg#(Bit#(32)) cycle <- mkReg(0);
   Reg#(TxDesc) newTxDesc <- mkReg(unpack(0));
   FIFOF#(TxDesc) txDescQueue <- mkSizedFIFOF(valueof(TxCredTotal));
   ConfigCounter#(32) txCredFreed <- mkConfigCounter(0);
   FIFOF#(UInt#(32)) txCredCf <- mkSizedFIFOF(8);

   FIFOF#(void) xmitInProgress <- mkSizedFIFOF(1);
   Gearbox#(2, 1, PacketData#(64)) fifoTxData <- mkNto1Gearbox(defaultClock, defaultReset, defaultClock, defaultReset);

   MemReadEngine#(DataBusWidth,DataBusWidth,NumOutstandingRequests,1) re <- mkMemReadEngineBuff(valueOf(BufferSizeBytes));
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
      re.readServers[0].request.put(MemengineCmd{tag:0, sglId:v.sglId, base:v.offset, len:v.len,
                                               burstLen:truncate(v.len)});
   endrule

   rule readData;
      if (re.readServers[0].data.notEmpty()) begin
         let v <- toGet(re.readServers[0].data).get;
         txPktBuff.writeServer.writeData.put(EtherData{sop: v.first, eop: v.last, data:v.data});
      end
   endrule

   rule txMacStart;
      let pktLen <- txPktBuff.readServer.readLen.get;
      txPktBuff.readServer.readReq.put(EtherReq{len: pktLen});
      xmitInProgress.enq(?);
   endrule

   //FIXME::
   function Vector#(2, PacketData#(64)) split(EtherData in);
      Vector#(2, PacketData#(64)) v = defaultValue;
      v[0].sop = in.sop;
      v[0].eop = False;
      v[0].err = 0;
      v[0].empty = 0;
      v[0].data = in.data[63:0];
      v[0].valid = True;
      v[1].sop = False;
      v[1].eop = in.eop;
      v[1].err = 0;
      v[1].empty = 0;
      v[1].data = in.data[127:64];
      v[1].valid = True;
      return v;
   endfunction
   rule txMacInProgress if (xmitInProgress.notEmpty);
      let v <- txPktBuff.readServer.readData.get;
      //if (verbose) $display("Send: data=%x sop=%x eop=%x", v.data, v.sop, v.eop);
      // rule to read 128 bit packet from buffer, and enqueue 64 bit twice to txfifo
      Vector#(2, PacketData#(64)) txdata = split(v);
      fifoTxData.enq(txdata);

      if (v.eop) begin
         txCredFreed.increment(1);
         // tigger writeback is freed txcred is more than threshold
         if ((txCredFreed.read>=fromInteger(valueOf(TxCredThres))) && txCredCf.notFull) begin
            txCredCf.enq(txCredFreed.read);
            txCredFreed.decrement(txCredFreed.read);
         end
         xmitInProgress.deq;
      end
   endrule

 //  rule txMacClockCrossing if (fifoTxData.notEmpty);
 //     let data = fifoTxData.first;
 //     let temp = head(data);
 //     //if(verbose) $display("Send %d data=%x sop=%x eop=%x", cycle, temp.data, temp.sop, temp.eop);
 //     fifoTxData.deq;
 //  endrule

   //SyncFIFOIfc#(Bit#(64)) txMacSyncFifo <- mkSyncFIFO(8, clk_156_25, rst_156_n, host.portalClock);
   //PipeOut#(PacketData) txMacSyncPipeOut = toPipeOut(txMacSyncFifo);
   //PipeIn#(PacketData) txMacSyncPipeIn = toPipeIn(txMacSyncFifo);
   //mkConnection(toPipeOut(txMacFifo), txMacSyncPipeIn);
   //mkConnection(txMacSyncPipeOut, );

   // Rx Path
   FIFOF#(RxDesc)            rxDescQueue <- mkSizedFIFOF(valueof(RxCredTotal));
   FIFOF#(RxMeta)         currRxMetadata <- mkSizedFIFOF(1);
   FIFOF#(Bit#(EtherLen)) recvInProgress <- mkSizedFIFOF(1);
   FIFOF#(Bool)               finishFifo <- mkFIFOF;
   Reg#(RxDesc)                newRxDesc <- mkReg(unpack(0));
   Reg#(Bit#(32))                totalRx <- mkReg(0);
   Reg#(Bit#(EtherLen))     currDmaWrLen <- mkReg(0);
   PacketBuffer                rxPktBuff <- mkPacketBuffer();
   MemWriteEngine#(DataBusWidth,DataBusWidth,2,1) we <- mkMemWriteEngine;
   Gearbox#(1, 2, PacketData#(64)) fifoRxData <- mk1toNGearbox(defaultClock, defaultReset, defaultClock, defaultReset);

   rule enqRxDesc(rxDescQueue.notFull && newRxDesc.nDesc>0);
      rxDescQueue.enq(newRxDesc);
      newRxDesc.nDesc <= newRxDesc.nDesc-1;
      totalRx <= totalRx+1;
   endrule
   rule dmaWriteStart;
      let rxDesc <- toGet(rxDescQueue).get;
      let pktLen <- rxPktBuff.readServer.readLen.get;
      // write packet metadata
      we.writeServers[0].request.put(MemengineCmd{tag:0, sglId:rxDesc.sglId,
                                                base:extend(rxDesc.offset - fromInteger(valueOf(RxMetadataLen))),
                                                len:extend(pktLen + fromInteger(valueOf(RxMetadataLen))),
                                                burstLen:truncate(pktLen + fromInteger(valueOf(RxMetadataLen)))});
      $display("SonicTop::dmaWriteStart offset=%x pktlen=%d", rxDesc.offset - fromInteger(valueof(RxMetadataLen)), pktLen);
      currRxMetadata.enq(RxMeta{filled: 1, len: extend(pktLen), reserved: 0});
   endrule
   rule dmaWriteMeta;
      let meta <- toGet(currRxMetadata).get;
      $display("SonicTop::dmaWriteMeta %d: filled=%x, len=%x", cycle, meta.filled, meta.len);
      we.writeServers[0].data.enq(pack(meta));
      rxPktBuff.readServer.readReq.put(EtherReq{len: truncate(meta.len)});
      recvInProgress.enq(truncate(meta.len));
   endrule
   rule dmaWriteInProgress if (recvInProgress.notEmpty);
      let v <- rxPktBuff.readServer.readData.get;
      $display("SonicTop::dmaWriteInProgress %d: data=%x sop=%x eop=%x", cycle, v.data, v.sop, v.eop);
      we.writeServers[0].data.enq(extend(v.data));
      if (v.eop) begin
         recvInProgress.deq;
      end
   endrule
   rule dmaWriteFinish;
      let rv <- we.writeServers[0].done.get;
      $display("SonicTop::dmaWriteFinish");
   endrule
   // rule to clock crossing from 156.25MHz to 250MHz with 64bit
   function EtherData combine(Vector#(2, PacketData#(64)) in);
      return EtherData {sop: in[0].sop, eop: in[1].eop, data: {in[1].data, in[0].data}};
   endfunction

   rule rxWriteData;
      // rule to pack 2x64 read from MAC interface to 128bit
      let data = fifoRxData.first; fifoRxData.deq;
      let temp = combine(data);
      $display("Recv %d: data=%x sop=%x eop=%x", cycle, temp.data, temp.sop, temp.eop);
      rxPktBuff.writeServer.writeData.put(temp);
   endrule

//   rule rxMacClockCrossing;
//      fifoRxData.enq(data);
//   endrule

   // Network MAC and PHY

   // Loopback
   mkConnection(toPipeOut(fifoTxData), toPipeIn(fifoRxData));

   Reg#(Bit#(32)) tx_cnt <- mkReg(0);
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
         //$display("NewRxDesc: rp=%x offset=%x len=%x burstLen=%x", rp, off, nb, bl);
         newRxDesc <= RxDesc{sglId:rp, offset:extend(off), len:nb, burstLen:truncate(bl), nDesc:1};
      endmethod
      method Action writePacketData(Bit#(64) upper, Bit#(64) lower, Bit#(1) sop, Bit#(1) eop);
         let d = EtherData{data: {upper, lower}, sop: unpack(sop), eop: unpack(eop)};
         rxPktBuff.writeServer.writeData.put(d);
      endmethod
      method Action writeMacData(Bit#(64) data, Bit#(1) sop, Bit#(1) eop);
         PacketData#(64) v = defaultValue;
         v.data = data;
         v.sop = unpack(sop);
         v.eop = unpack(eop);
         fifoRxData.enq(vec(v));
      endmethod
      method Action resetWrite(Bit#(32) qid);
         rxDescQueue.clear();
         currRxMetadata.clear();
         recvInProgress.clear();
         finishFifo.clear();
      endmethod
   endinterface
   interface `PinType pins;
      // Clocks
`ifndef SIMULATION
      interface deleteme_unused_clock = defaultClock;
      interface deleteme_unused_reset = defaultReset;
`endif
      // Resets
      // SFP+
   endinterface
endmodule
