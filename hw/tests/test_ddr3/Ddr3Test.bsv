// Copyright (c) 2013 Quanta Research Cambridge, Inc.

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
import Clocks::*;
import Vector::*;
import BuildVector::*;
import GetPut::*;
import Connectable::*;
import ClientServer::*;
import ConnectalMemory::*;
import ConnectalBramFifo::*;
import FIFO::*;
import FIFOF::*;
import Gearbox::*;
import GearboxGetPut::*;
import MemTypes::*;
import Pipe::*;
import Ddr3Controller::*;
import GetPutWithClocks::*;
import AxiMasterSlave::*;
import Axi4MasterSlave::*;
import AxiDdr3Wrapper  ::*;
import AxiDma::*;
import AxiBits::*;
import ConnectalConfig::*;
import HostInterface::*;
import Probe::*;
import Ddr3Controller::*;
import SharedBuffMemServer::*;
import SharedBuffMMU::*;
import MemServerIndication::*;
import GetPutWithClocks::*;

interface Ddr3TestRequest;
   method Action startWriteDram(Bit#(32) sglId, Bit#(32) transferBytes);
   method Action startReadDram(Bit#(32) sglId, Bit#(32) transferBytes);
endinterface

interface Ddr3TestIndication;
   method Action writeDone(Bit#(32) v);
   method Action readDone(Bit#(32) v);
endinterface

interface Ddr3Test;
   interface Ddr3TestRequest request;
   interface Ddr3Pins ddr3;
endinterface

typedef TDiv#(Ddr3DataWidth,DataBusWidth) BusRatio;
typedef TDiv#(Ddr3DataWidth,8) Ddr3DataBytes;

module mkDdr3Test#(HostInterface host, Ddr3TestIndication indication, MemServerIndication memind, MMUIndication mmuInd)(Ddr3Test);

   let clock <- exposeCurrentClock();
   let reset <- exposeCurrentReset();

   Reg#(Bit#(Ddr3AddrWidth)) transferLen <- mkReg(256);

   Clock clk200 = host.tsys_clk_200mhz_buf;

   let ddr3Controller <- mkDdr3(clk200);

   FIFO#(MemRequest) writeReqFifo <- mkFIFO();
   FIFO#(MemData#(Ddr3DataWidth)) writeDataFifo <- mkFIFO();
   FIFO#(Bit#(MemTagSize)) writeDoneFifo <- mkFIFO();
   MemWriteClient#(Ddr3DataWidth) writeClient = (interface MemWriteClient;
      interface Get writeReq = toGet(writeReqFifo);
      interface Get writeData = toGet(writeDataFifo);
      interface Put writeDone = toPut(writeDoneFifo);
      endinterface);

   FIFO#(MemRequest) readReqFifo <- mkFIFO();
   FIFO#(MemData#(Ddr3DataWidth)) readDataFifo <- mkFIFO();
   MemReadClient#(Ddr3DataWidth) readClient = (interface MemReadClient;
      interface Get readReq = toGet(readReqFifo);
      interface Put readData = toPut(readDataFifo);
      endinterface);

   MMU#(Ddr3AddrWidth) mmu <- mkSimpleMMU(0, False, mmuInd);
   MemServer#(Ddr3AddrWidth, Ddr3DataWidth, 1) dma <- mkMemServer(vec(readClient), vec(writeClient), vec(mmu), memind);
   Vector#(1, PhysMemSlave#(Ddr3AddrWidth, Ddr3DataWidth)) memSlaves <- replicateM(mkPhysMemSlave(ddr3Controller.axiBits, clocked_by ddr3Controller.uiClock, reset_by ddr3Controller.uiReset));
   for (Integer i=0; i<1; i=i+1) begin
      mkConnectionWithClocks(dma.masters[i], memSlaves[i], clock, reset, ddr3Controller.uiClock, ddr3Controller.uiReset);
   end

   Gearbox#(1,BusRatio,Bit#(DataBusWidth)) dramWriteGearbox <- mk1toNGearbox(clock, reset, clock, reset);
   FIFOF#(Vector#(BusRatio,Bit#(DataBusWidth))) dramWriteFifo <- mkDualClockBramFIFOF(clock, reset, ddr3Controller.uiClock, ddr3Controller.uiReset);

//   rule rl_wdata;
//      let mds <- toGet(dramWriteGearbox).get();
//      dramWriteFifo.enq(mds);
//   endrule
//   rule rl_writeDataFifo;
//      let mds <- toGet(dramWriteFifo).get();
//      // ddr3?
//   endrule

   Gearbox#(BusRatio,1,Bit#(DataBusWidth)) dramReadGearbox <- mkNto1Gearbox(ddr3Controller.uiClock, ddr3Controller.uiReset, ddr3Controller.uiClock, ddr3Controller.uiReset);
   FIFOF#(Bit#(DataBusWidth)) dramReadFifo <- mkDualClockBramFIFOF(ddr3Controller.uiClock, ddr3Controller.uiReset, clock, reset);

//   rule rl_rdata_gb;
//      Bit#(DataBusWidth) rdata <- toGet(dramReadGearbox).get();
//      dramReadFifo.enq(rdata);
//   endrule
//   rule rl_rdata_slack;
//      let rdata <- toGet(dramReadFifo).get();
//      // to readClient?
//   endrule

   interface Ddr3TestRequest request;
      method Action startWriteDram(Bit#(32) sglId, Bit#(32) transferBytes);
        transferLen <= truncate(transferBytes);
      endmethod
      method Action startReadDram(Bit#(32) sglId, Bit#(32) transferBytes);
        transferLen <= truncate(transferBytes);
      endmethod
   endinterface
   interface AxiDdr3 ddr3 = ddr3Controller.ddr3;
endmodule
