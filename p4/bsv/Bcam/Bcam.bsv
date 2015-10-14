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
import Idxram::*;
import Vacram::*;
import PriorityEncoder::*;

typedef 1 CDEP;
typedef 1 PWID;

typedef enum {S0, S1, S2} StateType
   deriving (Bits, Eq);

interface CamCtrl;
   interface PipeIn#(Bool) wEnb;
   interface PipeIn#(Bool) oldPattV;
   interface PipeIn#(Bool) oldPattMultiOcc;
   interface PipeIn#(Bool) newPattMultiOcc;
   interface PipeIn#(Bool) oldEqNewPatt;
   interface PipeOut#(Bool) wEnb_setram;
   interface PipeOut#(Bool) wEnb_idxram;
   interface PipeOut#(Bool) wEnb_vacram;
   interface PipeOut#(Bool) wEnb_indc;
   interface PipeOut#(Bool) wEnb_indx;
   interface PipeOut#(Bool) wEnb_iVld;
   interface PipeOut#(Bool) wIVld;
   interface PipeOut#(Bool) oldNewbPattWr;
endinterface
module mkCamCtrl(CamCtrl);
   let verbose = True;
   FIFOF#(Bool) wEnb_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) oldPattV_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) oldPattMultiOcc_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) newPattMultiOcc_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) oldEqNewPatt_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) wEnb_setram_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) wEnb_idxram_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) wEnb_vacram_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) wEnb_indc_fifo<- mkBypassFIFOF();
   FIFOF#(Bool) wEnb_indx_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) wEnb_iVld_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) wIVld_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) oldNewbPattWr_fifo <- mkBypassFIFOF();

   Reg#(StateType) curr_state <- mkReg(S0);

   (* fire_when_enabled *)
   rule state_s0 (curr_state == S0);
      let v <- toGet(wEnb_fifo).get;
      curr_state <= S1;
      if(verbose) $display("cc::state0");
   endrule

//   (* fire_when_enabled *)
//   rule state_s1 (curr_state == S1);
//      let oldEqNewPatt <- toGet(oldEqNewPatt_fifo).get;
//      let oldPattV <- toGet(oldPattV_fifo).get;
//      let oldPattMultiOcc <- toGet(oldPattMultiOcc_fifo).get;
//      let newPattMultiOcc <- toGet(newPattMultiOcc_fifo).get;
//
//      Bool wEnb_indc = !(oldEqNewPatt && oldPattV) && oldPattV && oldPattMultiOcc;
//      Bool wEnb_iVld = !(oldEqNewPatt && oldPattV) && oldPattV && !oldPattMultiOcc;
//      Bool oldNewbPattWr = oldPattV;
//
//      wEnb_indc_fifo.enq(wEnb_indc);
//      wEnb_iVld_fifo.enq(wEnb_iVld);
//      oldNewbPattWr_fifo.enq(oldNewbPattWr);
//      curr_state <= S2;
//      if(verbose) $display("cc::state1");
//   endrule
//
//   (* fire_when_enabled *)
//   rule state_s2 (curr_state == S2);
//      let oldEqNewPatt <- toGet(oldEqNewPatt_fifo).get;
//      let oldPattV <- toGet(oldPattV_fifo).get;
//      let oldPattMultiOcc <- toGet(oldPattMultiOcc_fifo).get;
//      let newPattMultiOcc <- toGet(newPattMultiOcc_fifo).get;
//
//      Bool wEnb_setram = !(oldEqNewPatt && oldPattV);
//      Bool wEnb_idxram = !(oldEqNewPatt && oldPattV);
//      Bool wEnb_vacram = !(oldEqNewPatt && oldPattV) && (oldPattV && !oldPattMultiOcc) || !newPattMultiOcc;
//      Bool wEnb_indc = !(oldEqNewPatt && oldPattV);
//      Bool wEnb_indx = !(oldEqNewPatt && oldPattV) && !newPattMultiOcc;
//      Bool wEnb_iVld = !(oldEqNewPatt && oldPattV) && !newPattMultiOcc;
//      Bool wIVld = True;
//      Bool oldNewbPattWr = False;
//
//      wEnb_setram_fifo.enq(wEnb_setram);
//      wEnb_idxram_fifo.enq(wEnb_idxram);
//      wEnb_vacram_fifo.enq(wEnb_vacram);
//      wEnb_indc_fifo.enq(wEnb_indc);
//      wEnb_indx_fifo.enq(wEnb_indx);
//      wEnb_iVld_fifo.enq(wEnb_iVld);
//      wIVld_fifo.enq(wIVld);
//      oldNewbPattWr_fifo.enq(oldNewbPattWr);
//      curr_state <= S0;
//      if(verbose) $display("cc::state2");
//   endrule

   interface PipeIn wEnb = toPipeIn(wEnb_fifo);
   interface PipeIn oldPattV = toPipeIn(oldPattV_fifo);
   interface PipeIn oldPattMultiOcc = toPipeIn(oldPattMultiOcc_fifo);
   interface PipeIn newPattMultiOcc = toPipeIn(newPattMultiOcc_fifo);
   interface PipeIn oldEqNewPatt = toPipeIn(oldEqNewPatt_fifo);
   interface PipeOut wEnb_setram = toPipeOut(wEnb_setram_fifo);
   interface PipeOut wEnb_idxram = toPipeOut(wEnb_idxram_fifo);
   interface PipeOut wEnb_vacram = toPipeOut(wEnb_vacram_fifo);
   interface PipeOut wEnb_indc = toPipeOut(wEnb_indc_fifo);
   interface PipeOut wEnb_indx = toPipeOut(wEnb_indx_fifo);
   interface PipeOut wEnb_iVld = toPipeOut(wEnb_iVld_fifo);
   interface PipeOut wIVld = toPipeOut(wIVld_fifo);
   interface PipeOut oldNewbPattWr = toPipeOut(oldNewbPattWr_fifo);
