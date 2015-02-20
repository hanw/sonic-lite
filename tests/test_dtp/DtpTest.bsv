import FIFO::*;
import FIFOF::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;
import Connectable::*;

import Pipe::*;
import MemTypes::*;
import MemreadEngine::*;

import Dtp::*;

interface DtpTestRequest;
   method Action startDtp(Bit#(32) pointer, Bit#(32) numWords, Bit#(32) burstLen, Bit#(32) iterCount);
endinterface

interface DtpTest;
   interface DtpTestRequest request;
   interface MemReadClient#(128) dmaClient;
endinterface

interface DtpTestIndication;
   method Action dtpTestDone(Bit#(32) matchCount);
endinterface

typedef 5 Delay; //one-way delay
Integer delay = valueOf(Delay);

module mkDtpTest#(DtpTestIndication indication) (DtpTest);

   let verbose = True;

   Reg#(SGLId)    pointer  <- mkReg(0);
   Reg#(Bit#(32)) numWords <- mkReg(0);
   Reg#(Bit#(32)) burstLen <- mkReg(0);
   Reg#(Bit#(32)) toStart  <- mkReg(0);
   Reg#(Bit#(32)) toFinish <- mkReg(0);
   Reg#(Bit#(32)) cycle <- mkReg(0);
   FIFO#(void)          cf <- mkSizedFIFO(1);
   Bit#(MemOffsetSize) chunk = extend(numWords)*4;
   FIFOF#(Bit#(66)) write_encoder_data1 <- mkFIFOF;
   FIFOF#(Bit#(66)) write_encoder_data2 <- mkFIFOF;

   MemreadEngineV#(128, 2, 1) re <- mkMemreadEngine;
//   FIFOF#(Bit#(66)) sc1_to_sc2 <- mkFIFOF;
//   FIFOF#(Bit#(66)) sc2_to_sc1 <- mkFIFOF;

   Vector#(Delay, FIFOF#(Bit#(66))) fifo_sc1_to_sc2 <- replicateM(mkFIFOF);
   Vector#(Delay, FIFOF#(Bit#(66))) fifo_sc2_to_sc1 <- replicateM(mkFIFOF);

//   DtpIfc sc1 <- mkDtp(toPipeOut(sc2_to_sc1), toPipeOut(write_encoder_data1), 1, 100);
//   DtpIfc sc2 <- mkDtp(toPipeOut(sc1_to_sc2), toPipeOut(write_encoder_data2), 2, 200);

   Dtp sc1 <- mkDtp(toPipeOut(fifo_sc2_to_sc1[delay-1]), toPipeOut(write_encoder_data1), 1, 100);
   Dtp sc2 <- mkDtp(toPipeOut(fifo_sc1_to_sc2[delay-1]), toPipeOut(write_encoder_data2), 2, 200);

   rule init;
      let sc1_out = sc1.encoderOut.first;
      sc1.encoderOut.deq;
      let sc2_out = sc2.encoderOut.first;
      sc2.encoderOut.deq;
      fifo_sc1_to_sc2[0].enq(sc1_out);
      fifo_sc2_to_sc1[0].enq(sc2_out);
      if(verbose) $display("%d: sc0 -> sc1 : %h", cycle, sc1_out);
      if(verbose) $display("%d: sc1 -> sc0 : %h", cycle, sc2_out);
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

//   rule inp;
//      let sc1_out = sc1.encoderOut.first;
//      sc1.encoderOut.deq;
//      let sc2_out = sc2.encoderOut.first;
//      sc2.encoderOut.deq;
//      sc1_to_sc2.enq(sc1_out);
//      sc2_to_sc1.enq(sc2_out);
//   endrule

   rule cyc;
      cycle <= cycle + 1;
   endrule

   rule start(toStart > 0);
      re.readServers[0].request.put(MemengineCmd{sglId:pointer, base:0, len:truncate(chunk), burstLen:truncate(burstLen*4)});
      toStart <= toStart - 1;
   endrule

   rule data;
      let v <- toGet(re.dataPipes[0]).get;
      write_encoder_data1.enq({2'b00, v[63:0]});
      write_encoder_data2.enq({2'b00, v[63:0]});
      if(verbose) $display("mkDtpTest.write_data v=%h", v[63:0]);
   endrule

   rule out;
      let v1 = sc1.decoderOut.first();
      sc1.decoderOut.deq;
      let v2 = sc2.decoderOut.first();
      sc2.decoderOut.deq;
      if(verbose) $display("%d: sc1 out v=%h", cycle, v1);
      if(verbose) $display("%d: sc2 out v=%h", cycle, v2);
   endrule

   rule finish(toFinish > 0);
      let rv <- re.readServers[0].response.get;
      if (toFinish == 1) begin
         cf.deq;
         indication.dtpTestDone(0);
      end
      toFinish <= toFinish - 1;
   endrule

   interface dmaClient = re.dmaClient;
   interface DtpTestRequest request;
      method Action startDtp(Bit#(32) rp, Bit#(32) nw, Bit#(32)bl, Bit#(32) ic) if(toStart == 0 && toFinish == 0);
         cf.enq(?);
         pointer  <= rp;
         numWords <= nw;
         burstLen <= bl;
         toStart  <= ic;
         toFinish <= ic;
      endmethod
   endinterface
endmodule

