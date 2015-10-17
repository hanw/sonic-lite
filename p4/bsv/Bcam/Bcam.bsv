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

import Setram::*;
import IdxVacRam::*;
import Ram9b::*;
import PriorityEncoder::*;

typedef enum {S0, S1, S2} StateType
   deriving (Bits, Eq);

interface Bcam9b#(numeric type camDepth);
   interface Put#(Tuple2#(Bit#(TLog#(camDepth)), Bit#(9))) writeServer;
   interface PipeIn#(Bit#(9)) mPatt;
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
         );

   let verbose = True;
   Reg#(Bit#(32)) cycle <- mkReg(0);
   rule every1;
      cycle <= cycle + 1;
   endrule

   FIFO#(Tuple2#(Bit#(camSz), Bit#(9))) writeReqFifo <- mkFIFO;

   FIFOF#(Bit#(9)) mPatt_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(9)) wPatt_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(indcWidth)) mIndc_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) oldNewbPattWr_fifo <- mkFIFOF();

   Reg#(Bit#(9)) oldPattR <- mkReg(0);
   Reg#(Bool) oldPattVR <- mkReg(False);
   Reg#(Bool) oldPattMultiOccR <- mkReg(False);
   Reg#(Bool) newPattMultiOccR <- mkReg(False);

   Ram9b#(cdep) ram9b <- mkRam9b();
   Setram#(camDepth) setram <- mkSetram();
   IdxVacram#(camDepth) ivram <- mkIdxVacram();

   FIFOF#(Bool) oldEqNewPatt_fifo <- mkBypassFIFOF;
   Vector#(2, PipeOut#(Bool)) oldEqNewPattPipes <- mkForkVector(toPipeOut(oldEqNewPatt_fifo));

   rule write_request;
      let v <- toGet(writeReqFifo).get;
      Bit#(camSz) wAddr = tpl_1(v);
      Bit#(9) wData = tpl_2(v);
      Vector#(wAddrHWidth, Bit#(1)) wAddrH = takeAt(5, unpack(wAddr));
      setram.writeServer.put(v);
      ivram.wAddr.put(wAddr);
      wPatt_fifo.enq(wData);
      ram9b.wAddr_indx.enq(pack(wAddrH));
      ram9b.wPatt.enq(wData);
      $display("cam9b %d: write_request wAddr=%x wAddrH=%x", cycle, wAddr, pack(wAddrH));
   endrule

   rule generate_oldEqNewPatt;
      let wPatt <- toGet(wPatt_fifo).get;
      let oldPatt <- toGet(setram.oldPatt).get;
      Bool oldEqNewPatt = (wPatt == oldPatt);
      $display("bcam %d: oldEqNewPatt=%x", cycle, oldEqNewPatt);
      oldPattR <= oldPatt;
      oldEqNewPatt_fifo.enq(oldEqNewPatt);
      if (verbose) $display("bcam %d: oldPatt=%x", cycle, oldPatt);
   endrule

   rule update_oldPattV;
      let oldPattV <- toGet(setram.oldPattV).get;
      oldPattVR <= oldPattV;
      ivram.oldPattV.enq(oldPattV);
      if (verbose) $display("bcam %d: oldPattV=%x", cycle, oldPattV);
   endrule

   rule update_oldMultiOcc;
      let oldPattMultiOcc <- toGet(setram.oldPattMultiOcc).get;
      ivram.oldPattMultiOcc.enq(oldPattMultiOcc);
      oldPattMultiOccR <= oldPattMultiOcc;
      if (verbose) $display("bcam %d: oldMultiOcc=%x", cycle, oldPattMultiOcc);
   endrule

   rule update_newMultiOcc;
      let newPattMultiOcc <- toGet(setram.newPattMultiOcc).get;
      ivram.newPattMultiOcc.enq(newPattMultiOcc);
      newPattMultiOccR <= newPattMultiOcc;
      if (verbose) $display("bcam %d: newMultiOcc=%x", cycle, newPattMultiOcc);
   endrule

   // Cam Control
   Reg#(StateType) curr_state <- mkReg(S0);
   (* fire_when_enabled *)
   rule state_S0 (curr_state == S0);
      let oldEqNewPatt <- toGet(oldEqNewPattPipes[0]).get;
      Bool wEnb_indc = !(oldEqNewPatt && oldPattVR) && oldPattVR && oldPattMultiOccR;
      Bool wEnb_iVld = !(oldEqNewPatt && oldPattVR) && oldPattVR && !oldPattMultiOccR;
      ivram.oldNewbPattWr.enq(oldPattVR);
      oldNewbPattWr_fifo.enq(oldPattVR); // FIXME: no need??
      curr_state <= S1;
      if (verbose) $display("camctrl %d: oldPatt=%x, oldPattV=%x, oldMultiOcc=%x, newMultiOcc=%x", cycle, oldPattR, oldPattVR, oldPattMultiOccR, newPattMultiOccR);
      if (verbose) $display("camctrl %d: Genereate wEnb_indc=%x and wEnb_iVld=%x", cycle, wEnb_indc, wEnb_iVld);
   endrule

   (* fire_when_enabled *)
   rule state_S1 (curr_state == S1);
      let oldEqNewPatt <- toGet(oldEqNewPattPipes[1]).get;
      Bool wEnb_setram = !(oldEqNewPatt && oldPattVR);
      Bool wEnb_idxram = !(oldEqNewPatt && oldPattVR);
      Bool wEnb_vacram = !(oldEqNewPatt && oldPattVR) && (oldPattVR && !oldPattMultiOccR) || !newPattMultiOccR;
      Bool wEnb_indc = !(oldEqNewPatt && oldPattVR);
      Bool wEnb_indx = !(oldEqNewPatt && oldPattVR) && !newPattMultiOccR;
      Bool wEnb_iVld = !(oldEqNewPatt && oldPattVR) && !newPattMultiOccR;
      if (verbose) $display("camctrl %d: wEnb_setram=%x, wEnb_idxram=%x, wEnb_vacram=%x, wEnb_indx=%x, wEnb_indc=%x", cycle, wEnb_setram, wEnb_idxram, wEnb_vacram, wEnb_indx, wEnb_indc);

      setram.wEnb_setram.enq(wEnb_setram);
      ivram.wEnb_vacram.enq(wEnb_vacram);
      ivram.wEnb_idxram.enq(wEnb_idxram);
      ram9b.wEnb_iVld.enq(wEnb_iVld);
      ram9b.wEnb_indx.enq(wEnb_indx);
      ram9b.wEnb_indc.enq(wEnb_indc);
      ram9b.wIVld.enq(True);
      if (verbose) $display("camctrl %d: write new pattern to iitram", cycle);
      curr_state <= S0;
   endrule

   // Index and Vacancy RAM Rules
   rule ivram_newPattOcc;
      let newPattOccFLoc <- toGet(setram.newPattOccFLoc).get;
      ivram.newPattOccFLoc.enq(newPattOccFLoc);
   endrule

   rule wIndc_to_all;
      let oldPattIndc <- toGet(setram.oldPattIndc).get;
      let newPattIndc <- toGet(setram.newPattIndc).get;
      let oldNewbPattWr <- toGet(oldNewbPattWr_fifo).get;
      Bit#(32) wIndc = oldNewbPattWr ? oldPattIndc : newPattIndc;
      if(verbose) $display("cam9b %d: oldNewbPattwr=%x, wIndc=", cycle, oldNewbPattWr, fshow(wIndc));
      ram9b.wIndc.enq(wIndc);
   endrule

   rule wIndx_to_ram;
      let v <- toGet(ivram.wIndx).get;
      ram9b.wIndx.enq(v);
      ram9b.wAddr_indc.enq(v);
   endrule

   rule read_mPatt;
      let v <- toGet(mPatt_fifo).get;
      ram9b.mPatt.enq(v);
   endrule

   rule write_mIndc;
      let v <- toGet(ram9b.mIndc).get;
      mIndc_fifo.enq(v);
   endrule

   interface Put writeServer = toPut(writeReqFifo);
   interface PipeIn mPatt = toPipeIn(mPatt_fifo);
   interface PipeOut mIndc = toPipeOut(mIndc_fifo);
