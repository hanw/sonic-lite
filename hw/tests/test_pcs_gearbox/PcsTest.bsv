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
import Gearbox_66_40 ::*;
import Gearbox_40_66 ::*;
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
//   FIFOF#(Bit#(66)) scrambled_data <- mkFIFOF;
   FIFOF#(Bit#(72)) write_data2 <- mkFIFOF;
//   FIFOF#(Bit#(66)) scrambled_data2 <- mkFIFOF;

   PipeOut#(Bit#(72)) pipe_out1 = toPipeOut(write_data1);
   PipeOut#(Bit#(72)) pipe_out2 = toPipeOut(write_data2);

   Vector#(Delay, FIFOF#(Bit#(66))) fifo_sc1_to_sc2 <- replicateM(mkFIFOF);
   Vector#(Delay, FIFOF#(Bit#(66))) fifo_sc2_to_sc1 <- replicateM(mkFIFOF);

   PipeOut#(Bit#(66)) pipe_fifo_sc1_to_sc2 = toPipeOut(fifo_sc1_to_sc2[delay-1]);
   PipeOut#(Bit#(66)) pipe_fifo_sc2_to_sc1 = toPipeOut(fifo_sc2_to_sc1[delay-1]);

   MemreadEngineV#(256, 2, 1) re <- mkMemreadEngine;

   EthPcs sc1 <- mkEthPcs(0);
   EthPcs sc2 <- mkEthPcs(1);
   Gearbox_66_40 gearbox_66_40_1 <- mkGearbox66to40;
   Gearbox_40_66 gearbox_40_66_1 <- mkGearbox40to66;
   Gearbox_66_40 gearbox_66_40_2 <- mkGearbox66to40;
   Gearbox_40_66 gearbox_40_66_2 <- mkGearbox40to66;

   // PCS1 -> Gearbox66/40 -> Gearbox40/66 -> PCS2
   mkConnection(pipe_out1, sc1.encoderIn);
   mkConnection(pipe_fifo_sc1_to_sc2, gearbox_66_40_1.gbIn);
   mkConnection(gearbox_66_40_1.gbOut, gearbox_40_66_2.gbIn);
   mkConnection(gearbox_40_66_2.gbOut, sc2.bsyncIn);

   // PCS2 -> Gearbox66/40 -> Gearbox40/66 -> PCS1
   mkConnection(pipe_out2, sc2.encoderIn);
   mkConnection(pipe_fifo_sc2_to_sc1, gearbox_66_40_2.gbIn);
   mkConnection(gearbox_66_40_2.gbOut, gearbox_40_66_1.gbIn);
   mkConnection(gearbox_40_66_1.gbOut, sc1.bsyncIn);

   rule init;
      let sc1_out = sc1.scramblerOut.first;
      sc1.scramblerOut.deq;
      let sc2_out = sc2.scramblerOut.first;
      sc2.scramblerOut.deq;
      fifo_sc1_to_sc2[0].enq(sc1_out);
      fifo_sc2_to_sc1[0].enq(sc2_out);
//      if(verbose) $display("%d: sc0 -> sc1 : %h", cycle, sc1_out);
//      if(verbose) $display("%d: sc1 -> sc0 : %h", cycle, sc2_out);
   endrule

   Vector#(Delay, Reg#(Bit#(66))) sc1_wires <- replicateM(mkReg(0));
   Vector#(Delay, Reg#(Bit#(66))) sc2_wires <- replicateM(mkReg(0));
   for (Integer i=0; i<delay-1; i=i+1) begin
      rule connect;
            sc1_wires[i] <= fifo_sc1_to_sc2[i].first;
            sc2_wires[i] <= fifo_sc2_to_sc1[i].first;
            fifo_sc1_to_sc2[i].deq;
            fifo_sc2_to_sc1[i].deq;
            fifo_sc1_to_sc2[i+1].enq(sc1_wires[i]);
            fifo_sc2_to_sc1[i+1].enq(sc2_wires[i]);
      endrule
   end

   rule cyc;
      cycle <= cycle + 1;
   endrule

   rule start(toStart > 0);
      re.readServers[0].request.put(MemengineCmd{sglId:pointer, base:0, len:truncate(chunk), burstLen:truncate(burstLen*4)});
      toStart <= toStart - 1;
   endrule

   rule data;
      Bit#(72) xgmii;
//      Bit#(66) scrambled;
      let v <- toGet(re.dataPipes[0]).get;
      xgmii = {v[227:192], v[163:128]};
      write_data1.enq(xgmii);
      write_data2.enq(xgmii);
//      scrambled = {v[65:0]};
//      scrambled_data.enq(scrambled);
      if(verbose) $display("%d: xgmiiIn v=%h", cycle, xgmii);
   endrule

   rule rxout;
      let v1 = sc1.decoderOut.first();
      sc1.decoderOut.deq;
      let v2 = sc2.decoderOut.first();
      sc2.decoderOut.deq;
      if(verbose) $display("%d: decoderOut v=%h", cycle, v1);
      if(verbose) $display("%d: decoderOut v=%h", cycle, v2);
   endrule

//   rule txout;
//      let v = sc.scramblerOut.first();
//      sc.scramblerOut.deq;
//      if(verbose) $display("%d: scramblerOut v=%h", cycle, v);
//   endrule

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

