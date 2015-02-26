import FIFO::*;
import FIFOF::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;
import Connectable::*;

import Pipe::*;
import MemTypes::*;
import MemreadEngine::*;

import MacTx::*;

interface MacTxTestRequest;
   method Action startMacTx(Bit#(32) pointer, Bit#(32) numWords, Bit#(32) burstLen, Bit#(32) iterCount);
endinterface

interface MacTxTest;
   interface MacTxTestRequest request;
   interface MemReadClient#(128) dmaClient;
endinterface

interface MacTxTestIndication;
   method Action macTxTestDone(Bit#(32) matchCount);
endinterface

module mkMacTxTest#(MacTxTestIndication indication) (MacTxTest);

   let verbose = True;

   Reg#(SGLId)    pointer  <- mkReg(0);
   Reg#(Bit#(32)) numWords <- mkReg(0);
   Reg#(Bit#(32)) burstLen <- mkReg(0);
   Reg#(Bit#(32)) toStart  <- mkReg(0);
   Reg#(Bit#(32)) toFinish <- mkReg(0);
   Reg#(Bit#(32)) cycle <- mkReg(0);
   FIFO#(void)          cf <- mkSizedFIFO(1);
   Bit#(MemOffsetSize) chunk = extend(numWords)*4;
   FIFOF#(Bit#(72)) write_data <- mkFIFOF;

   MemreadEngineV#(128, 2, 1) re <- mkMemreadEngine;
   MacTx sc <- mkMacTx(toPipeOut(write_data));

   rule cyc;
      cycle <= cycle + 1;
   endrule

   rule start(toStart > 0);
      re.readServers[0].request.put(MemengineCmd{sglId:pointer, base:0, len:truncate(chunk), burstLen:truncate(burstLen*4)});
      toStart <= toStart - 1;
   endrule

   rule data;
      Bit#(72) xgmii;
      let v <- toGet(re.dataPipes[0]).get;
      xgmii = {v[99:64], v[35:0]};
      write_data.enq(xgmii);
      if(verbose) $display("%d: macIn v=%h", cycle, xgmii);
   endrule

//   rule out;
//      Vector#(8, Bit#(8)) txd;
//      Vector#(8, Bit#(1)) txc;
//      Bit#(64) xgmii_txd;
//      Bit#(8)  xgmii_txc;
//
//      let v = sc.macTxOut.first();
//      sc.macTxOut.deq;
//      if(verbose) $display("%d: macTx out v=%h", cycle, v);
//
//      for (Integer i=0; i<8; i=i+1) begin
//         txd[i] = v[9*i+7 : 9*i];
//         txc[i] = v[9*i+8];
//      end
//      xgmii_txd = pack(txd);
//      xgmii_txc = pack(txc);
//
//      if(verbose) $display("%d: xgmii_txd=%h, txc=%h", cycle, xgmii_txd, xgmii_txc);
//   endrule

   rule finish(toFinish > 0);
      let rv <- re.readServers[0].response.get;
      if (toFinish == 1) begin
         cf.deq;
         indication.macTxTestDone(0);
      end
      toFinish <= toFinish - 1;
   endrule

   interface dmaClient = re.dmaClient;
   interface MacTxTestRequest request;
      method Action startMacTx(Bit#(32) rp, Bit#(32) nw, Bit#(32)bl, Bit#(32) ic) if(toStart == 0 && toFinish == 0);
         cf.enq(?);
         pointer  <= rp;
         numWords <= nw;
         burstLen <= bl;
         toStart  <= ic;
         toFinish <= ic;
      endmethod
   endinterface
endmodule

