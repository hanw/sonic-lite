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

interface IdxVacram#(numeric type camDepth);
   interface Put#(Bit#(TLog#(camDepth))) wAddr;
   interface PipeIn#(Bool) oldPattV;
   interface PipeIn#(Bool) oldPattMultiOcc;
   interface PipeIn#(Bool) newPattMultiOcc;
   interface PipeIn#(Bool) oldNewbPattWr;
   interface PipeIn#(Bit#(5)) newPattOccFLoc;

   interface PipeIn#(Bool) wEnb_vacram;
   interface PipeIn#(Bool) wEnb_idxram;
   interface PipeOut#(Bit#(5)) wIndx;
endinterface

module mkIdxVacram(IdxVacram#(camDepth))
   provisos(Add#(cdep, 9, camSz)
            ,Log#(camDepth, camSz)
            ,Add#(TLog#(cdep), 5, wAddrHWidth)
            ,Add#(writeSz, 0, 5)
            ,Add#(readSz, 0, 40)
            ,Div#(camDepth, 4, writeDepth)
            ,Div#(readSz, writeSz, ratio)
            ,Log#(ratio, ratioSz)
            ,Log#(writeDepth, writeDepthSz)
            ,Add#(readDepthSz, ratioSz, writeDepthSz)
            ,Add#(wAddrHWidth, a__, camSz)
            ,Add#(readDepthSz, 0, wAddrHWidth)
            ,Add#(5, b__, camSz)
            ,Add#(3, c__, camSz)
            ,Add#(2, d__, camSz)
            ,Add#(e__, 3, TLog#(TDiv#(camDepth, 4)))
            ,Add#(vacWriteSz, 0, 32)
            ,Add#(vacReadSz, 0, 32)
            ,Div#(camDepth, 32, vacWriteDepth)
            ,Div#(vacReadSz, vacWriteSz, vacRatio)
            ,Log#(vacRatio, vacRatioSz)
            ,Log#(vacWriteDepth, vacWriteDepthSz)
            ,Add#(vacReadDepthSz, vacRatioSz, vacWriteDepthSz)
            ,Add#(vacReadDepthSz, 0, wAddrHWidth)
            ,Add#(vacWriteDepthSz, 0, wAddrHWidth)
         );

   // Vacancy Ram
   let verbose = True;
   Reg#(Bit#(32)) cycle <- mkReg(0);
   rule every1 if (verbose);
      cycle <= cycle + 1;
   endrule

   FIFOF#(Bit#(camSz)) writeReqFifo <- mkFIFOF;
   FIFOF#(Bool) oldPattV_fifo <- mkFIFOF();
   FIFOF#(Bool) oldPattMultiOcc_fifo <- mkFIFOF();
   FIFOF#(Bool) newPattMultiOcc_fifo <- mkFIFOF();
   FIFOF#(Bool) oldNewbPattWr_fifo <- mkFIFOF();
   FIFOF#(Bit#(5)) vacFLoc_fifo0 <- mkFIFOF();
   FIFOF#(Bit#(5)) vacFLoc_fifo1 <- mkFIFOF();
   FIFOF#(Bit#(5)) vacFLoc_fifo2 <- mkFIFOF();

   FIFOF#(Bit#(32)) wVac_fifo <- mkFIFOF();
   FIFOF#(Bit#(32)) cVac_fifo <- mkFIFOF();

   FIFOF#(Bool) wEnb_vacram_fifo <- mkFIFOF;
   FIFOF#(Bool) wEnb_idxram_fifo <- mkFIFOF;

   Vector#(4, PipeOut#(Bit#(camSz))) wAddrPipes <- mkForkVector(toPipeOut(writeReqFifo));
   //Reg#(Bit#(5)) vacFLocR <- mkReg(0);

   Reg#(Bit#(32)) cVacR <- mkReg(maxBound);
   Reg#(Bool) oldPattMultiOccR <- mkReg(False);
   Reg#(Bool) newPattMultiOccR <- mkReg(False);
   Reg#(Bit#(5)) oldIdxR <- mkReg(0);
   Reg#(Bit#(5)) newIdxR <- mkReg(0);

   // Indx Ram
   FIFOF#(Bit#(5)) newPattOccFLoc_fifo <- mkFIFOF();
   FIFOF#(Bit#(5)) wIndx_fifo <- mkFIFOF();
   FIFOF#(Bit#(5)) wAddrL_fifo <- mkFIFOF();
   FIFOF#(Bit#(160)) data_oldPatt_fifo <- mkFIFOF();
   FIFOF#(Bit#(160)) data_newPatt_fifo <- mkFIFOF();

`define VACRAM AsymmetricBRAM#(Bit#(vacReadDepthSz), Bit#(vacReadSz), Bit#(vacWriteDepthSz), Bit#(vacWriteSz))
   `VACRAM vacram <- mkAsymmetricBRAM(True, False, "Vacram");

   PEnc32 pe_vac <- mkPriorityEncoder32();

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

   rule vacram_read_request;
      let wAddr <- toGet(wAddrPipes[1]).get;
      Vector#(wAddrHWidth, Bit#(1)) wAddrH = takeAt(5, unpack(wAddr));
      vacram.readServer.request.put(pack(wAddrH));
      $display("vacram %d: vacram read wAddrH=%x", cycle, pack(wAddrH));
   endrule

   rule vacram_read_response;
      let rVac <- vacram.readServer.response.get;
      let oldPattMultiOcc <- toGet(oldPattMultiOcc_fifo).get;
      let oldPattV <- toGet(oldPattV_fifo).get;
      oldPattMultiOccR <= oldPattMultiOcc;
      Bit#(32) cVac = compute_cVac(rVac, oldPattMultiOcc, oldPattV, oldIdxR);
      cVacR <= cVac;
      pe_vac.oht.put(cVac);
      $display("vacram %d: response cVac=%x, rVac = %x, oldPattMultiOcc = %x, oldPattV = %x, oldIdx = %x", cycle, cVac, rVac, oldPattMultiOcc, oldPattV, oldIdxR);
   endrule

   rule vacram_write;
      let wAddr <- toGet(wAddrPipes[0]).get;
      let wEnb <- toGet(wEnb_vacram_fifo).get;
      let vacFLocR <- toGet(vacFLoc_fifo0).get;
      Vector#(wAddrHWidth, Bit#(1)) wAddrH = takeAt(5, unpack(wAddr));
      Bit#(32) wVac = compute_wVac(vacFLocR, newPattMultiOccR, cVacR);
      $display("vacram %d: vacFLoc=%x, newPattMultiOcc=%x, cVac=%x", cycle, vacFLocR, newPattMultiOccR, cVacR);
      vacram.writeServer.put(tuple2(pack(wAddrH), wVac));
      $display("vacram %d: vacram write wAddrH=%x, data=%x", cycle, pack(wAddrH), wVac);
   endrule

   rule newPatt;
      let newPattMultiOcc <- toGet(newPattMultiOcc_fifo).get;
      let oldNewbPattWr <- toGet(oldNewbPattWr_fifo).get;
      let vacFLocR <- toGet(vacFLoc_fifo1).get;
      newPattMultiOccR <= newPattMultiOcc;
      Bit#(5) oldIdx_ = oldPattMultiOccR ? oldIdxR : 0;
      Bit#(5) newIdx_ = newPattMultiOcc ? newIdxR : vacFLocR;
      Bit#(5) wIndx = oldNewbPattWr ? oldIdx_ : newIdx_;
      $display("vacram %d: compute oldIdx_=%x, newIdx_=%x wIndx=%x", cycle, oldIdx_, newIdx_, wIndx);
      wIndx_fifo.enq(wIndx);
   endrule

   rule pe_vac_out;
      let bin <- toGet(pe_vac.bin).get;
      let vld <- toGet(pe_vac.vld).get;
      //vacFLocR <= bin;
      vacFLoc_fifo0.enq(bin);
      vacFLoc_fifo1.enq(bin);
      vacFLoc_fifo2.enq(bin);
      $display("vacram %d: bin=%x vld=%x", cycle, bin, vld);
   endrule

`define IDXRAM AsymmetricBRAM#(Bit#(readDepthSz), Bit#(readSz), Bit#(writeDepthSz), Bit#(writeSz))
   Vector#(4, `IDXRAM) idxRam <- replicateM(mkAsymmetricBRAM(True, False, "Idxram"));

   rule idxram_write;
      let wAddr <- toGet(wAddrPipes[2]).get;
      let wEnb <- toGet(wEnb_idxram_fifo).get;
      let vacFLocR <- toGet(vacFLoc_fifo2).get;
      Vector#(2, Bit#(1)) wAddrLH = takeAt(3, unpack(wAddr));
      Vector#(3, Bit#(1)) wAddrLL = take(unpack(wAddr));
      Vector#(5, Bit#(1)) wAddrL = take(unpack(wAddr));
      Vector#(wAddrHWidth, Bit#(1)) wAddrH = takeAt(5, unpack(wAddr));
      Bit#(writeDepthSz) writeAddr = {pack(wAddrH), pack(wAddrLL)};
      if (verbose) $display("idxram %d: wAddrLH %x", cycle, pack(wAddrLH));
      if (verbose) $display("idxram %d: wAddrLL %x", cycle, pack(wAddrLL));
      if (verbose) $display("idxram %d: wAddrH %x", cycle, pack(wAddrH));
      for (Integer i=0; i<4; i=i+1) begin
         if (fromInteger(i) == pack(wAddrLH)) begin
            if (verbose) $display("idxram %d: write memory %x, addr=%x data=%x", cycle, i, writeAddr, vacFLocR);
            idxRam[i].writeServer.put(tuple2(writeAddr, vacFLocR));
         end
      end
      if (verbose) $display("idxram %d: wAddrL %x", cycle, pack(wAddrL));
      wAddrL_fifo.enq(pack(wAddrL));
   endrule

   rule idxram_read;
      let wAddr <- toGet(wAddrPipes[3]).get;
      Vector#(wAddrHWidth, Bit#(1)) wAddrH = takeAt(5, unpack(wAddr));
      Vector#(5, Bit#(1)) wAddrL = take(unpack(wAddr));
      for (Integer i=0; i<4; i=i+1) begin
         idxRam[i].readServer.request.put(pack(wAddrH));
      end
      if (verbose) $display("idxram %d: idxram read addr=%x", cycle, pack(wAddrH));
   endrule

   rule idxram_readdata;
      Vector#(4, Bit#(40)) data = newVector;
      for (Integer i=0; i<4; i=i+1) begin
         let v <- idxRam[i].readServer.response.get;
         data[i] = v;
      end
      Bit#(160) data_pack = pack(data);
      data_oldPatt_fifo.enq(data_pack);
      data_newPatt_fifo.enq(data_pack);
      $display("idxram %d: response %x", cycle, data_pack);
   endrule

   rule oldPatt_indx;
      let wAddrL <- toGet(wAddrL_fifo).get;
      let data <- toGet(data_oldPatt_fifo).get;
      Bit#(5) oldIdx = data[wAddrL*5+5 : wAddrL*5];
      oldIdxR <= oldIdx;
      $display("idxram %d: oldIdx=%x", cycle, oldIdx);
   endrule

   rule newPattOccFloc_idx;
      let data <- toGet(data_newPatt_fifo).get;
      let newPattOccFLoc <- toGet(newPattOccFLoc_fifo).get;
      Bit#(5) newIdx = data[newPattOccFLoc*5 + 5: newPattOccFLoc*5];
      newIdxR <= newIdx;
      $display("idxram %d: newIdx=%x", cycle, newIdx);
   endrule

   interface Put wAddr = toPut(writeReqFifo);
   interface PipeIn oldPattV = toPipeIn(oldPattV_fifo);
   interface PipeIn oldPattMultiOcc = toPipeIn(oldPattMultiOcc_fifo);
   interface PipeIn newPattMultiOcc = toPipeIn(newPattMultiOcc_fifo);
   interface PipeIn newPattOccFLoc = toPipeIn(newPattOccFLoc_fifo);
   interface PipeIn oldNewbPattWr = toPipeIn(oldNewbPattWr_fifo);
   interface PipeIn wEnb_vacram = toPipeIn(wEnb_vacram_fifo);
   interface PipeIn wEnb_idxram = toPipeIn(wEnb_idxram_fifo);
   interface PipeOut wIndx = toPipeOut(wIndx_fifo);
endmodule
