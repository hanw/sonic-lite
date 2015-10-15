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
            ,Log#(TDiv#(camDepth, 32), a__)
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

//   Bcam_ram9b#(cdep) ram9b <- mkBcam_ram9b();
   Setram#(camDepth) setram <- mkSetram();
   IdxVacram#(camDepth) ivram <- mkIdxVacram();

   Vector#(3, PipeOut#(Bool)) oldPattVPipes <- mkForkVector(setram.oldPattV);
   Vector#(2, PipeOut#(Bit#(9))) oldPattPipes <- mkForkVector(setram.oldPatt);
   Vector#(3, PipeOut#(Bool)) oldPattMultiOccPipes <- mkForkVector(setram.oldPattMultiOcc);
   Vector#(3, PipeOut#(Bool)) newPattMultiOccPipes <- mkForkVector(setram.newPattMultiOcc);
   Vector#(2, PipeOut#(Bit#(9))) wPattPipes <- mkForkVector(toPipeOut(wPatt_fifo));

   rule write_request;
      let v <- toGet(writeReqFifo).get;
      Bit#(camSz) wAddr = tpl_1(v);
      Bit#(9) wData = tpl_2(v);
      setram.writeServer.put(v);
      ivram.wAddr.put(wAddr);
      wPatt_fifo.enq(wData);
      $display("cam9b %d: write_request");
   endrule

   // Cam Control
   Reg#(StateType) curr_state <- mkReg(S0);
   (* fire_when_enabled *)
   rule state_S0 (curr_state == S0);
      let oldPattV <- toGet(oldPattVPipes[0]).get;
      let oldPatt <- toGet(oldPattPipes[0]).get;
      let oldPattMultiOcc <- toGet(oldPattMultiOccPipes[0]).get;
      let newPattMultiOcc <- toGet(newPattMultiOccPipes[0]).get;
      let wPatt <- toGet(wPattPipes[0]).get;
      if (verbose) $display("%d: Genereate wEnb_indc and wEnb_iVld", cycle);
      ivram.oldNewbPattWr.enq(oldPattV);
      oldNewbPattWr_fifo.enq(oldPattV);
      curr_state <= S1;
   endrule

   (* fire_when_enabled *)
   rule state_S1 (curr_state == S1);
      let oldPattV <- toGet(oldPattVPipes[1]).get;
      let oldPatt <- toGet(oldPattPipes[1]).get;
      let oldPattMultiOcc <- toGet(oldPattMultiOccPipes[1]).get;
      let newPattMultiOcc <- toGet(newPattMultiOccPipes[1]).get;
      let wPatt <- toGet(wPattPipes[1]).get;
      if (verbose) $display("%d: Genereate wEnb_indc and wEnb_iVld and others", cycle);
      curr_state <= S0;
   endrule

   // Index and Vacancy RAM Rules
   rule ivram_oldPattV;
      let oldPattV <- toGet(oldPattVPipes[2]).get;
      ivram.oldPattV.enq(oldPattV);
   endrule
   rule ivram_oldPattMultiOcc;
      let oldPattMultiOcc <- toGet(oldPattMultiOccPipes[2]).get;
      ivram.oldPattMultiOcc.enq(oldPattMultiOcc);
   endrule
   rule ivram_newPattMultiOcc;
      let newPattMultiOcc <- toGet(newPattMultiOccPipes[2]).get;
      ivram.newPattMultiOcc.enq(newPattMultiOcc);
   endrule
   rule ivram_newPattOcc;
      let newPattOccFLoc <- toGet(setram.newPattOccFLoc).get;
      ivram.newPattOccFLoc.enq(newPattOccFLoc);
   endrule

//   rule cam_oldEqNewPatt;
//      let wPatt <- toGet(t_wPatt_fifo).get;
//      let oldPatt <- toGet(setram.oldPatt).get;
//      let oldNewbPattWr <- toGet(cc.oldNewbPattWr).get;
//      Bool oldEqNewPatt = (oldPatt == wPatt);
//      Bit#(9) t_wPatt = oldNewbPattWr ? oldPatt : wPatt;
//      oldNewbPattWr_fifo.enq(oldNewbPattWr);
//      ram9b.wPatt.enq(t_wPatt);
//      cc.oldEqNewPatt.enq(oldEqNewPatt);
//      if(verbose) $display("cam9b::wPatt ", fshow(wPatt));
//   endrule

   rule wInd_to_all;
      let oldPattIndc <- toGet(setram.oldPattIndc).get;
      let newPattIndc <- toGet(setram.newPattIndc).get;
      let oldNewbPattWr <- toGet(oldNewbPattWr_fifo).get;
      Bit#(32) wIndc = oldNewbPattWr ? oldPattIndc : newPattIndc;
      if(verbose) $display("cam9b::wInd_to_all ", fshow(wIndc));
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
      Vector#(indcWidth, Bit#(1)) mIndc_vec = replicate(1);
      Bit#(indcWidth) mIndc = pack(mIndc_vec);
      for (Integer i=0; i < valueOf(pwid); i=i+1) begin
         let v <- toGet(mIndc_i_fifo[i]).get;
         mIndc = mIndc & v;
      end
      mIndc_fifo.enq(mIndc);
   endrule

   PEnc#(indcWidth) pe_bcam <- mkPriorityEncoder(toPipeOut(mIndc_fifo));
   rule pe_bcam_out;
      let bin <- toGet(pe_bcam.bin).get;
      let vld <- toGet(pe_bcam.vld).get;
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

