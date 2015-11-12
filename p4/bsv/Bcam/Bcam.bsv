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

import BcamTypes::*;
import PriorityEncoder::*;
import Ram9b::*;
import PriorityEncoder1::*;

typedef struct {
   Vector#(4, Maybe#(Bit#(9))) rpatt;
} RPatt deriving (Bits, Eq);

typedef enum {S0, S1, S2} StateType
   deriving (Bits, Eq);

interface Bcam9b#(numeric type camDepth);
   interface Put#(BcamWriteReq#(TLog#(camDepth), 9)) writeServer;
   interface Put#(Bit#(9)) mPatt;
   interface PipeOut#(Bit#(TMul#(TSub#(TLog#(camDepth),9), 1024))) mIndc;
endinterface
module mkBcam9b(Bcam9b#(camDepth))
   provisos(Add#(cdep, 9, camSz)
            ,Log#(camDepth, camSz)
            ,Mul#(cdep, 1024, indcWidth)
            ,Add#(a__, 2, TLog#(TDiv#(camDepth, 8)))
            ,Add#(h__, 3, TLog#(TDiv#(camDepth, 4)))
            ,Log#(TDiv#(camDepth, 4), TAdd#(a__, 3))
            ,Add#(TAdd#(cdep, 5), b__, camSz)
            ,Add#(5, c__, camSz)
            ,Add#(2, d__, camSz)
            ,Add#(3, e__, camSz)
            ,Add#(TLog#(f__), 5, a__)
            ,Add#(a__, g__, camSz)
            ,Add#(f__, 9, camSz)
            ,Log#(TDiv#(camDepth, 32), g__)
            ,Log#(TDiv#(camDepth, 32), a__)
            ,Add#(TAdd#(TLog#(TSub#(TLog#(camDepth), 9)), 5), h__, camSz)
            ,Add#(TLog#(cdep), 5, wAddrHWidth)
            ,Add#(writeSz, 0, 10)
            ,Add#(dataSz, 1, writeSz)
            ,Add#(readSz, 0, 40)
            ,Div#(readSz, writeSz, ratio)
            ,Log#(ratio, ratioSz)
            ,Div#(camDepth, 8, writeDepth)
            ,Log#(writeDepth, writeDepthSz)
            ,Add#(readDepthSz, ratioSz, writeDepthSz)
            ,Add#(readDepthSz, 0, wAddrHWidth)
            ,Add#(vacWriteSz, 0, 32)
            ,Add#(vacReadSz, 0, 32)
            ,Div#(camDepth, 32, vacWriteDepth)
            ,Div#(vacReadSz, vacWriteSz, vacRatio)
            ,Log#(vacRatio, vacRatioSz)
            ,Log#(vacWriteDepth, vacWriteDepthSz)
            ,Add#(vacReadDepthSz, vacRatioSz, vacWriteDepthSz)
            ,Add#(vacReadDepthSz, 0, wAddrHWidth)
            ,Add#(vacWriteDepthSz, 0, wAddrHWidth)
            ,Add#(idxWriteSz, 0, 5)
            ,Add#(idxReadSz, 0, 40)
            ,Div#(camDepth, 4, idxWriteDepth)
            ,Div#(idxReadSz, idxWriteSz, idxRatio)
            ,Log#(idxRatio, idxRatioSz)
            ,Log#(idxWriteDepth, idxWriteDepthSz)
            ,Add#(idxReadDepthSz, idxRatioSz, idxWriteDepthSz)
            ,Add#(wAddrHWidth, a__, camSz)
            ,Add#(idxReadDepthSz, 0, wAddrHWidth)
         );

   let verbose = True;
   let verbose_setram = verbose && True;
   let verbose_idxram = verbose && True;
   let verbose_vacram = verbose && True;

   Reg#(Bit#(32)) cycle <- mkReg(0);
   rule every1 if (verbose);
      cycle <= cycle + 1;
   endrule

   Reg#(Bool) oldNewbPattWr_reg <- mkReg(False);

   Reg#(Bit#(9)) oldPattR <- mkReg(0);
   Reg#(Bool) oldPattVR <- mkReg(False);

   // setram fifo, remove later.
   FIFO#(Bit#(32)) oldPattIndc_fifo <- mkFIFO1();
   FIFO#(Bit#(32)) newPattIndc_fifo <- mkFIFO1();

   Reg#(Bit#(9)) wPatt_bcam <- mkReg(0);
   Reg#(Bit#(camSz)) wAddr_bcam <- mkReg(0);
   FIFO#(void) setram_read <- mkFIFO1;
   FIFO#(void) vacram_read <- mkFIFO1;
   FIFO#(void) idxram_read <- mkFIFO1;
   FIFO#(void) bcam_fsm_start <- mkFIFO1;
   FIFO#(void) ram9b_wIndx_start <- mkFIFO1;

   Reg#(Bool) oldPattMultiOcc_reg <- mkReg(False);
   Reg#(Bit#(32)) oldPattIndc_reg <- mkReg(0);
   Reg#(Bit#(32)) newPattIndc_reg <- mkReg(0);
   Reg#(Bit#(5)) newPattOccFLoc_reg <- mkReg(0);

   // BEGIN IVRAM STATES
   FIFOF#(Bool) oldPattV_fifo <- mkFIFOF();
   FIFOF#(Bool) oldPattMultiOcc_fifo <- mkFIFOF();

   FIFO#(Bool) wEnb_setram_fifo <- mkFIFO1;
   FIFO#(Bool) wEnb_vacram_fifo <- mkFIFO1;
   FIFO#(Bool) wEnb_idxram_fifo <- mkFIFO1;

   Reg#(Bit#(5)) vacFLocR <- mkReg(0);

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

   FIFOF#(Bool) oldEqNewPatt_fifo <- mkFIFOF;
   Reg#(Bool) oldEqNewPatt_reg <- mkReg(False);
   // END IVRAM STATES

   PEnc32 pe_multiOcc <- mkPriorityEncoder32();
   PEnc32 pe_vac <- mkPriorityEncoder32();

   Ram9b#(cdep) ram9b <- mkRam9b();

   `define SETRAM AsymmetricBRAM#(Bit#(readDepthSz), Bit#(readSz), Bit#(writeDepthSz), Bit#(writeSz))
   Vector#(8, `SETRAM) setRam <- replicateM(mkAsymmetricBRAM(True, False, "Setram"));

   `define VACRAM AsymmetricBRAM#(Bit#(vacReadDepthSz), Bit#(vacReadSz), Bit#(vacWriteDepthSz), Bit#(vacWriteSz))
   `VACRAM vacram <- mkAsymmetricBRAM(True, False, "Vacram");

   `define IDXRAM AsymmetricBRAM#(Bit#(idxReadDepthSz), Bit#(idxReadSz), Bit#(idxWriteDepthSz), Bit#(idxWriteSz))
   Vector#(4, `IDXRAM) idxRam <- replicateM(mkAsymmetricBRAM(True, False, "Idxram"));

   // Cam Control
   // first state, erase previous entry
   Reg#(StateType) curr_state <- mkReg(S0);
   (* fire_when_enabled *)
   rule state_S0 (curr_state == S0);
      let v <- toGet(bcam_fsm_start).get;
      let oldEqNewPatt <- toGet(oldEqNewPatt_fifo).get;
      Bool wEnb_indc = !(oldEqNewPatt && oldPattVR) && oldPattVR && oldPattMultiOcc_reg;
      Bool wEnb_iVld = !(oldEqNewPatt && oldPattVR) && oldPattVR && !oldPattMultiOcc_reg;
      if (wEnb_indc)
      ram9b.wEnb_indc.put(wEnb_indc);
      ram9b.wEnb_iVld.put(wEnb_iVld);
      ram9b.wIVld.put(False);
      oldNewbPattWr_reg <= oldPattVR;
      Bit#(9) patt = oldPattVR ? oldPattR : wPatt_bcam;
      ram9b.wPatt.put(patt);
      curr_state <= S1;
      if (verbose) $display("camctrl\t %d: currStt=%d, patt=%x oldPattV=%x, oldPatt=%x, wPatt=%x", cycle, curr_state, patt, oldPattVR, oldPattR, wPatt_bcam);
      if (verbose) $display("camctrl\t %d: currStt=%d, oldPatt=%x, oldPattV=%x, oldMultiOcc=%x, newMultiOcc=%x", cycle, curr_state, oldPattR, oldPattVR, oldPattMultiOcc_reg, newPattMultiOccR);
      if (verbose) $display("camctrl\t %d: Genereate wEnb_indc=%x and wEnb_iVld=%x", cycle, wEnb_indc, wEnb_iVld);
   endrule

   // second state, write new entry
   (* fire_when_enabled *)
   rule state_S1 (curr_state == S1);
      let oldEqNewPatt = oldEqNewPatt_reg;
      Bool wEnb_setram = !(oldEqNewPatt && oldPattVR);
      Bool wEnb_idxram = !(oldEqNewPatt && oldPattVR);
      Bool wEnb_vacram = !(oldEqNewPatt && oldPattVR) && (oldPattVR && !oldPattMultiOcc_reg) || !newPattMultiOccR;
      Bool wEnb_indc = !(oldEqNewPatt && oldPattVR);
      Bool wEnb_indx = !(oldEqNewPatt && oldPattVR) && !newPattMultiOccR;
      Bool wEnb_iVld = !(oldEqNewPatt && oldPattVR) && !newPattMultiOccR;

      if (verbose) $display("camctrl %d: currStt=%d, wEnb_setram=%x, wEnb_idxram=%x, wEnb_vacram=%x, wEnb_indx=%x, wEnb_indc=%x", cycle, curr_state, wEnb_setram, wEnb_idxram, wEnb_vacram, wEnb_indx, wEnb_indc);

      wEnb_setram_fifo.enq(wEnb_setram);
      wEnb_vacram_fifo.enq(wEnb_vacram);
      wEnb_idxram_fifo.enq(wEnb_idxram);
      ram9b.wEnb_iVld.put(wEnb_iVld);
      ram9b.wEnb_indx.put(wEnb_indx);
      ram9b.wEnb_indc.put(wEnb_indc);
      oldNewbPattWr_reg <= False;
      ram9b.wPatt.put(wPatt_bcam);
      ram9b.wIVld.put(True);
      if (verbose) $display("camctrl %d: write new pattern to iitram", cycle);
      curr_state <= S0;
   endrule

   // Index and Vacancy RAM Rules
   rule wIndc_to_all;
      let oldPattIndc <- toGet(oldPattIndc_fifo).get;
      let newPattIndc <- toGet(newPattIndc_fifo).get;
      Bit#(32) wIndc = oldNewbPattWr_reg ? oldPattIndc : newPattIndc;
      if(verbose) $display("cam9b %d: oldPattIndc=%x, newPattIndc=%x", cycle, oldPattIndc, newPattIndc);
      if(verbose) $display("cam9b %d: oldNewbPattwr=%x, wIndc=", cycle, oldNewbPattWr_reg, fshow(wIndc));
      ram9b.wIndc.put(wIndc);
   endrule

   // vacram
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

   // FIXME: shouldn't take a cycle
   rule vacram_read_request;
      let v <- toGet(vacram_read).get;
      Vector#(wAddrHWidth, Bit#(1)) wAddrH = takeAt(5, unpack(wAddr_bcam));
      vacram.readServer.request.put(pack(wAddrH));
      if (verbose) $display("vacram %d: vacram read addr=%x", cycle, pack(wAddrH));
   endrule

   rule vacram_read_response;
      let rVac <- vacram.readServer.response.get;
      let oldPattMultiOcc <- toGet(oldPattMultiOcc_fifo).get;
      let oldPattV <- toGet(oldPattV_fifo).get;
      oldPattMultiOccR <= oldPattMultiOcc;
      oldPattVR <= oldPattV;
      Bit#(32) cVac = compute_cVac(rVac, oldPattMultiOcc, oldPattV, oldIdxR);
      cVacR <= cVac;
      pe_vac.oht.put(cVac);
      if (verbose) $display("vacram %d: response cVac=%x, rVac = %x, oldPattMultiOcc = %x, oldPattV = %x, oldIdx = %x", cycle, cVac, rVac, oldPattMultiOcc, oldPattV, oldIdxR);
   endrule

   rule vacram_write_request;
      let wEnb <- toGet(wEnb_vacram_fifo).get;
      Vector#(wAddrHWidth, Bit#(1)) wAddrH = takeAt(5, unpack(wAddr_bcam));
      Bit#(32) wVac = compute_wVac(vacFLocR, newPattMultiOccR, cVacR);
      if (verbose) $display("vacram %d: vacFLoc=%x, newPattMultiOcc=%x, cVac=%x", cycle, vacFLocR, newPattMultiOccR, cVacR);
      vacram.writeServer.put(tuple2(pack(wAddrH), wVac));
      if (verbose) $display("vacram %d: vacram write wAddrH=%x, wVac=%x", cycle, pack(wAddrH), wVac);
   endrule

   // FIXME: consider merging with previous rule
   rule newPatt;
      let v <- toGet(ram9b_wIndx_start).get;
      Bit#(5) oldIdx_ = oldPattMultiOccR ? oldIdxR : 0;
      Bit#(5) newIdx_ = newPattMultiOccR ? newIdxR : vacFLocR;
      Bit#(5) wIndx = oldNewbPattWr_reg ? oldIdx_ : newIdx_;
      if (verbose) $display("vacram %d: oldPattMultiOccR=%x, newPattMultiOcc=%x, oldNewbPattWr_reg=%x", cycle, oldPattMultiOccR, newPattMultiOccR, oldNewbPattWr_reg);
      if (verbose) $display("vacram %d: compute oldIdx_=%x, newIdx_=%x wIndx=%x", cycle, oldIdx_, newIdx_, wIndx);
      wIndx_fifo.enq(wIndx);
   endrule

   rule pe_vac_out;
      let bin <- toGet(pe_vac.bin).get;
      let vld <- toGet(pe_vac.vld).get;
      vacFLocR <= bin;
      bcam_fsm_start.enq(?);
      ram9b_wIndx_start.enq(?);
      if (verbose) $display("vacram %d: bin=%x vld=%x vacFLoc=%x", cycle, bin, vld, bin);
   endrule

   // IdxRAM
   rule idxram_read_request;
      let v <- toGet(idxram_read).get;
      Vector#(wAddrHWidth, Bit#(1)) wAddrH = takeAt(5, unpack(wAddr_bcam));
      Vector#(5, Bit#(1)) wAddrL = take(unpack(wAddr_bcam));
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
      if (verbose) $display("idxram %d: response %x", cycle, data_pack);
   endrule

   rule idxram_write_request;
      let wEnb <- toGet(wEnb_idxram_fifo).get;
      //let vacFLocR <- toGet(vacFLoc_fifo2).get;
      Vector#(2, Bit#(1)) wAddrLH = takeAt(3, unpack(wAddr_bcam));
      Vector#(3, Bit#(1)) wAddrLL = take(unpack(wAddr_bcam));
      Vector#(wAddrHWidth, Bit#(1)) wAddrH = takeAt(5, unpack(wAddr_bcam));
      Bit#(idxWriteDepthSz) writeAddr = {pack(wAddrH), pack(wAddrLL)};
      if (verbose) $display("idxram %d: wAddrLH %x", cycle, pack(wAddrLH));
      if (verbose) $display("idxram %d: wAddrLL %x", cycle, pack(wAddrLL));
      if (verbose) $display("idxram %d: wAddrH %x", cycle, pack(wAddrH));
      for (Integer i=0; i<4; i=i+1) begin
         if (fromInteger(i) == pack(wAddrLH)) begin
            if (verbose) $display("idxram %d: write memory %x, addr=%x data=%x", cycle, i, writeAddr, vacFLocR);
            idxRam[i].writeServer.put(tuple2(writeAddr, vacFLocR));
         end
      end
   endrule

   rule idxram_gen_oldIdx;
      let data <- toGet(data_oldPatt_fifo).get;
      Vector#(5, Bit#(1)) wAddrL = take(unpack(wAddr_bcam));
      Bit#(5) oldIdx = data[pack(wAddrL)*5+5 : pack(wAddrL)*5];
      oldIdxR <= oldIdx;
      if (verbose) $display("idxram %d: oldIdx=%x", cycle, oldIdx);
   endrule

   rule idxram_gen_newIdx;
      let data <- toGet(data_newPatt_fifo).get;
      let newPattOccFLoc <- toGet(newPattOccFLoc_fifo).get;
      Bit#(5) newIdx = data[newPattOccFLoc*5 + 5: newPattOccFLoc*5];
      newIdxR <= newIdx;
      if (verbose) $display("idxram %d: newIdx=%x", cycle, newIdx);
   endrule

   // Original
   //FIXME:
   rule wIndx_to_ram;
      let v <- toGet(wIndx_fifo).get;
      ram9b.wIndx.put(v);
      ram9b.wAddr_indc.put(v);
      if (verbose) $display("bcam %d: ram9b wIndx=%x", cycle, v);
   endrule

   rule setram_read_request;
      let v <- toGet(setram_read).get;
      Vector#(wAddrHWidth, Bit#(1)) wAddrH = takeAt(5, unpack(wAddr_bcam));
      if (verbose) $display("setram %d: setram read addr=%x", cycle, pack(wAddrH));
      for (Integer i=0; i<8; i=i+1) begin
         setRam[i].readServer.request.put(pack(wAddrH));
      end
   endrule

   rule setram_write_request;
      let v <- toGet(wEnb_setram_fifo).get;
      Vector#(3, Bit#(1)) wAddrLH = takeAt(2, unpack(wAddr_bcam));
      Vector#(2, Bit#(1)) wAddrLL = take(unpack(wAddr_bcam));
      Vector#(wAddrHWidth, Bit#(1)) wAddrH = takeAt(5, unpack(wAddr_bcam));
      Bit#(writeDepthSz) writeAddr = {pack(wAddrH), pack(wAddrLL)};
      Maybe#(Bit#(dataSz)) writeData = tagged Valid wPatt_bcam;
      if (verbose) $display("setram %d: writeReq wAddr=%x, wData=%x", cycle, wAddr_bcam, wPatt_bcam);
      for (Integer i=0; i<8; i=i+1) begin
         if (fromInteger(i) == pack(wAddrLH)) begin
            setRam[i].writeServer.put(tuple2(writeAddr, pack(writeData)));
         end
      end
      if (verbose) $display("Setram %d: write to setram addr=%x, data=%x", cycle, wAddr_bcam, wPatt_bcam);
   endrule

   // Compute Setram Outputs
   rule setram_read_response;
      Vector#(5, Bit#(1)) wAddrL = take(unpack(wAddr_bcam));
      OInt#(32) wAddrLOH = toOInt(pack(wAddrL));
      Vector#(8, RPatt) data = newVector;
      Bit#(3) wAddrL_ram = pack(wAddrL)[4:2];
      Bit#(2) wAddrL_word = pack(wAddrL)[1:0];

      for (Integer i=0; i<8; i=i+1) begin
         let setram_data <- setRam[i].readServer.response.get;
         Vector#(4, Maybe#(Bit#(9))) m = unpack(setram_data);
         data[i] = unpack(setram_data);
      end
      Bool oldPattV = isValid(data[wAddrL_ram].rpatt[wAddrL_word]);
      Bit#(9) oldPatt = fromMaybe(?, data[wAddrL_ram].rpatt[wAddrL_word]);

      // compute old pattern
      Vector#(32, Bool) oldPattIndc;
      for (Integer i=0; i<8; i=i+1) begin
         for (Integer j=0; j<4; j=j+1) begin
            Bit#(9) rPatt = fromMaybe(?, data[i].rpatt[j]);
            Bool rPattV = isValid(data[i].rpatt[j]);
            //oldPattIndc[i*4+j] = (rPatt == oldPatt) && rPattV;
            oldPattIndc[i*4+j] = (rPatt==oldPatt) && !unpack(pack(wAddrLOH)[i*4+j]) && rPattV;
            //$display("setram %d: rPatt=%x, oldPatt=%x, wAddrLOH=%x, rPattV=%d oldPattIndc=%d", cycle, rPatt, oldPatt, wAddrLOH, rPattV, oldPattIndc[i*4+j]);
         end
      end
      Bool oldPattMultiOcc = (pack(oldPattIndc) != 0);
      if (verbose) $display("setram %d: oldPattIndc=%x", cycle, pack(oldPattIndc));

      // outputs
      oldPattIndc_fifo.enq(pack(oldPattIndc));
      oldPattIndc_reg <= pack(oldPattIndc);

      oldPattV_fifo.enq(oldPattV);
      oldPattR <= oldPatt;

      oldEqNewPatt_fifo.enq(oldPatt==wPatt_bcam);
      oldEqNewPatt_reg <= (oldPatt==wPatt_bcam);

      // detect if old pattern has multi-occurence in segment
      if (verbose) $display("setram %d: oldPattMultiOcc=%x", cycle, oldPattMultiOcc);
      oldPattMultiOcc_fifo.enq(oldPattMultiOcc);
      oldPattMultiOcc_reg <= oldPattMultiOcc;

      // compute new pattern
      Vector#(32, Bool) newPattIndc_prv;
      for (Integer i=0; i<8; i=i+1) begin
         for (Integer j=0; j<4; j=j+1) begin
            Bit#(9) rPatt = fromMaybe(?, data[i].rpatt[j]);
            Bool rPattV = isValid(data[i].rpatt[j]);
            newPattIndc_prv[i*4+j] = (rPatt == wPatt_bcam) && rPattV;
            //$display("%d: rPatt=%x, rPattV=%d newPattIndc_prv=%d", cycle, fromMaybe(?, data[i].rpatt[j]), isValid(data[i].rpatt[j]), newPattIndc_prv[i*4+j]);
         end
      end
      pe_multiOcc.oht.put(pack(newPattIndc_prv));
      Bit#(32) newPattIndc = pack(newPattIndc_prv) | pack(wAddrLOH);
      newPattIndc_fifo.enq(newPattIndc);
      newPattIndc_reg <= newPattIndc;
      if (verbose) $display("setram %d: newPattIndc=%x", cycle, newPattIndc);
   endrule

   rule setram_encoder;
      let bin <- toGet(pe_multiOcc.bin).get;
      let vld <- toGet(pe_multiOcc.vld).get;
      newPattOccFLoc_fifo.enq(bin);
      newPattOccFLoc_reg <= bin;
      newPattMultiOccR <= vld;
      if (verbose) $display("setram %d: bin=%x, vld=%x", cycle, bin, vld);
      if (verbose) $display("setram %d: newPattMultiOcc=%x, newPattOccFLoc=%x", cycle, vld, bin);
   endrule

   interface Put writeServer;
      // Cycle 0.
      method Action put(BcamWriteReq#(camSz, 9) req);
         Bit#(camSz) wAddr = req.addr;
         Bit#(9) wData = req.data;
         Vector#(wAddrHWidth, Bit#(1)) wAddrH = takeAt(5, unpack(wAddr));

         wAddr_bcam <= wAddr;
         wPatt_bcam <= wData;
         if(verbose) $display("bcam9b %d: wAddr=%x, wPatt=%x", cycle, wAddr, wData);

         setram_read.enq(?);
         vacram_read.enq(?);
         idxram_read.enq(?);

         // ram9b control
         ram9b.wAddr_indx.put(pack(wAddrH));
      endmethod
   endinterface

   interface Put mPatt = ram9b.mPatt;
   interface PipeOut mIndc = ram9b.mIndc;
endmodule

interface BinaryCam#(numeric type camDepth, numeric type pattWidth);
   //interface Put#(Tuple2#(Bit#(TLog#(camDepth)), Bit#(pattWidth))) writeServer;
   interface Put#(BcamWriteReq#(TLog#(camDepth), pattWidth)) writeServer;
   interface Server#(Bit#(pattWidth), Maybe#(Bit#(TLog#(camDepth)))) readServer;
endinterface

module mkBinaryCam(BinaryCam#(camDepth, pattWidth))
   provisos(Add#(cdep, 9, camSz)
            ,Mul#(cdep, 1024, indcWidth)
            ,Log#(camDepth, camSz)
            ,Log#(indcWidth, camSz)
            ,Mul#(pwid, 9, pattWidth)
            ,Add#(TLog#(TSub#(camSz, 9)), 10, camSz)
            ,Add#(TAdd#(TLog#(cdep), 5), a__, camSz)
            ,Add#(5, b__, camSz)
            ,Add#(2, c__, camSz)
            ,Add#(3, d__, camSz)
            ,Add#(TAdd#(cdep, 5), e__, camSz)
            ,Add#(TAdd#(TLog#(TSub#(camSz, 9)), 5), f__, camSz)
            ,Add#(g__, 3, TLog#(TDiv#(camDepth, 4)))
            ,Add#(9, h__, pattWidth)
            ,Add#(TAdd#(TLog#(cdep), 5), 2, TLog#(TDiv#(camDepth, 8)))
            ,Log#(TDiv#(camDepth, 4), TAdd#(TAdd#(TLog#(cdep), 5), 3))
            ,Log#(TDiv#(camDepth, 32), TAdd#(TLog#(cdep), 5))
            ,PriorityEncoder#(indcWidth) //??
            ,Add#(TLog#(cdep), 5, a__)
            ,Add#(TAdd#(TLog#(TSub#(TLog#(camDepth), 9)), 5), g__, camSz)
         );
   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

   let verbose = True;
   Reg#(Bit#(32)) cycle <- mkReg(0);
   rule every1 if (verbose);
      cycle <= cycle + 1;
   endrule

   FIFO#(Maybe#(Bit#(camSz))) readFifo <- mkFIFO;

   Vector#(pwid, Bcam9b#(camDepth)) cam9b <- replicateM(mkBcam9b());
   PEnc#(indcWidth) pe_bcam <- mkPriorityEncoder();

   rule cam9b_fifo_out;
      Bit#(indcWidth) mIndc = maxBound;
      for (Integer i=0; i < valueOf(pwid); i=i+1) begin
         let v_mIndc <- toGet(cam9b[i].mIndc).get;
         mIndc = mIndc & pack(v_mIndc);
      end
      pe_bcam.oht.put(mIndc);
      if (verbose) $display("bcam %d: cascading mindc=%x", cycle, mIndc);
   endrule

   rule pe_bcam_out;
      let bin <- pe_bcam.bin.get;
      let vld <- pe_bcam.vld.get;
      if (verbose) $display("pe_bcam %d: bin=%x, vld=%x", cycle, bin, vld);
      if (vld) begin
         readFifo.enq(tagged Valid bin);
      end
      else begin
         readFifo.enq(Invalid);
      end
   endrule

   interface Server readServer;
      interface Put request;
         method Action put(Bit#(pattWidth) v);
            for (Integer i=0; i<valueOf(pwid); i=i+1) begin
               Vector#(9, Bit#(1)) data = takeAt(fromInteger(i) * 9, unpack(v));
               cam9b[i].mPatt.put(pack(data));
            end
         endmethod
      endinterface
      interface Get response = toGet(readFifo);
   endinterface
   interface Put writeServer;
      method Action put(BcamWriteReq#(camSz, pattWidth) v);
         for (Integer i=0; i<valueOf(pwid); i=i+1) begin
            Vector#(9, Bit#(1)) data = takeAt(fromInteger(i) * 9, unpack(v.data));
            BcamWriteReq#(camSz, 9) req = BcamWriteReq{addr: v.addr, data: pack(data)};
            cam9b[i].writeServer.put(req);
         end
      endmethod
   endinterface
endmodule

// Generated by compiler
//(* synthesize *)
module mkBinaryCamBSV(BinaryCam#(1024, 9));
   BinaryCam#(1024, 9) bcam <- mkBinaryCam();
   interface writeServer = bcam.writeServer;
   interface readServer = bcam.readServer;
endmodule

(* synthesize *)
module mkBinaryCam_1024_9(BinaryCam#(1024, 9));
   BinaryCam#(1024, 9) bcam <- mkBinaryCam();
   interface writeServer = bcam.writeServer;
   interface readServer = bcam.readServer;
endmodule

//(* synthesize *)
//module mkBinaryCam_1024_18(BinaryCam#(1024, 18));
//   BinaryCam#(1024, 18) bcam <- mkBinaryCam();
//   interface writeServer = bcam.writeServer;
//   interface readServer = bcam.readServer;
//endmodule
//
//(* synthesize *)
//module mkBinaryCam_1024_27(BinaryCam#(1024, 27));
//   BinaryCam#(1024, 27) bcam <- mkBinaryCam();
//   interface writeServer = bcam.writeServer;
//   interface readServer = bcam.readServer;
//endmodule
//
//(* synthesize *)
//module mkBinaryCam_1024_36(BinaryCam#(1024, 36));
//   BinaryCam#(1024, 36) bcam <- mkBinaryCam();
//   interface writeServer = bcam.writeServer;
//   interface readServer = bcam.readServer;
//endmodule
//
//(* synthesize *)
//module mkBinaryCam_1024_45(BinaryCam#(1024, 45));
//   BinaryCam#(1024, 45) bcam <- mkBinaryCam();
//   interface writeServer = bcam.writeServer;
//   interface readServer = bcam.readServer;
//endmodule
//
//(* synthesize *)
//module mkBinaryCam_1024_54(BinaryCam#(1024, 54));
//   BinaryCam#(1024, 54) bcam <- mkBinaryCam();
//   interface writeServer = bcam.writeServer;
//   interface readServer = bcam.readServer;
//endmodule


