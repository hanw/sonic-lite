import FIFO::*;
import FIFOF::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;
import Connectable::*;

import Pipe::*;
import MemTypes::*;
import MemreadEngine::*;

import Descrambler::*;

interface DescramblerTestRequest;
   method Action startDescrambler(Bit#(32) pointer, Bit#(32) numWords, Bit#(32) burstLen, Bit#(32) iterCount);
endinterface

interface DescramblerTest;
   interface DescramblerTestRequest request;
   interface MemReadClient#(128) dmaClient;
endinterface

interface DescramblerTestIndication;
   method Action descramblerTestDone(Bit#(32) matchCount);
endinterface

module mkDescramblerTest#(DescramblerTestIndication indication) (DescramblerTest);

   let verbose = True;

   Reg#(SGLId)    pointer  <- mkReg(0);
   Reg#(Bit#(32)) numWords <- mkReg(0);
   Reg#(Bit#(32)) burstLen <- mkReg(0);
   Reg#(Bit#(32)) toStart  <- mkReg(0);
   Reg#(Bit#(32)) toFinish <- mkReg(0);
   FIFO#(void)          cf <- mkSizedFIFO(1);
   Bit#(MemOffsetSize) chunk = extend(numWords)*4;
   FIFOF#(Bit#(66)) write_data <- mkFIFOF;

   MemreadEngineV#(128, 2, 1) re <- mkMemreadEngine;
   Descrambler sc <- mkDescrambler(toPipeOut(write_data));

   rule start(toStart > 0);
      re.readServers[0].request.put(MemengineCmd{sglId:pointer, base:0, len:truncate(chunk), burstLen:truncate(burstLen*4)});
      toStart <= toStart - 1;
   endrule

   rule data;
      let v <- toGet(re.dataPipes[0]).get;
      write_data.enq(v[65:0]);
      //if(verbose) $display("mkDescramblerTest.write_data v=%h", v[39:0]);
   endrule

   rule out;
      let v = sc.descrambledOut.first();
      sc.descrambledOut.deq;
      if(verbose) $display("descrambled out v=%h", v);
   endrule

   rule finish(toFinish > 0);
      let rv <- re.readServers[0].response.get;
      if (toFinish == 1) begin
         cf.deq;
         indication.descramblerTestDone(0);
      end
      toFinish <= toFinish - 1;
   endrule

   interface dmaClient = re.dmaClient;
   interface DescramblerTestRequest request;
      method Action startDescrambler(Bit#(32) rp, Bit#(32) nw, Bit#(32)bl, Bit#(32) ic) if(toStart == 0 && toFinish == 0);
         cf.enq(?);
         pointer  <= rp;
         numWords <= nw;
         burstLen <= bl;
         toStart  <= ic;
         toFinish <= ic;
      endmethod
   endinterface
endmodule

