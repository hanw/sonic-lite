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

import Arith::*;
import BRAM::*;
import BRAMCore::*;
import Connectable::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import OInt::*;
import StmtFSM::*;
import Vector::*;
import Pipe::*;
import AsymmetricBRAM::*;

interface Vacram#(numeric type camDepth);
   interface Put#(Bit#(TLog#(camDepth))) wAddr;
   interface PipeIn#(Bool) oldPattV;
   interface PipeIn#(Bool) oldPattMultiOcc;
   interface PipeIn#(Bool) newPattMultiOcc;
   interface PipeIn#(Bit#(5)) oldIdx;
   interface PipeOut#(Bit#(5)) vacFLoc;
endinterface
module mkVacram(Vacram#(camDepth))
   provisos(Add#(cdep, 9, camSz)
            ,Log#(camDepth, camSz)
            ,Add#(TLog#(cdep), 5, wAddrHWidth)
            ,Add#(writeSz, 0, 32)
            ,Add#(readSz, 0, 32)
            ,Div#(camDepth, 32, writeDepth)
            ,Div#(readSz, writeSz, ratio)
            ,Log#(ratio, ratioSz)
            ,Log#(writeDepth, writeDepthSz)
            ,Add#(readDepthSz, ratioSz, writeDepthSz)
            ,Add#(wAddrHWidth, a__, camSz)
         );
   let verbose = True;
   Reg#(Bit#(32)) cycle <- mkReg(0);
   rule every1;
      cycle <= cycle + 1;
   endrule

   FIFO#(Bit#(camSz)) writeReqFifo <- mkFIFO;
   FIFOF#(Bool) oldPattV_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) oldPattMultiOcc_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) newPattMultiOcc_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(5)) oldIdx_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(5)) vacFLoc_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(5)) t_vacFLoc_fifo <- mkBypassFIFOF();

   FIFOF#(Bit#(32)) wVac_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(32)) cVac_fifo <- mkBypassFIFOF();

   // WWID=32, RWID=32, WDEP=CDEP*1024/32, OREG=0, INIT=1
`define VACRAM AsymmetricBRAM#(Bit#(readDepthSz), Bit#(readSz), Bit#(writeDepthSz), Bit#(writeSz))
   `VACRAM vacRam <- mkAsymmetricBRAM(False, False);

   rule ram_input;
      let v <- toGet(writeReqFifo).get;
      Vector#(wAddrHWidth, Bit#(1)) wAddrH = takeAt(5, unpack(v));
//      ram.wAddr.enq(pack(wAddrH));
//      ram.rAddr.enq(pack(wAddrH));
   endrule

//   PrioEnc#(32) pe_vac <- mkPE32();
//   mkConnection(toPipeOut(cVac_fifo), pe_vac.oht);

//   rule pe_vac_out;
//      let v <- toGet(pe_vac.pe).get;
//      vacFLoc_fifo.enq(v.bin);
//      t_vacFLoc_fifo.enq(v.bin);
//   endrule

//   rule mask_logic_cvac;
//      let rVac <- toGet(ram.rData).get;
//      let oldPattMultiOcc <- toGet(oldPattMultiOcc_fifo).get;
//      let oldPattV <- toGet(oldPattV_fifo).get;
//      let oldIdx <- toGet(oldIdx_fifo).get;
//      let newPattMultiOcc <- toGet(newPattMultiOcc_fifo).get;
//      let vacFLoc <- toGet(t_vacFLoc_fifo).get;
//
//      OInt#(32) oldIdxOH = toOInt(oldIdx);
//      Bool oldVac = !oldPattMultiOcc && oldPattV;
//      Vector#(32, Bit#(1)) maskOldVac = replicate(pack(oldVac));
//      Bit#(32) cVac = (~rVac) | (pack(oldIdxOH) & pack(maskOldVac));
//
//      OInt#(32) vacFLocOH = toOInt(vacFLoc);
//      Vector#(32, Bit#(1)) maskNewVac = replicate(pack(newPattMultiOcc));
//      Bit#(32) wVac = ~(cVac & ((~pack(vacFLocOH)) | pack(maskNewVac)));
//
//      cVac_fifo.enq(cVac);
//      wVac_fifo.enq(wVac);
//   endrule

   interface Put wAddr = toPut(writeReqFifo);
   interface PipeIn oldPattV = toPipeIn(oldPattV_fifo);
   interface PipeIn oldPattMultiOcc = toPipeIn(oldPattMultiOcc_fifo);
   interface PipeIn newPattMultiOcc = toPipeIn(newPattMultiOcc_fifo);
   interface PipeIn oldIdx = toPipeIn(oldIdx_fifo);
   interface PipeOut vacFLoc = toPipeOut(vacFLoc_fifo);
endmodule