endmodule

interface BinaryCam#(numeric type camDepth, numeric type pattWidth);
   interface Put#(Tuple2#(Bit#(TLog#(camDepth)), Bit#(pattWidth))) writeServer;
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
            ,PriorityEncoder::PriorityEncoder#(indcWidth) //??
            ,Add#(TLog#(cdep), 5, a__)
            ,Add#(TAdd#(TLog#(TSub#(TLog#(camDepth), 9)), 5), g__, camSz)
         );
   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

   FIFO#(Tuple2#(Bit#(camSz), Bit#(pattWidth))) writeReqFifo <- mkFIFO;

   FIFO#(Maybe#(Bit#(camSz))) readFifo <- mkFIFO;
   FIFO#(Bit#(pattWidth)) readReqFifo <- mkFIFO;

   Wire#(Bool) writeEnable <- mkDWire(False);
   Wire#(Bit#(camSz)) writeAddr <- mkDWire(0);
   Wire#(Bit#(pattWidth)) writeData <- mkDWire(0);
   Wire#(Bit#(pattWidth)) readData <- mkDWire(0);

   Vector#(pwid, FIFOF#(Bit#(indcWidth))) mIndc_i_fifo <- replicateM(mkBypassFIFOF());
   FIFOF#(Bit#(indcWidth)) mIndc_fifo <- mkBypassFIFOF();

   Vector#(pwid, Bcam9b#(camDepth)) cam9b <- replicateM(mkBcam9b());
   PEnc#(indcWidth) pe_bcam <- mkPriorityEncoder();

   rule writeBcam;
      let v <- toGet(writeReqFifo).get;
      let wAddr = tpl_1(v);
      let wData = tpl_2(v);
      for (Integer i=0; i<valueOf(pwid); i=i+1) begin
         Vector#(9, Bit#(1)) data = takeAt(fromInteger(i) * 9, unpack(wData));
         cam9b[i].writeServer.put(tuple2(wAddr, pack(data)));
      end
   endrule

   rule readBcam;
      let mPatt <- toGet(readReqFifo).get;
      for (Integer i=0; i<valueOf(pwid); i=i+1) begin
         Vector#(9, Bit#(1)) data = takeAt(fromInteger(i) * 9, unpack(mPatt));
         cam9b[i].mPatt.enq(pack(data));
      end
   endrule

   rule cam9b_fifo_out;
      for (Integer i=0; i < valueOf(pwid); i=i+1) begin
         let mIndc <- toGet(cam9b[i].mIndc).get;
         mIndc_i_fifo[i].enq(mIndc);
      end
   endrule

   // cascading by AND'ing matches
   rule cascading_matches;
      Bit#(indcWidth) mIndc = maxBound;
      for (Integer i=0; i < valueOf(pwid); i=i+1) begin
         let v <- toGet(mIndc_i_fifo[i]).get;
         mIndc = mIndc & v;
      end
      pe_bcam.oht.put(mIndc);
      $display("bcam: cascading mindc=%x", mIndc);
   endrule

   rule pe_bcam_out;
      let bin <- pe_bcam.bin.get;
      let vld <- pe_bcam.vld.get;
      $display("pe_bcam: bin=%x, vld=%x", bin, vld);
      if (vld) begin
         readFifo.enq(tagged Valid bin);
      end
      else begin
         readFifo.enq(Invalid);
      end
   endrule

   interface Server readServer;
      interface Put request;
         method Action put(Bit#(pattWidth) data);
            readReqFifo.enq(data);
         endmethod
      endinterface
      interface Get response = toGet(readFifo);
   endinterface
   interface Put writeServer = toPut(writeReqFifo);
endmodule

