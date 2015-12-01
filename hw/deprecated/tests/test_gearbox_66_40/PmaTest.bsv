import FIFO::*;
import FIFOF::*;
import Clocks::*;
import SpecialFIFOs::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;
import Connectable::*;

import Pipe::*;
import MemTypes::*;
import MemreadEngine::*;

import Gearbox_66_40::*;

interface PmaTestRequest;
   method Action startPma(Bit#(32) pointer, Bit#(32) numWords, Bit#(32) burstLen, Bit#(32) iterCount);
endinterface

interface PmaTest;
   interface PmaTestRequest request;
   interface MemReadClient#(64) dmaClient;
endinterface

interface PmaTestIndication;
   method Action pmaTestDone(Bit#(32) matchCount);
endinterface

module mkPmaTest#(PmaTestIndication indication, Clock slow_clk) (PmaTest);

   let verbose = True;
   Clock defaultClock <- exposeCurrentClock;
   Reset defaultReset <- exposeCurrentReset;
   Reset slow_rst     <- mkAsyncReset(2, defaultReset, slow_clk);

   Reg#(SGLId)    pointer  <- mkReg(0);
   Reg#(Bit#(32)) numWords <- mkReg(0);
   Reg#(Bit#(32)) burstLen <- mkReg(0);
   Reg#(Bit#(32)) toStart  <- mkReg(0);
   Reg#(Bit#(32)) toFinish <- mkReg(0);
   FIFO#(void)          cf <- mkSizedFIFO(1);
   Bit#(MemOffsetSize) chunk = extend(numWords)*4;
   FIFOF#(Bit#(66)) write_data <- mkBypassFIFOF(clocked_by slow_clk, reset_by slow_rst);
   PipeOut#(Bit#(66)) pipe_out = toPipeOut(write_data);

   SyncFIFOIfc#(Bit#(64)) syncFIFO <- mkSyncFIFO(1, defaultClock, defaultReset, slow_clk);

   MemreadEngineV#(64, 2, 1) re <- mkMemreadEngine;
   Gearbox_66_40 gb <- mkGearbox66to40(slow_clk);

   mkConnection(pipe_out, gb.gbIn);

   rule start(toStart > 0);
      re.readServers[0].request.put(MemengineCmd{sglId:pointer, base:0, len:truncate(chunk), burstLen:truncate(burstLen*4)});
      toStart <= toStart - 1;
   endrule

   rule toGet;
      let v <- toGet(re.dataPipes[0]).get;
      syncFIFO.enq(v);
   endrule

   rule toPut;
      let v <- toGet(syncFIFO).get;
      write_data.enq(zeroExtend(v));
   endrule

//   rule data;
//      let v <- toGet(re.dataPipes[0]).get;
//      write_data.enq(zeroExtend(v));
//      if(verbose) $display("mkPmaTest.write_data v=%h", v);
//   endrule

   rule out;
      let v = gb.gbOut.first();
      gb.gbOut.deq;
      if(verbose) $display("Tx Pma Out v=%h", v);
   endrule

   rule finish(toFinish > 0);
      let rv <- re.readServers[0].response.get;
      if (toFinish == 1) begin
         cf.deq;
         indication.pmaTestDone(0);
      end
      toFinish <= toFinish - 1;
   endrule

   interface dmaClient = re.dmaClient;
   interface PmaTestRequest request;
      method Action startPma(Bit#(32) rp, Bit#(32) nw, Bit#(32)bl, Bit#(32) ic) if(toStart == 0 && toFinish == 0);
         cf.enq(?);
         pointer  <= rp;
         numWords <= nw;
         burstLen <= bl;
         toStart  <= ic;
         toFinish <= ic;
      endmethod
   endinterface
endmodule