endmodule

interface Bcam9b#(numeric type camDepth);
   interface Put#(Tuple2#(Bit#(TLog#(camDepth)), Bit#(9))) writeServer;
   interface PipeIn#(Bit#(9)) mPatt;
   interface PipeOut#(Bit#(TMul#(TLog#(camDepth), 1024))) mIndc;
endinterface
module mkBcam9b(Bcam9b#(camDepth))
   provisos(Add#(cdep, 10, camSz)
            ,Log#(camDepth, camSz)
            ,Mul#(camSz, 1024, indcWidth)
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

//   Bcam_ram9b#(cdep) ram9b <- mkBcam_ram9b();
   Setram#(camDepth) setram <- mkSetram();
   Idxram#(camDepth) idxram <- mkIdxram();
//   Vacram#(cdep) vacram <- mkVacram();

   Vector#(2, PipeOut#(Bool)) oldPattVPipes <- mkForkVector(setram.oldPattV);
   Vector#(2, PipeOut#(Bit#(9))) oldPattPipes <- mkForkVector(setram.oldPatt);
   Vector#(2, PipeOut#(Bool)) oldPattMultiOccPipes <- mkForkVector(setram.oldPattMultiOcc);
   Vector#(2, PipeOut#(Bool)) newPattMultiOccPipes <- mkForkVector(setram.newPattMultiOcc);
   Vector#(2, PipeOut#(Bit#(9))) wPattPipes <- mkForkVector(toPipeOut(wPatt_fifo));

   rule write_request;
      let v <- toGet(writeReqFifo).get;
      Bit#(camSz) wAddr = tpl_1(v);
      Bit#(9) wData = tpl_2(v);
      setram.writeServer.put(v);
      idxram.wAddr.put(wAddr);
      wPatt_fifo.enq(wData);
      $display("cam9b %d: write_request");
   endrule

   // cam ctrl state machine
   Reg#(StateType) curr_state <- mkReg(S0);
   (* fire_when_enabled *)
   rule state_S0 (curr_state == S0);
      let oldPattV <- toGet(oldPattVPipes[0]).get;
      let oldPatt <- toGet(oldPattPipes[0]).get;
      let oldPattMultiOcc <- toGet(oldPattMultiOccPipes[0]).get;
      let newPattMultiOcc <- toGet(newPattMultiOccPipes[0]).get;
      let wPatt <- toGet(wPattPipes[0]).get;
      if (verbose) $display("%d: Genereate wEnb_indc and wEnb_iVld", cycle);
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
//
//   rule wAddr_to_all;
//      let v <- toGet(wAddr_fifo).get;
//      setram.wAddr.enq(v);
//      idxram.wAddr.enq(v);
//      vacram.wAddr.enq(v);
//      Vector#(indxWidth, Bit#(1)) indx_addr = takeAt(5, unpack(v));
//      ram9b.wAddr_indx.enq(pack(indx_addr));
//      if(verbose) $display("cam9b::wAddr ", fshow(v));
//   endrule
//
//   rule setram_wIndx;
//      let oldPatt <- toGet(oldPattMultiOcc_fifo).get;
//      let newPatt <- toGet(newPattMultiOcc_fifo).get;
//      let oldIdx <- toGet(oldIdx_fifo).get;
//      let newIdx <- toGet(newIdx_fifo).get;
//      let vacFLoc <- toGet(vacFLoc_fifo).get;
//      Bit#(5) oldIdx_ = oldPatt ? oldIdx : 0;
//      Bit#(5) newIdx_ = newPatt ? newIdx : vacFLoc;
//      t_newIdx_fifo.enq(newIdx_);
//      t_oldIdx_fifo.enq(oldIdx_);
//      if(verbose) $display("cam9b::setram_wIndx ", fshow(oldIdx_), fshow(newIdx_));
//   endrule
//
//   rule wInd_to_all;
//      let newIdx <- toGet(t_newIdx_fifo).get;
//      let oldIdx <- toGet(t_oldIdx_fifo).get;
//      let oldPattIndc <- toGet(oldPattIndc_fifo).get;
//      let newPattIndc <- toGet(newPattIndc_fifo).get;
//      let oldNewbPattWr <- toGet(oldNewbPattWr_fifo).get;
//      idxram.vacFLoc.enq(newIdx);
//      Bit#(5) wIndx = oldNewbPattWr ? oldIdx : newIdx;
//      Bit#(32) wIndc = oldNewbPattWr ? oldPattIndc : newPattIndc;
//      ram9b.wAddr_indc.enq(wIndx);
//      ram9b.wIndx.enq(wIndx);
//      ram9b.wIndc.enq(wIndc);
//      if(verbose) $display("cam9b::wInd_to_all ", fshow(wIndx), fshow(wIndc));
//   endrule

   interface Put writeServer = toPut(writeReqFifo);
//   interface PipeIn wEnb = toPipeIn(wEnb_fifo);
//   interface PipeIn wPatt = toPipeIn(wPatt_fifo);
//   interface PipeIn wAddr = toPipeIn(wAddr_fifo);
   interface PipeIn mPatt = toPipeIn(mPatt_fifo);
   interface PipeOut mIndc = toPipeOut(mIndc_fifo);
endmodule

/*
interface BcamInternal#(numeric type camDepth, numeric type pwid);
   interface Put#(Tuple2#(Bit#(TLog#(camDepth)), Bit#(9))) writeServer;
//   interface PipeIn#(Bool) wEnb;
//   interface PipeIn#(Bit#(TAdd#(TLog#(cdep), 10))) wAddr;
//   interface PipeIn#(Bit#(TMul#(pwid, 9))) wPatt;
   interface PipeIn#(Bit#(TMul#(pwid, 9))) mPatt;
   interface PipeOut#(Bit#(TAdd#(TLog#(cdep), 10))) mAddr;
   interface PipeOut#(Bool) isMatch;
endinterface
module mkBcam_internal(BcamInternal#(camDepth, pwid))
   provisos(Add#(TLog#(cdep), 10, TAdd#(TLog#(cdep), 10)),
            Add#(TAdd#(10, TLog#(cdep)), 0, camDepth),
            Mul#(pwid, 9, pattWidth),
            Mul#(cdep, 1024, indcWidth)
            );
   let verbose = True;

   FIFO#(Tuple2#(Bit#(camSz), Bit#(pattWidth))) writeReqFifo <- mkFIFO;
   FIFOF#(Bool) wEnb_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(camDepth)) wAddr_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(pattWidth)) wPatt_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(pattWidth)) mPatt_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(camDepth)) mAddr_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) match_fifo <- mkBypassFIFOF();

   Vector#(pwid, FIFOF#(Bit#(indcWidth))) mIndc_i_fifo <- replicateM(mkBypassFIFOF());
   FIFOF#(Bit#(indcWidth)) mIndc_fifo <- mkBypassFIFOF();

   Vector#(pwid, Bcam9b#(cdep)) cam9b <- replicateM(mkBcam9b());

   rule cam9b_match;
      let mPatt <- toGet(mPatt_fifo).get;
      for (Integer i=0; i < valueOf(pwid); i=i+1) begin
         Bit#(9) mPatt_vec = mPatt[i*9 + 8 : i*9];
         cam9b[i].mPatt.enq(mPatt_vec);
      end
      if (verbose) $display(fshow(mPatt));
   endrule

   rule cam9b_write;
      let wPatt <- toGet(wPatt_fifo).get;
      let wAddr <- toGet(wAddr_fifo).get;
      let wEnb <- toGet(wEnb_fifo).get;
      for (Integer i=0; i < valueOf(pwid); i=i+1) begin
         Bit#(9) wPatt_vec = wPatt[i*9 + 8 : i*9];
         cam9b[i].wPatt.enq(wPatt_vec);
         cam9b[i].wAddr.enq(wAddr);
         cam9b[i].wEnb.enq(wEnb);
      end
      if (verbose) $display("cam::write ", fshow(wPatt), fshow(wAddr), fshow(wEnb));
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

//   PrioEnc#(indcWidth) pe1024 <- mkPE1024();
//
//   rule pe1024_out;
//      let v <- toGet(pe1024.pe).get;
//      mAddr_fifo.enq(v.bin);
//      match_fifo.enq(unpack(v.vld));
//   endrule

//   interface PipeIn wEnb = toPipeIn(wEnb_fifo);
//   interface PipeIn wPatt = toPipeIn(wPatt_fifo);
//   interface PipeIn wAddr = toPipeIn(wAddr_fifo);

   interface Put writeServer = toPut(writeReqFifo);
   interface PipeIn mPatt = toPipeIn(mPatt_fifo);
   interface PipeOut mAddr = toPipeOut(mAddr_fifo);
   interface PipeOut isMatch = toPipeOut(match_fifo);
endmodule
*/

interface BinaryCam#(numeric type camDepth, numeric type pattWidth);
   interface Put#(Tuple2#(Bit#(TLog#(camDepth)), Bit#(pattWidth))) writeServer;
   interface Server#(Bit#(pattWidth), Maybe#(Bit#(TLog#(camDepth)))) readServer;
endinterface

module mkBinaryCam(BinaryCam#(camDepth, pattWidth))
   provisos(Add#(cdep, 9, camSz)
            ,Log#(camDepth, camSz)
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
         );
   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

   //BcamInternal#(TSub#(camSz, 9), pwid) bcamWrap <- mkBcam_internal(clocked_by defaultClock, reset_by defaultReset);
   FIFO#(Tuple2#(Bit#(camSz), Bit#(pattWidth))) writeReqFifo <- mkFIFO;

   FIFO#(Maybe#(Bit#(camSz))) readFifo <- mkFIFO;
   FIFO#(Bit#(pattWidth)) readReqFifo <- mkFIFO;

   Wire#(Bool) writeEnable <- mkDWire(False);
   Wire#(Bit#(camSz)) writeAddr <- mkDWire(0);
   Wire#(Bit#(pattWidth)) writeData <- mkDWire(0);
   Wire#(Bit#(pattWidth)) readData <- mkDWire(0);

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
      let v <- toGet(readReqFifo).get;
      //bcamWrap.mPatt.enq(v);
   endrule

//   rule doReadResp;
//      let v <- toGet(bcamWrap.isMatch).get;
//      let addr <- toGet(bcamWrap.mAddr).get;
//      if (v) begin
//         readFifo.enq(tagged Valid addr);
//      end
//   endrule

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


// CDEP = 1*1024, PWID = 1 = 9bits
//(* synthesize *)
//module mkBcam(BcamInternal#(1, 1));
//   BcamInternal#(1, 1) _a <- mkBcam_internal(); return _a;
//endmodule

