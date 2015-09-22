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

import M20k::*;
import PriorityEncoder::*;

typedef 1 CDEP;
typedef 1 PWID;

interface Bcam_ram9bx1k;
   interface PipeIn#(Bool) wEnb_iVld;
   interface PipeIn#(Bool) wEnb_indx;
   interface PipeIn#(Bool) wEnb_indc;
   interface PipeIn#(Bit#(9)) mPatt;
   interface PipeIn#(Bit#(9)) wPatt;
   interface PipeIn#(Bit#(5)) wAddr_indx;
   interface PipeIn#(Bit#(5)) wAddr_indc;
   interface PipeIn#(Bit#(5)) wIndx;
   interface PipeIn#(Bit#(32)) wIndc;
   interface PipeIn#(Bool) wIVld;
   interface PipeOut#(Bit#(1024)) mIndc;
endinterface
module mkBcam_ram9bx1k(Bcam_ram9bx1k);
   FIFOF#(Bool) wEnb_iVld_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) wEnb_indx_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) wEnb_indc_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(9)) mPatt_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(9)) wPatt_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(5)) wAddr_indx_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(5)) wAddr_indc_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(5)) wIndx_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(32)) wIndc_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) wIVld_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(1024)) mIndc_fifo <- mkBypassFIFOF();

   Wire#(Bit#(32)) iVld_wires <- mkDWire(0);

   // WWID = 1, RWID = 32, WDEP = 16384, OREG = 1, INIT = 1
   M20k#(1, 32, 16384) vldram <- mkM20k();
   // WWID = 5, RWID = 40, WDEP = 4096, OREG = 0, INIT = 1
   Vector#(4, M20k#(5, 40, 4096)) indxram <- replicateM(mkM20k());
   // DWID = 32, DDEP = 32, MRDW = "DONT_CARE", RREG=ALL, INIT=1
   Vector#(8, M20k#(32, 32, 32)) dpmlab <- replicateM(mkM20k());

   Vector#(4, Wire#(Bit#(40))) indx <- replicateM(mkDWire(0));
   rule ram_input;
      let wEnb_iVld <- toGet(wEnb_iVld_fifo).get;
      let wPatt <- toGet(wPatt_fifo).get;
      let mPatt <- toGet(mPatt_fifo).get;
      let wAddr_indx <- toGet(wAddr_indx_fifo).get;
      let wAddr_indc <- toGet(wAddr_indc_fifo).get;
      let wIVld <- toGet(wIVld_fifo).get;
      let wEnb_indx <- toGet(wEnb_indx_fifo).get;
      let wEnb_indc <- toGet(wEnb_indc_fifo).get;
      let wIndx <- toGet(wIndx_fifo).get;
      let wIndc <- toGet(wIndc_fifo).get;
      vldram.wEnb.enq(wEnb_iVld);
      vldram.wAddr.enq({wPatt, wAddr_indx});
      vldram.wData.enq(pack(wIVld));
      vldram.rAddr.enq(mPatt);

      for (Integer i=0; i<4; i=i+1) begin
         indxram[i].wEnb.enq(wEnb_indx && (wAddr_indx[4:3] == fromInteger(i)));
         indxram[i].wAddr.enq({wPatt, wAddr_indx[2:0]});
         indxram[i].wData.enq(wIndx);
         indxram[i].rAddr.enq(mPatt);
//         for (Integer j=0; j<8; j=j+1) begin
//            dpmlab[i].wEnb.enq(wEnb_indc && (wAddr_indx[4:3] == fromInteger(i)) &&
//                                             wAddr_indx[2:0] == fromInteger(j));
//            dpmlab[i].wAddr.enq(wAddr_indc);
//            dpmlab[i].wData.enq(wIndc);
//         end
      end
   endrule

   rule vldram_output;
      let v <- toGet(vldram.rData).get;
      iVld_wires <= v;
   endrule

   rule indxram_output;
      for (Integer i=0; i<4; i=i+1) begin
         let v <- toGet(indxram[i].rData).get;
         indx[i] <= v;
      end
   endrule

   interface PipeIn wEnb_iVld = toPipeIn(wEnb_iVld_fifo);
   interface PipeIn wEnb_indx = toPipeIn(wEnb_indx_fifo);
   interface PipeIn wEnb_indc = toPipeIn(wEnb_indc_fifo);
   interface PipeIn mPatt = toPipeIn(mPatt_fifo);
   interface PipeIn wPatt = toPipeIn(wPatt_fifo);
   interface PipeIn wAddr_indx = toPipeIn(wAddr_indx_fifo);
   interface PipeIn wAddr_indc = toPipeIn(wAddr_indc_fifo);
   interface PipeIn wIndx = toPipeIn(wIndx_fifo);
   interface PipeIn wIndc = toPipeIn(wIndc_fifo);
   interface PipeIn wIVld = toPipeIn(wIVld_fifo);
   interface PipeOut mIndc = toPipeOut(mIndc_fifo);
