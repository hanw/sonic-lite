import FIFO::*;
import FIFOF::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;
import Connectable::*;

import Pipe::*;
import MemTypes::*;
import MemreadEngine::*;

import Ethernet::*;
import Encoder ::*;
import Decoder ::*;
import Scrambler ::*;
import Descrambler ::*;
import Dtp::*;
import EthPcs::*;

interface PcsTestRequest;
   method Action startPcs(Bit#(32) pointer, Bit#(32) numWords, Bit#(32) burstLen, Bit#(32) iterCount);
endinterface

interface PcsTest;
   interface PcsTestRequest request;
   interface MemReadClient#(256) dmaClient;
endinterface

interface PcsTestIndication;
   method Action pcsTestDone(Bit#(32) matchCount);
endinterface

typedef 5 Delay; //one-way delay
Integer delay = valueOf(Delay);

module mkPcsTest#(PcsTestIndication indication) (PcsTest);

   let verbose = True;

   Reg#(Bit#(32)) cycle    <- mkReg(0);
   Reg#(SGLId)    pointer  <- mkReg(0);
   Reg#(Bit#(32)) numWords <- mkReg(0);
   Reg#(Bit#(32)) burstLen <- mkReg(0);
   Reg#(Bit#(32)) toStart  <- mkReg(0);
   Reg#(Bit#(32)) toFinish <- mkReg(0);
   FIFO#(void)          cf <- mkSizedFIFO(1);
   Bit#(MemOffsetSize) chunk = extend(numWords)*4;
   FIFOF#(Bit#(72)) write_data1 <- mkFIFOF;
   FIFOF#(Bit#(66)) scrambled_data <- mkFIFOF;

   MemreadEngineV#(256, 2, 1) re <- mkMemreadEngine;
   EthPcs sc1 <- mkEthPcs(toPipeOut(write_data1), toPipeOut(scrambled_data), 0, 100);

   rule init;
      let sc1_out = sc1.scramblerOut.first;
      sc1.scramblerOut.deq;
      if(verbose) $display("%d: sc1->sc2 %h", cycle, sc1_out);
      scrambled_data.enq(sc1_out);
   endrule

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
      xgmii = {v[227:192], v[163:128]};
      write_data1.enq(xgmii);
      if(verbose) $display("%d: xgmiiIn v=%h", cycle, xgmii);
   endrule

   rule rxout;
      let v1 = sc1.decoderOut.first();
      sc1.decoderOut.deq;
      if(verbose) $display("%d: decoderOut v=%h", cycle, v1);
   endrule

   rule finish(toFinish > 0);
      let rv <- re.readServers[0].response.get;
      if (toFinish == 1) begin
         cf.deq;
         indication.pcsTestDone(0);
      end
      toFinish <= toFinish - 1;
   endrule

   interface dmaClient = re.dmaClient;
   interface PcsTestRequest request;
      method Action startPcs(Bit#(32) rp, Bit#(32) nw, Bit#(32)bl, Bit#(32) ic) if(toStart == 0 && toFinish == 0);
         cf.enq(?);
         pointer  <= rp;
         numWords <= nw;
         burstLen <= bl;
         toStart  <= ic;
         toFinish <= ic;
      endmethod
   endinterface
endmodule

