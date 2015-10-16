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
import PriorityEncoder::*;

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
            ,Add#(writeDepthSz, 0, wAddrHWidth)
         );
   let verbose = True;
   Reg#(Bit#(32)) cycle <- mkReg(0);
   rule every1;
      cycle <= cycle + 1;
   endrule

   FIFOF#(Bit#(camSz)) writeReqFifo <- mkFIFOF;
   FIFOF#(Bool) oldPattV_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) oldPattMultiOcc_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) newPattMultiOcc_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(5)) oldIdx_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(5)) vacFLoc_fifo <- mkBypassFIFOF();

   FIFOF#(Bit#(32)) wVac_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(32)) cVac_fifo <- mkBypassFIFOF();

   Reg#(Bit#(32)) cVacR <- mkReg(maxBound);
   Reg#(Bool) newPattMultiOccR <- mkReg(False);
   Reg#(Bit#(5)) vacFLocR <- mkReg(0);

`define VACRAM AsymmetricBRAM#(Bit#(readDepthSz), Bit#(readSz), Bit#(writeDepthSz), Bit#(writeSz))
   `VACRAM vacram <- mkAsymmetricBRAM(False, False);

   function Bit#(32) compute_cVac(Bit#(32) rVac, Bool oldPattMultiOcc, Bool oldPattV, Bit#(5) oldIdx);
      OInt#(32) oldIdxOH = toOInt(oldIdx);
      Bool oldVac = !oldPattMultiOcc && oldPattV;
      Vector#(32, Bit#(1)) maskOldVac = replicate(pack(oldVac));
      Bit#(32) cVac = (~rVac) | (pack(oldIdxOH) & pack(maskOldVac));
      return cVac;
   endfunction

   function Bit#(32) compute_wVac(Bit#(5) vacFLoc, Bool newPattMultiOcc, Bit#(32) cVac);
      OInt#(32) vacFLocOH = toOInt(vacFLoc);
      Vector#(32, Bit#(1)) maskNewVac = replicate(pack(newPattMultiOcc));
      Bit#(32) wVac = ~(cVac & ((~pack(vacFLocOH)) | pack(maskNewVac)));
      return wVac;
   endfunction

   rule vacram_write;
      let v <- toGet(writeReqFifo).get;
      Vector#(wAddrHWidth, Bit#(1)) wAddrH = takeAt(5, unpack(v));
      Bit#(32) wVac = compute_wVac(vacFLocR, newPattMultiOccR, cVacR);
      $display("vacram %d: vacFLoc=%x, newPattMultiOcc=%x, cVac=%x", cycle, vacFLocR, newPattMultiOccR, cVacR);
      vacram.writeServer.put(tuple2(pack(wAddrH), wVac));
      $display("vacram %d: vacram write wAddrH=%x, wVac=%x", cycle, pack(wAddrH), wVac);
      vacram.readServer.request.put(pack(wAddrH));
      $display("vacram %d: vacram read wAddrH=%x", cycle, pack(wAddrH));
   endrule

   rule newPatt;
      let newPattMultiOcc <- toGet(newPattMultiOcc_fifo).get;
      newPattMultiOccR <= newPattMultiOcc;
   endrule

   rule update_cVac;
      let rVac <- vacram.readServer.response.get;
      let oldPattMultiOcc <- toGet(oldPattMultiOcc_fifo).get;
      let oldPattV <- toGet(oldPattV_fifo).get;
      let oldIdx <- toGet(oldIdx_fifo).get;
      Bit#(32) cVac = compute_cVac(rVac, oldPattMultiOcc, oldPattV, oldIdx);
      cVacR <= cVac;
      cVac_fifo.enq(cVac);
      $display("vacram %d: rVac = %x, cVac=%x, oldPattMultiOcc = %x, oldPattV = %x, oldIdx = %x", cycle, rVac, cVac, oldPattMultiOcc, oldPattV, oldIdx);
   endrule

   // Encode cVac and wVac
   PEnc#(32) pe_vac <- mkPriorityEncoder(toPipeOut(cVac_fifo));

   rule pe_vac_out;
      let bin <- toGet(pe_vac.bin).get;
      let vld <- toGet(pe_vac.vld).get;
      vacFLoc_fifo.enq(bin);
      vacFLocR <= bin;
      $display("vacram %d: bin=%x vld=%x", cycle, bin, vld);
   endrule

   interface Put wAddr = toPut(writeReqFifo);
   interface PipeIn oldPattV = toPipeIn(oldPattV_fifo);
   interface PipeIn oldPattMultiOcc = toPipeIn(oldPattMultiOcc_fifo);
   interface PipeIn newPattMultiOcc = toPipeIn(newPattMultiOcc_fifo);
   interface PipeIn oldIdx = toPipeIn(oldIdx_fifo);
   interface PipeOut vacFLoc = toPipeOut(vacFLoc_fifo);
endmodule