endmodule

interface Bcam_ram9b#(numeric type cdep);
   interface PipeIn#(Bool) wEnb_iVld;
   interface PipeIn#(Bool) wEnb_indx;
   interface PipeIn#(Bool) wEnb_indc;
   interface PipeIn#(Bit#(9)) mPatt;
   interface PipeIn#(Bit#(9)) wPatt;
   interface PipeIn#(Bit#(TAdd#(TLog#(cdep), 5))) wAddr_indx;
   interface PipeIn#(Bit#(5)) wAddr_indc;
   interface PipeIn#(Bit#(5)) wIndx;
   interface PipeIn#(Bit#(32)) wIndc;
   interface PipeIn#(Bool) wIVld;
   interface PipeOut#(Bit#(TMul#(cdep, 1024))) mIndc;
endinterface
module mkBcam_ram9b(Bcam_ram9b#(cdep))
   provisos(Add#(TLog#(cdep), 5, TAdd#(TLog#(cdep), 5)),
            Add#(TAdd#(TLog#(cdep), 5), 0, indxWidth),
            Mul#(cdep, 1024, indcWidth));
   FIFOF#(Bool) wEnb_iVld_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) wEnb_indx_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) wEnb_indc_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(9)) mPatt_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(9)) wPatt_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(indxWidth)) wAddr_indx_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(5)) wAddr_indc_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(5)) wIndx_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(32)) wIndc_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) wIVld_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(indcWidth)) mIndc_fifo <- mkBypassFIFOF();

   Vector#(cdep, Bcam_ram9bx1k) ram <- replicateM(mkBcam_ram9bx1k());

   rule ram_instance;
      let wEnb_iVld <- toGet(wEnb_iVld_fifo).get;
      let wEnb_indx <- toGet(wEnb_indx_fifo).get;
      let wEnb_indc <- toGet(wEnb_indc_fifo).get;
      let wAddr_indx <- toGet(wAddr_indx_fifo).get;
      let mPatt <- toGet(mPatt_fifo).get;
      let wPatt <- toGet(wPatt_fifo).get;
      let wAddr_indc <- toGet(wAddr_indc_fifo).get;
      let wIndx <- toGet(wIndx_fifo).get;
      let wIVld <- toGet(wIVld_fifo).get;
      let wIndc <- toGet(wIndc_fifo).get;

      Vector#(cdep, Bool) wEnb = replicate(False);
      for (Integer i=0; i < valueOf(cdep); i=i+1) begin
         wEnb[i] = ((wAddr_indx >> 5) == fromInteger(i));
         ram[i].wEnb_iVld.enq(wEnb_iVld && wEnb[i]);
         ram[i].wEnb_indx.enq(wEnb_indx && wEnb[i]);
         ram[i].wEnb_indc.enq(wEnb_indc && wEnb[i]);
         ram[i].mPatt.enq(mPatt);
         ram[i].wPatt.enq(wPatt);
         ram[i].wAddr_indc.enq(wAddr_indc);
         ram[i].wIndx.enq(wIndx);
         ram[i].wIVld.enq(wIVld);
         ram[i].wIndc.enq(wIndc);
      end
   endrule

   rule ram_output;
      Vector#(cdep, Bit#(1024)) mIndc;
      for (Integer i=0; i < valueOf(cdep); i=i+1) begin
         let v <- toGet(ram[i].mIndc).get;
         mIndc[i] = v;
      end
      mIndc_fifo.enq(pack(mIndc));
   endrule

   interface PipeIn wEnb_iVld = toPipeIn(wEnb_iVld_fifo);
   interface PipeIn wEnb_indx = toPipeIn(wEnb_indx_fifo);
   interface PipeIn wEnb_indc = toPipeIn(wEnb_indc_fifo);
   interface PipeIn mPatt = toPipeIn(mPatt_fifo);
   interface PipeIn wPatt = toPipeIn(wPatt_fifo);
   interface PipeIn wAddr_indx = toPipeIn(wAddr_indx_fifo);
   interface PipeIn wAddr_indc = toPipeIn(wAddr_indc_fifo);
   interface PipeIn wIndx = toPipeIn(wIndx_fifo);
   interface PipeIn wIndc = toPipeIn(wIndc_fifo);
   interface PipeIn wIVld = toPipeIn(wIVld_fifo);
   interface PipeOut mIndc = toPipeOut(mIndc_fifo);
endmodule

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

typedef struct {
   Vector#(4, Maybe#(Bit#(9))) rpatt;
} RPatt deriving (Bits, Eq);
instance FShow#(RPatt);
   function Fmt fshow (RPatt r);
      return ($format("<") + fshow(r.rpatt[0]) + fshow(r.rpatt[1])
                           + fshow(r.rpatt[2]) + fshow(r.rpatt[3])
                           + $format(">"));
   endfunction
endinstance

interface Setram#(numeric type cdep);
   interface PipeIn#(Bool) wEnb;
   interface PipeIn#(Bit#(9)) wPatt;
   interface PipeIn#(Bit#(TAdd#(TLog#(cdep), 10))) wAddr;
   interface PipeOut#(Bit#(9)) oldPatt;
   interface PipeOut#(Bool) oldPattV;
   interface PipeOut#(Bool) oldPattMultiOcc;
   interface PipeOut#(Bool) newPattMultiOcc;
   interface PipeOut#(Bit#(5)) newPattOccFLoc;
   interface PipeOut#(Bit#(32)) oldPattIndc;
   interface PipeOut#(Bit#(32)) newPattIndc;
endinterface
module mkSetram(Setram#(cdep))
   provisos(Add#(TLog#(cdep), 10, TAdd#(TLog#(cdep), 10)),
            Add#(TAdd#(TLog#(cdep), 10), 0, camDepth),
            Add#(TAdd#(TLog#(cdep), 5), 0, wAddrHWidth),
            Log#(cdep, 0));

   let verbose = True;
   FIFOF#(Bool) wEnb_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(9)) wPatt_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(camDepth)) wAddr_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(9)) oldPatt_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) oldPattV_fifo<- mkBypassFIFOF();
   FIFOF#(Bool) oldPattMultiOcc_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) newPattMultiOcc_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(5)) newPattOccFLoc_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(32)) oldPattIndc_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(32)) newPattIndc_fifo <- mkBypassFIFOF();

   FIFOF#(Vector#(8, RPatt)) rpatt_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(5)) wAddrL_fifo <- mkFIFOF();
   FIFOF#(OInt#(32)) wAddrLOH_fifo <- mkFIFOF();
   FIFOF#(Bit#(9)) wPatt2_fifo <- mkFIFOF();

   Vector#(8, M20k#(10, 40, 128)) ram <- replicateM(mkM20k());

   Reg#(Bit#(32)) cycle <- mkReg(0);
   rule every1;
      cycle <= cycle + 1;
   endrule

   rule setram_input;
      let wEnb <- toGet(wEnb_fifo).get;
      let wAddr <- toGet(wAddr_fifo).get;
      let wPatt <- toGet(wPatt_fifo).get;

      Vector#(3, Bit#(1)) wAddrLH = takeAt(2, unpack(wAddr));
      Vector#(2, Bit#(1)) wAddrLL = take(unpack(wAddr));
      Vector#(wAddrHWidth, Bit#(1)) wAddrH = takeAt(5, unpack(wAddr));
      Vector#(5, Bit#(1)) wAddrL = take(unpack(wAddr));
      OInt#(32) wAddrLOH = toOInt(pack(wAddrL));

      for (Integer i=0; i<8; i=i+1) begin
         // WWID=10, RWID=40, WDEP=CDEP*1024/8, OREG=0, INIT=1
         ram[i].wEnb.enq(wEnb && (fromInteger(i) == pack(wAddrLH)));
         ram[i].wAddr.enq({pack(wAddrH), pack(wAddrLL)});
         ram[i].wData.enq({1'b1, wPatt});
         ram[i].rAddr.enq(pack(wAddrH));
      end
      wAddrL_fifo.enq(pack(wAddrL));
      wAddrLOH_fifo.enq(wAddrLOH);
      wPatt2_fifo.enq(wPatt);
      if (verbose) $display("%x setram::input ", cycle, fshow(wEnb), fshow(wAddr), fshow(wPatt));
   endrule

   //FIXME: there may be a bug with oldPattInc computation
   rule setram_readdata;
      let wAddrL <- toGet(wAddrL_fifo).get;
      let wAddrLOH <- toGet(wAddrLOH_fifo).get;
      let wPatt <- toGet(wPatt2_fifo).get;
      Vector#(8, RPatt) data = newVector;
      for (Integer i=0; i<8; i=i+1) begin
         let v <- toGet(ram[i].rData).get;
         data[i] = unpack(v);
      end
      Bit#(3) wAddrL_ram = wAddrL[4:2];
      Bit#(2) wAddrL_word = wAddrL[1:0];
      Bool oldPattV = isValid(data[wAddrL_ram].rpatt[wAddrL_word]);
      Bit#(9) oldPatt = fromMaybe(?, data[wAddrL_ram].rpatt[wAddrL_word]);

      if (verbose) $display("%x setram::readdata wAddrLOH %x", cycle, wAddrLOH);
      Vector#(32, Bool) oldPattInc;
      for (Integer i=0; i<8; i=i+1) begin
         for (Integer j=0; j<4; j=j+1) begin
            // FIXME: LOH
            oldPattInc[i*4+j] = (fromMaybe(?, data[i].rpatt[j]) == oldPatt) &&
                                !(wAddrLOH[i*4+j]) &&
                                (isValid(data[i].rpatt[j]));
         end
      end
      rpatt_fifo.enq(data);
      oldPattIndc_fifo.enq(pack(oldPattInc));
      Bit#(1) oldPattMultiOcc = |(pack(oldPattInc));
      oldPattMultiOcc_fifo.enq(unpack(oldPattMultiOcc));

      Vector#(32, Bool) newPattIndc_prv;
      for (Integer i=0; i<8; i=i+1) begin
         for (Integer j=0; j<4; j=j+1) begin
            newPattIndc_prv[i*4+j] = (fromMaybe(?, data[i].rpatt[j]) == wPatt) && isValid(data[i].rpatt[j]);
         end
      end
      Bit#(32) newPattIndc = pack(newPattIndc_prv) | pack(wAddrLOH);
      newPattIndc_fifo.enq(newPattIndc);

      if (verbose) $display("%x setram::readdata ", cycle, fshow(pack(oldPattInc)), fshow(oldPattV));
   endrule

   PrioEnc#(32) pe_multiOcc <- mkPE32();

   interface PipeIn wEnb = toPipeIn(wEnb_fifo);
   interface PipeIn wPatt = toPipeIn(wPatt_fifo);
   interface PipeIn wAddr = toPipeIn(wAddr_fifo);
   interface PipeOut oldPatt = toPipeOut(oldPatt_fifo);
   interface PipeOut oldPattV = toPipeOut(oldPattV_fifo);
   interface PipeOut oldPattMultiOcc = toPipeOut(oldPattMultiOcc_fifo);
   interface PipeOut newPattMultiOcc = toPipeOut(newPattMultiOcc_fifo);
   interface PipeOut newPattOccFLoc = toPipeOut(newPattOccFLoc_fifo);
   interface PipeOut oldPattIndc = toPipeOut(oldPattIndc_fifo);
   interface PipeOut newPattIndc = toPipeOut(newPattIndc_fifo);
endmodule

interface Idxram#(numeric type cdep);
   interface PipeIn#(Bool) wEnb;
   interface PipeIn#(Bit#(TAdd#(TLog#(cdep), 10))) wAddr;
   interface PipeIn#(Bit#(5)) vacFLoc;
   interface PipeIn#(Bit#(5)) newPattOccFLoc;
   interface PipeOut#(Bit#(5)) oldIdx;
   interface PipeOut#(Bit#(5)) newIdx;
endinterface
module mkIdxram(Idxram#(cdep))
   provisos(Add#(TLog#(cdep), 10, TAdd#(TLog#(cdep), 10)),
            Add#(TAdd#(TLog#(cdep), 10), 0, camDepth),
            Add#(TAdd#(TLog#(cdep), 5), 0, wAddrHWidth),
            Log#(cdep, 0));

   FIFOF#(Bool) wEnb_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(camDepth)) wAddr_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(5)) vacFLoc_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(5)) newPattOccFLoc_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(5)) oldIdx_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(5)) newIdx_fifo <- mkBypassFIFOF();

   // WWID=5, RWID=40, WDEP=CDEP*1024/4, OREG=0, INIT=1
   Vector#(4, M20k#(5, 40, 256)) ram <- replicateM(mkM20k());

   FIFOF#(Bit#(5)) wAddrL_fifo <- mkFIFOF();
   FIFOF#(Bit#(160)) data_oldPatt_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(160)) data_newPatt_fifo <- mkBypassFIFOF();

   rule idxram_input;
      let v <- toGet(wEnb_fifo).get;
      let wAddr <- toGet(wAddr_fifo).get;
      let wData <- toGet(vacFLoc_fifo).get;
      Vector#(2, Bit#(1)) wAddrLH = takeAt(3, unpack(wAddr));
      Vector#(3, Bit#(1)) wAddrLL = take(unpack(wAddr));
      Vector#(5, Bit#(1)) wAddrL = take(unpack(wAddr));
      Vector#(wAddrHWidth, Bit#(1)) wAddrH = takeAt(5, unpack(wAddr));

      for (Integer i=0; i<4; i=i+1) begin
         ram[i].wEnb.enq(v && (fromInteger(i) == pack(wAddrLH)));
         ram[i].wAddr.enq({pack(wAddrH), pack(wAddrLL)});
         ram[i].wData.enq(wData);
         ram[i].rAddr.enq(pack(wAddrH));
      end
      wAddrL_fifo.enq(pack(wAddrL));
   endrule

   rule idxram_readdata;
      Vector#(4, Bit#(40)) data = newVector;
      for (Integer i=0; i<4; i=i+1) begin
         let v <- toGet(ram[i].rData).get;
         data[i] = v;
      end
      Bit#(160) data_pack = pack(data);
      data_oldPatt_fifo.enq(data_pack);
      data_newPatt_fifo.enq(data_pack);
   endrule

   rule oldPatt_indx;
      let wAddrL <- toGet(wAddrL_fifo).get;
      let data <- toGet(data_oldPatt_fifo).get;
      Bit#(5) oldIdx = data[wAddrL*5+5 : wAddrL*5];
      oldIdx_fifo.enq(oldIdx);
   endrule

   rule newPattOccFloc_idx;
      let data <- toGet(data_newPatt_fifo).get;
      let newPattOccFLoc <- toGet(newPattOccFLoc_fifo).get;
      Bit#(5) newIdx = data[newPattOccFLoc*5 + 5: newPattOccFLoc*5];
      newIdx_fifo.enq(newIdx);
   endrule

   interface PipeIn wEnb = toPipeIn(wEnb_fifo);
   interface PipeIn wAddr = toPipeIn(wAddr_fifo);
   interface PipeIn vacFLoc = toPipeIn(vacFLoc_fifo);
   interface PipeIn newPattOccFLoc = toPipeIn(newPattOccFLoc_fifo);
   interface PipeOut oldIdx = toPipeOut(oldIdx_fifo);
   interface PipeOut newIdx = toPipeOut(newIdx_fifo);
endmodule

interface Vacram#(numeric type cdep);
   interface PipeIn#(Bool) wEnb;
   interface PipeIn#(Bit#(TAdd#(TLog#(cdep), 10))) wAddr;
   interface PipeIn#(Bool) oldPattV;
   interface PipeIn#(Bool) oldPattMultiOcc;
   interface PipeIn#(Bool) newPattMultiOcc;
   interface PipeIn#(Bit#(5)) oldIdx;
   interface PipeOut#(Bit#(5)) vacFLoc;
endinterface
module mkVacram(Vacram#(cdep))
   provisos(Add#(TLog#(cdep), 10, TAdd#(TLog#(cdep), 10)),
            Add#(TAdd#(TLog#(cdep), 10), 0, camDepth),
            Add#(TAdd#(TLog#(cdep), 5), 0, wAddrHWidth),
            Bits#(Vector::Vector#(TAdd#(TLog#(cdep), 5), Bit#(1)), 5),
            Log#(cdep, 0));

   FIFOF#(Bool) wEnb_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(camDepth)) wAddr_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) oldPattV_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) oldPattMultiOcc_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) newPattMultiOcc_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(5)) oldIdx_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(5)) vacFLoc_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(5)) t_vacFLoc_fifo <- mkBypassFIFOF();

   FIFOF#(Bit#(32)) wVac_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(32)) cVac_fifo <- mkBypassFIFOF();

   // WWID=32, RWID=32, WDEP=CDEP*1024/32, OREG=0, INIT=1
   M20k#(32, 32, 32) ram <- mkM20k();
   mkConnection(toPipeOut(wEnb_fifo), ram.wEnb);
   mkConnection(toPipeOut(wVac_fifo), ram.wData);

   rule ram_input;
      let v <- toGet(wAddr_fifo).get;
      Vector#(wAddrHWidth, Bit#(1)) wAddrH = takeAt(5, unpack(v));
      ram.wAddr.enq(pack(wAddrH));
      ram.rAddr.enq(pack(wAddrH));
   endrule

   PrioEnc#(32) pe_vac <- mkPE32();
   mkConnection(toPipeOut(cVac_fifo), pe_vac.oht);

   rule pe_vac_out;
      let v <- toGet(pe_vac.pe).get;
      vacFLoc_fifo.enq(v.bin);
      t_vacFLoc_fifo.enq(v.bin);
   endrule

   rule mask_logic_cvac;
      let rVac <- toGet(ram.rData).get;
      let oldPattMultiOcc <- toGet(oldPattMultiOcc_fifo).get;
      let oldPattV <- toGet(oldPattV_fifo).get;
      let oldIdx <- toGet(oldIdx_fifo).get;
      let newPattMultiOcc <- toGet(newPattMultiOcc_fifo).get;
      let vacFLoc <- toGet(t_vacFLoc_fifo).get;

      OInt#(32) oldIdxOH = toOInt(oldIdx);
      Bool oldVac = !oldPattMultiOcc && oldPattV;
      Vector#(32, Bit#(1)) maskOldVac = replicate(pack(oldVac));
      Bit#(32) cVac = (~rVac) | (pack(oldIdxOH) & pack(maskOldVac));

      OInt#(32) vacFLocOH = toOInt(vacFLoc);
      Vector#(32, Bit#(1)) maskNewVac = replicate(pack(newPattMultiOcc));
      Bit#(32) wVac = ~(cVac & ((~pack(vacFLocOH)) | pack(maskNewVac)));

      cVac_fifo.enq(cVac);
      wVac_fifo.enq(wVac);
   endrule

   interface PipeIn wEnb = toPipeIn(wEnb_fifo);
   interface PipeIn wAddr = toPipeIn(wAddr_fifo);
   interface PipeIn oldPattV = toPipeIn(oldPattV_fifo);
   interface PipeIn oldPattMultiOcc = toPipeIn(oldPattMultiOcc_fifo);
   interface PipeIn newPattMultiOcc = toPipeIn(newPattMultiOcc_fifo);
   interface PipeIn oldIdx = toPipeIn(oldIdx_fifo);
   interface PipeOut vacFLoc = toPipeOut(vacFLoc_fifo);
endmodule

interface Bcam9b#(numeric type cdep);
   interface PipeIn#(Bool) wEnb;
   interface PipeIn#(Bit#(TAdd#(TLog#(cdep), 10))) wAddr;
   interface PipeIn#(Bit#(9)) mPatt;
   interface PipeIn#(Bit#(9)) wPatt;
   interface PipeOut#(Bit#(TMul#(cdep, 1024))) mIndc;
endinterface
module mkBcam9b(Bcam9b#(cdep))
   provisos(Add#(TLog#(cdep), 10, TAdd#(10, TLog#(cdep))),
            Add#(TAdd#(10, TLog#(cdep)), 0, camDepth),
            Add#(TAdd#(TLog#(cdep), 5), 0, indxWidth),
            Mul#(cdep, 1024, indcWidth),
            Log#(cdep, 0));

   let verbose = True;
   FIFOF#(Bool) wEnb_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(camDepth)) wAddr_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(9)) mPatt_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(9)) wPatt_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(indcWidth)) mIndc_fifo <- mkBypassFIFOF();

   FIFOF#(Bool) oldPattMultiOcc_fifo <- mkFIFOF();
   FIFOF#(Bool) newPattMultiOcc_fifo <- mkFIFOF();
   FIFOF#(Bit#(5)) oldIdx_fifo <- mkFIFOF();
   FIFOF#(Bit#(5)) newIdx_fifo <- mkFIFOF();
   FIFOF#(Bit#(5)) vacFLoc_fifo <- mkFIFOF();
   FIFOF#(Bit#(5)) t_oldIdx_fifo <- mkFIFOF();
   FIFOF#(Bit#(5)) t_newIdx_fifo <- mkFIFOF();
   FIFOF#(Bool) oldNewbPattWr_fifo <- mkFIFOF();
   FIFOF#(Bit#(5)) wIndx_fifo <- mkFIFOF();
   FIFOF#(Bit#(32)) oldPattIndc_fifo <- mkFIFOF();
   FIFOF#(Bit#(32)) newPattIndc_fifo <- mkFIFOF();
   FIFOF#(Bool) oldPattV_fifo <- mkFIFOF();

   FIFOF#(Bit#(9)) t_wPatt_fifo <- mkBypassFIFOF();
   Reg#(Bool) running <- mkReg(False);

   Reg#(Bit#(32)) cycle <- mkReg(0);
   rule every1;
      cycle <= cycle + 1;
   endrule

   Bcam_ram9b#(cdep) ram9b <- mkBcam_ram9b();
   Setram#(cdep) setram <- mkSetram();
   Idxram#(cdep) idxram <- mkIdxram();
   Vacram#(cdep) vacram <- mkVacram();

   // Cam Ctrl
   Stmt camctrl =
   seq
   noAction;
   action
   $display("stmt %x", cycle);
   endaction
   action
   setram.wEnb.enq(True);
   $display("stmt %x", cycle);
   endaction
   endseq;

   FSM fsm <- mkFSM(camctrl);

   rule start (!running);
      let v <- toGet(wEnb_fifo).get;
      running <= True;
      fsm.start;
      $display("cam9b::fsm %x start", cycle);
   endrule

//   mkConnection(toPipeOut(wEnb_fifo), cc.wEnb);
//   mkConnection(cc.wEnb_iVld, ram9b.wEnb_iVld);
//   mkConnection(cc.wEnb_indx, ram9b.wEnb_indx);
//   mkConnection(cc.wEnb_indc, ram9b.wEnb_indc);
//   mkConnection(cc.wEnb_setram, setram.wEnb);
//   mkConnection(cc.wEnb_idxram, idxram.wEnb);
//   mkConnection(cc.wEnb_vacram, vacram.wEnb);
//   mkConnection(cc.wIVld, ram9b.wIVld);
//
//   mkConnection(toPipeOut(mPatt_fifo), ram9b.mPatt);
//
//   mkConnection(setram.newPattOccFLoc, idxram.newPattOccFLoc);
//
//
   rule cam_wPatt;
      let wPatt <- toGet(wPatt_fifo).get;
      if(verbose) $display("cam9b::wPatt ", fshow(wPatt));
      setram.wPatt.enq(wPatt);
      t_wPatt_fifo.enq(wPatt);
   endrule
//
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
   rule wAddr_to_all;
      let v <- toGet(wAddr_fifo).get;
      setram.wAddr.enq(v);
//      idxram.wAddr.enq(v);
//      vacram.wAddr.enq(v);
//      Vector#(indxWidth, Bit#(1)) indx_addr = takeAt(5, unpack(v));
//      ram9b.wAddr_indx.enq(pack(indx_addr));
      if(verbose) $display("cam9b::wAddr ", fshow(v));
   endrule
//
//   rule setram_oldPatt;
//      let v <- toGet(setram.oldPattV).get;
//      cc.oldPattV.enq(v);
//      vacram.oldPattV.enq(v);
//      if(verbose) $display("cam9b::setram_oldPatt ", fshow(v));
//   endrule
//
//   rule setram_oldPattMultiOcc;
//      let v <- toGet(setram.oldPattMultiOcc).get;
//      vacram.oldPattMultiOcc.enq(v);
//      cc.oldPattMultiOcc.enq(v);
//      oldPattMultiOcc_fifo.enq(v);
//      if(verbose) $display("cam9b::setram_oldPattMultiOcc ", fshow(v));
//   endrule
//
//   rule setram_newPattMultiOcc;
//      let v <- toGet(setram.newPattMultiOcc).get;
//      vacram.newPattMultiOcc.enq(v);
//      cc.newPattMultiOcc.enq(v);
//      newPattMultiOcc_fifo.enq(v);
//      if(verbose) $display("cam9b::setram_newPattMultiOcc ", fshow(v));
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
//   rule setram_oldPattIndc;
//      let v <- toGet(setram.oldPattIndc).get;
//      oldPattIndc_fifo.enq(v);
//      if(verbose) $display("cam9b::setram_oldPattIndc ", fshow(v));
//   endrule
//
//   rule setram_newPattIndc;
//      let v <- toGet(setram.newPattIndc).get;
//      newPattIndc_fifo.enq(v);
//      if(verbose) $display("cam9b::setram_newPattIndc ", fshow(v));
//   endrule
//
//   rule idxram_oldIdx;
//      let v <- toGet(idxram.oldIdx).get;
//      vacram.oldIdx.enq(v);
//      oldIdx_fifo.enq(v);
//      if(verbose) $display("cam9b::idxram_oldIdx ", fshow(v));
//   endrule
//
//   rule idxram_newIdx;
//      let v <- toGet(idxram.newIdx).get;
//      newIdx_fifo.enq(v);
//      if(verbose) $display("cam9b::idxram_newIdx ", fshow(v));
//   endrule
//
//   rule vacram_vacFLoc;
//      let v <- toGet(vacram.vacFLoc).get;
//      vacFLoc_fifo.enq(v);
//      if(verbose) $display("cam9b::vacram_vacFLoc ", fshow(v));
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

   interface PipeIn wEnb = toPipeIn(wEnb_fifo);
   interface PipeIn wPatt = toPipeIn(wPatt_fifo);
   interface PipeIn wAddr = toPipeIn(wAddr_fifo);
   interface PipeIn mPatt = toPipeIn(mPatt_fifo);
   interface PipeOut mIndc = toPipeOut(mIndc_fifo);
endmodule

interface Bcam#(numeric type cdep, numeric type pwid);
   interface PipeIn#(Bool) wEnb;
   interface PipeIn#(Bit#(TAdd#(TLog#(cdep), 10))) wAddr;
   interface PipeIn#(Bit#(TMul#(pwid, 9))) mPatt;
   interface PipeIn#(Bit#(TMul#(pwid, 9))) wPatt;
   interface PipeOut#(Bit#(TAdd#(TLog#(cdep), 10))) mAddr;
   interface PipeOut#(Bool) pMatch;
endinterface
module mkBcam_internal(Bcam#(cdep, pwid))
   provisos(Add#(TLog#(cdep), 10, TAdd#(TLog#(cdep), 10)),
            Add#(TAdd#(10, TLog#(cdep)), 0, camDepth),
            Mul#(pwid, 9, pattWidth),
            Mul#(cdep, 1024, indcWidth),
            Add#(indcWidth, 0, 1024)
            );
   let verbose = True;

   FIFOF#(Bool) wEnb_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(camDepth)) wAddr_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(pattWidth)) mPatt_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(pattWidth)) wPatt_fifo <- mkBypassFIFOF();
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

   PrioEnc#(1024) pe1024 <- mkPE1024();

   rule pe1024_out;
      let v <- toGet(pe1024.pe).get;
      mAddr_fifo.enq(v.bin);
      match_fifo.enq(unpack(v.vld));
   endrule

   interface PipeIn wEnb = toPipeIn(wEnb_fifo);
   interface PipeIn wPatt = toPipeIn(wPatt_fifo);
   interface PipeIn wAddr = toPipeIn(wAddr_fifo);
   interface PipeIn mPatt = toPipeIn(mPatt_fifo);
   interface PipeOut mAddr = toPipeOut(mAddr_fifo);
   interface PipeOut pMatch = toPipeOut(match_fifo);
endmodule

// CDEP = 1*1024, PWID = 1 = 9bits
(* synthesize *)
module mkBcam(Bcam#(1, 1));
   Bcam#(1, 1) _a <- mkBcam_internal(); return _a;
endmodule

