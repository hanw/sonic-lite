import FIFO::*;
import FIFOF::*;
import Vector::*;
import BuildVector::*;
import GetPut::*;
import ClientServer::*;
import Connectable::*;

import Pipe::*;
import MemTypes::*;
import MemreadEngine::*;
import HostInterface::*;

import Dtpm::*;
import DtpSwitch::*;

interface DtpTestRequest;
   method Action startDtp(Bit#(32) pointer, Bit#(32) numWords, Bit#(32) burstLen, Bit#(32) iterCount);
endinterface

interface DtpTest;
   interface DtpTestRequest request;
   interface Vector#(1, MemReadClient#(DataBusWidth)) dmaClient;
endinterface

interface DtpTestIndication;
   method Action dtpTestDone(Bit#(32) matchCount);
endinterface

typedef 6 Delay; //one-way delay
Integer delay = valueOf(Delay);

module mkDtpTest#(DtpTestIndication indication) (DtpTest);

   let verbose = False;

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
   FIFOF#(Bit#(66)) write_encoder_data3 <- mkFIFOF;
   FIFOF#(Bit#(66)) write_encoder_data4 <- mkFIFOF;

   PipeOut#(Bit#(66)) pipe_encoder_out1 = toPipeOut(write_encoder_data1);
   PipeOut#(Bit#(66)) pipe_encoder_out2 = toPipeOut(write_encoder_data2);
   PipeOut#(Bit#(66)) pipe_encoder_out3 = toPipeOut(write_encoder_data3);
   PipeOut#(Bit#(66)) pipe_encoder_out4 = toPipeOut(write_encoder_data4);

   MemreadEngine#(128, 2, 1) re <- mkMemreadEngine;

   Vector#(Delay, FIFOF#(Bit#(66))) fifo_sc1_to_sc2 <- replicateM(mkFIFOF);
   Vector#(Delay, FIFOF#(Bit#(66))) fifo_sc2_to_sc1 <- replicateM(mkFIFOF);
   Vector#(Delay, FIFOF#(Bit#(66))) fifo_sc3_to_sc4 <- replicateM(mkFIFOF);
   Vector#(Delay, FIFOF#(Bit#(66))) fifo_sc4_to_sc3 <- replicateM(mkFIFOF);

   PipeOut#(Bit#(66)) pipe_decoder_out1 = toPipeOut(fifo_sc1_to_sc2[delay-1]);
   PipeOut#(Bit#(66)) pipe_decoder_out2 = toPipeOut(fifo_sc2_to_sc1[delay-1]);
   PipeOut#(Bit#(66)) pipe_decoder_out3 = toPipeOut(fifo_sc3_to_sc4[delay-1]);
   PipeOut#(Bit#(66)) pipe_decoder_out4 = toPipeOut(fifo_sc4_to_sc3[delay-1]);

   DtpSwitch#(4) switch <- mkDtpSwitch();
   Dtpm sc1 <- mkDtpm(1, 100);
   Dtpm sc2 <- mkDtpm(2, 200);

   mkConnection(pipe_encoder_out1, sc1.dtpTxIn);
   mkConnection(pipe_encoder_out2, sc2.dtpTxIn);
   mkConnection(pipe_decoder_out1, sc2.dtpRxIn);
   mkConnection(pipe_decoder_out2, sc1.dtpRxIn);

   mkConnection(sc1.dtpLocalOut, switch.dtpLocalIn[0]);
   mkConnection(sc2.dtpLocalOut, switch.dtpLocalIn[1]);
   mkConnection(switch.dtpGlobalOut[0], sc1.dtpGlobalIn);
   mkConnection(switch.dtpGlobalOut[1], sc2.dtpGlobalIn);

   // 3rd and 4th ports
   Dtpm sc3 <- mkDtpm(3, 300);
   Dtpm sc4 <- mkDtpm(4, 400);

   mkConnection(pipe_encoder_out3, sc3.dtpTxIn);
   mkConnection(pipe_encoder_out4, sc4.dtpTxIn);
   mkConnection(pipe_decoder_out3, sc3.dtpRxIn);
   mkConnection(pipe_decoder_out4, sc4.dtpRxIn);
   mkConnection(sc3.dtpLocalOut, switch.dtpLocalIn[2]);
   mkConnection(sc4.dtpLocalOut, switch.dtpLocalIn[3]);
   mkConnection(switch.dtpGlobalOut[2], sc3.dtpGlobalIn);
   mkConnection(switch.dtpGlobalOut[3], sc4.dtpGlobalIn);

   rule tx1;
      let sc1_out <- toGet(sc1.dtpTxOut).get;
      fifo_sc1_to_sc2[0].enq(sc1_out);
      if(verbose) $display("%d: sc1 -> sc2 : %h", cycle, sc1_out);
   endrule

   rule tx2;
      let sc2_out <- toGet(sc2.dtpTxOut).get;
      fifo_sc2_to_sc1[0].enq(sc2_out);
      if(verbose) $display("%d: sc2 -> sc1 : %h", cycle, sc2_out);
   endrule

   rule tx3;
      let sc3_out <- toGet(sc3.dtpTxOut).get;
      fifo_sc3_to_sc4[0].enq(sc3_out);
      if(verbose) $display("%d: sc3 -> sc4 : %h", cycle, sc3_out);
   endrule

   rule tx4;
      let sc4_out <- toGet(sc4.dtpTxOut).get;
      fifo_sc4_to_sc3[0].enq(sc4_out);
      if(verbose) $display("%d: sc4 -> sc3 : %h", cycle, sc4_out);
   endrule

   rule every1;
      sc1.rx_ready(True);
      sc1.tx_ready(True);
      sc1.switch_mode(True);
      sc2.rx_ready(True);
      sc2.tx_ready(True);
      sc2.switch_mode(True);
      sc3.rx_ready(True);
      sc3.tx_ready(True);
      sc3.switch_mode(True);
      sc4.rx_ready(True);
      sc4.tx_ready(True);
      sc4.switch_mode(True);
      switch.switch_mode(True);
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

   Vector#(Delay, Reg#(Bit#(66))) sc3_wires <- replicateM(mkReg(0));
   Vector#(Delay, Reg#(Bit#(66))) sc4_wires <- replicateM(mkReg(0));
   for (Integer i=0; i<delay-1; i=i+1) begin
      rule connect;
            sc3_wires[i] <= fifo_sc3_to_sc4[i].first;
            sc4_wires[i] <= fifo_sc4_to_sc3[i].first;
            fifo_sc3_to_sc4[i].deq;
            fifo_sc4_to_sc3[i].deq;
            fifo_sc3_to_sc4[i+1].enq(sc3_wires[i]);
            fifo_sc4_to_sc3[i+1].enq(sc4_wires[i]);
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
      //let v <- toGet(re.dataPipes[0]).get;
      let v = 64'h79;
      write_encoder_data1.enq({2'b00, v[63:0]});
      write_encoder_data2.enq({2'b00, v[63:0]});
      write_encoder_data3.enq({2'b00, v[63:0]});
      write_encoder_data4.enq({2'b00, v[63:0]});
      if(verbose) $display("%d: mkDtpTest.write_data v=%h", cycle, v[63:0]);
   endrule

   rule out;
      let v <- toGet(sc1.dtpRxOut).get;
      if(verbose) $display("%d: sc1 out v=%h", cycle, v);
   endrule

   rule out2;
      let v <- toGet(sc2.dtpRxOut).get;
      if(verbose) $display("%d: sc2 out v=%h", cycle, v);
   endrule

   rule out3;
      let v <- toGet(sc3.dtpRxOut).get;
      if(verbose) $display("%d: sc3 out v=%h", cycle, v);
   endrule

   rule out4;
      let v <- toGet(sc4.dtpRxOut).get;
      if(verbose) $display("%d: sc4 out v=%h", cycle, v);
   endrule

   rule finish(toFinish > 0);
      let rv <- re.readServers[0].response.get;
      if (toFinish == 1) begin
         cf.deq;
         indication.dtpTestDone(0);
      end
      toFinish <= toFinish - 1;
   endrule

   interface dmaClient = vec(re.dmaClient);
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

