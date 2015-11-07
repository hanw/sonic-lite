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
//import Setram::*;
import PriorityEncoder::*;
import IdxVacRam::*;
import Ram9b::*;
import PriorityEncoderEfficient::*;

typedef struct {
   Vector#(4, Maybe#(Bit#(9))) rpatt;
} RPatt deriving (Bits, Eq);

typedef enum {S0, S1, S2} StateType
   deriving (Bits, Eq);

interface Bcam9b#(numeric type camDepth);
   interface Put#(BcamWriteReq#(TLog#(camDepth), 9)) writeServer;
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
            ,Add#(writeSz, 0, 10)
            ,Add#(dataSz, 1, writeSz)
            ,Add#(readSz, 0, 40)
            ,Div#(readSz, writeSz, ratio)
            ,Log#(ratio, ratioSz)
            ,Div#(camDepth, 8, writeDepth)
            ,Log#(writeDepth, writeDepthSz)
            ,Add#(readDepthSz, ratioSz, writeDepthSz)
            ,Add#(readDepthSz, 0, wAddrHWidth)
         );

   let verbose = True;
   let verbose_setram = verbose && True;
   let verbose_idxram = verbose && True;
   let verbose_vacram = verbose && True;

   Reg#(Bit#(32)) cycle <- mkReg(0);
   rule every1 if (verbose);
      cycle <= cycle + 1;
   endrule

   FIFOF#(Bit#(9)) mPatt_fifo <- mkFIFOF();
   FIFOF#(Bit#(9)) wPatt_fifo <- mkFIFOF();
   FIFOF#(Bit#(indcWidth)) mIndc_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) oldNewbPattWr_fifo <- mkFIFOF();

   Reg#(Bit#(9)) oldPattR <- mkReg(0);
   Reg#(Bool) oldPattVR <- mkReg(False);
   Reg#(Bool) oldPattMultiOccR <- mkReg(False);
   Wire#(Bool) newPattMultiOccR <- mkDWire(False);

   Ram9b#(cdep) ram9b <- mkRam9b();
   IdxVacram#(camDepth) ivram <- mkIdxVacram();

   // SetRAM implementation
   //Setram#(camDepth) setram <- mkSetram();

   // setram fifo, remove later.
   FIFO#(Bool) oldPattMultiOcc_fifo <- mkFIFO1();
   FIFO#(Bool) newPattMultiOcc_fifo <- mkFIFO1();
   FIFO#(Bit#(5)) newPattOccFLoc_fifo <- mkFIFO1();
   FIFO#(Bit#(32)) oldPattIndc_fifo <- mkFIFO1();
   FIFO#(Bit#(32)) newPattIndc_fifo <- mkFIFO1();
   FIFO#(Bool) oldPattV_fifo <- mkFIFO1;
   FIFO#(Bit#(9)) oldPatt_fifo <- mkFIFO1;

   Reg#(Bit#(9)) wPatt_setram <- mkReg(0);
   Reg#(Bit#(camSz)) wAddr_setram <- mkReg(0);
   FIFO#(void) setram_write <- mkFIFO1;
   FIFO#(void) setram_read <- mkFIFO1;

   Reg#(Bool) oldPattMultiOcc_reg <- mkReg(False);
   Reg#(Bit#(32)) oldPattIndc_reg <- mkReg(0);
   Reg#(Bit#(32)) newPattIndc_reg <- mkReg(0);
   Reg#(Bit#(5)) newPattOccFLoc_reg <- mkReg(0);
   Reg#(Bool) newPattMultiOcc_reg <- mkReg(False);
   PEnc32 pe_multiOcc <- mkPriorityEncoder32();

   `define SETRAM AsymmetricBRAM#(Bit#(readDepthSz), Bit#(readSz), Bit#(writeDepthSz), Bit#(writeSz))
   Vector#(8, `SETRAM) setRam <- replicateM(mkAsymmetricBRAM(True, False, "Setram"));


   FIFOF#(Bool) oldEqNewPatt_fifo <- mkFIFOF;
   Vector#(2, PipeOut#(Bool)) oldEqNewPattPipes <- mkForkVector(toPipeOut(oldEqNewPatt_fifo));

   // FIXME: nothing here, shouldn't take a cycle.
   rule generate_oldEqNewPatt;
      let wPatt <- toGet(wPatt_fifo).get;
      let oldPatt <- toGet(oldPatt_fifo).get;
      Bool oldEqNewPatt = (wPatt == oldPatt);
      if (verbose) $display("bcam %d: oldEqNewPatt=%x, wPatt=%x, oldPatt=%x", cycle, oldEqNewPatt, wPatt, oldPatt);
      oldPattR <= oldPatt;
      oldEqNewPatt_fifo.enq(oldEqNewPatt);
      if (verbose) $display("bcam %d: oldPatt=%x", cycle, oldPatt);
   endrule

   rule update_oldPattV;
      //let oldPattV <- toGet(setram.oldPattV).get;
      let oldPattV <- toGet(oldPattV_fifo).get;
      oldPattVR <= oldPattV;
      ivram.oldPattV.enq(oldPattV);
      if (verbose) $display("bcam %d: oldPattV=%x", cycle, oldPattV);
   endrule

   rule update_oldMultiOcc;
      //let oldPattMultiOcc <- toGet(setram.oldPattMultiOcc).get;
      let oldPattMultiOcc <- toGet(oldPattMultiOcc_fifo).get;
      ivram.oldPattMultiOcc.enq(oldPattMultiOcc);
      oldPattMultiOccR <= oldPattMultiOcc;
      if (verbose) $display("bcam %d: oldMultiOcc=%x", cycle, oldPattMultiOcc);
   endrule

   // FIXME: remove
   rule update_newMultiOcc;
      //let newPattMultiOcc <- toGet(setram.newPattMultiOcc).get;
      let newPattMultiOcc <- toGet(newPattMultiOcc_fifo).get;
      ivram.newPattMultiOcc.enq(newPattMultiOcc);
      //newPattMultiOccR <= newPattMultiOcc;
      if (verbose) $display("bcam %d: newMultiOcc=%x", cycle, newPattMultiOcc);
   endrule

   // Cam Control
   Reg#(StateType) curr_state <- mkReg(S0);
   (* fire_when_enabled *)
   rule state_S0 (curr_state == S0);
      let oldEqNewPatt <- toGet(oldEqNewPattPipes[0]).get;
      Bool wEnb_indc = !(oldEqNewPatt && oldPattVR) && oldPattVR && oldPattMultiOcc_reg;
      Bool wEnb_iVld = !(oldEqNewPatt && oldPattVR) && oldPattVR && !oldPattMultiOcc_reg;
      ivram.oldNewbPattWr.enq(oldPattVR);
      oldNewbPattWr_fifo.enq(oldPattVR); // FIXME: no need??
      curr_state <= S1;
      if (verbose) $display("camctrl %d: oldPatt=%x, oldPattV=%x, oldMultiOcc=%x, newMultiOcc=%x", cycle, oldPattR, oldPattVR, oldPattMultiOcc_reg, newPattMultiOcc_reg);
      if (verbose) $display("camctrl %d: Genereate wEnb_indc=%x and wEnb_iVld=%x", cycle, wEnb_indc, wEnb_iVld);
   endrule

   (* fire_when_enabled *)
   rule state_S1 (curr_state == S1);
      let oldEqNewPatt <- toGet(oldEqNewPattPipes[1]).get;
      Bool wEnb_setram = !(oldEqNewPatt && oldPattVR);
      Bool wEnb_idxram = !(oldEqNewPatt && oldPattVR);
      Bool wEnb_vacram = !(oldEqNewPatt && oldPattVR) && (oldPattVR && !oldPattMultiOcc_reg) || !newPattMultiOcc_reg;
      Bool wEnb_indc = !(oldEqNewPatt && oldPattVR);
      Bool wEnb_indx = !(oldEqNewPatt && oldPattVR) && !newPattMultiOcc_reg;
      Bool wEnb_iVld = !(oldEqNewPatt && oldPattVR) && !newPattMultiOcc_reg;
      if (verbose) $display("camctrl %d: wEnb_setram=%x, wEnb_idxram=%x, wEnb_vacram=%x, wEnb_indx=%x, wEnb_indc=%x", cycle, wEnb_setram, wEnb_idxram, wEnb_vacram, wEnb_indx, wEnb_indc);

//      setram.wEnb_setram.enq(wEnb_setram);
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
      //let newPattOccFLoc <- toGet(setram.newPattOccFLoc).get;
      let newPattOccFLoc <- toGet(newPattOccFLoc_fifo).get;
      ivram.newPattOccFLoc.enq(newPattOccFLoc);
   endrule

   rule wIndc_to_all;
      //let oldPattIndc <- toGet(setram.oldPattIndc).get;
      //let newPattIndc <- toGet(setram.newPattIndc).get;
      let oldPattIndc <- toGet(oldPattIndc_fifo).get;
      let newPattIndc <- toGet(newPattIndc_fifo).get;
      let oldNewbPattWr <- toGet(oldNewbPattWr_fifo).get;
      Bit#(32) wIndc = oldNewbPattWr ? oldPattIndc : newPattIndc;
      if(verbose) $display("cam9b %d: oldPattIndc=%x, newPattIndc=%x", cycle, oldPattIndc, newPattIndc);
      if(verbose) $display("cam9b %d: oldNewbPattwr=%x, wIndc=", cycle, oldNewbPattWr, fshow(wIndc));
      ram9b.wIndc.enq(wIndc);
   endrule

   rule wIndx_to_ram;
      let v <- toGet(ivram.wIndx).get;
      ram9b.wIndx.enq(v);
      ram9b.wAddr_indc.enq(v);
      $display("****ram9b, waddr_indc=%x", v);
   endrule

   rule read_mPatt;
      let v <- toGet(mPatt_fifo).get;
      ram9b.mPatt.enq(v);
   endrule

   rule write_mIndc;
      let v <- toGet(ram9b.mIndc).get;
      mIndc_fifo.enq(v);
   endrule

   rule setram_read_request;
      let v <- toGet(setram_read).get;
      Vector#(wAddrHWidth, Bit#(1)) wAddrH = takeAt(5, unpack(wAddr_setram));
      if (verbose) $display("setram %d: setram read Addr=%x", cycle, pack(wAddrH));
      for (Integer i=0; i<8; i=i+1) begin
         setRam[i].readServer.request.put(pack(wAddrH));
      end
   endrule

   rule setram_write_request;
      let v <- toGet(setram_write).get;
      Vector#(3, Bit#(1)) wAddrLH = takeAt(2, unpack(wAddr_setram));
      Vector#(2, Bit#(1)) wAddrLL = take(unpack(wAddr_setram));
      Vector#(wAddrHWidth, Bit#(1)) wAddrH = takeAt(5, unpack(wAddr_setram));
      Bit#(writeDepthSz) writeAddr = {pack(wAddrH), pack(wAddrLL)};
      Maybe#(Bit#(dataSz)) writeData = tagged Valid wPatt_setram;
      if (verbose) $display("setram %d: writeReq wAddr=%x, wData=%x", cycle, wAddr_setram, wPatt_setram);
      for (Integer i=0; i<8; i=i+1) begin
         if (fromInteger(i) == pack(wAddrLH)) begin
            setRam[i].writeServer.put(tuple2(writeAddr, pack(writeData)));
         end
      end
      if (verbose) $display("Setram: %d write to setram addr=%x, data=%x", cycle, wAddr_setram, wPatt_setram);
   endrule

   // Compute Setram Outputs
   // Cycle 2.
   rule setram_read_response;
      Vector#(5, Bit#(1)) wAddrL = take(unpack(wAddr_setram));
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
            oldPattIndc[i*4+j] = (rPatt == oldPatt) && rPattV; //&& !unpack(indx[i*4+j]) && rPattV;
            $display("%d: rPatt=%x, oldPatt=%x, wAddrLOH=%x, rPattV=%d oldPattIndc=%d", cycle, rPatt, oldPatt, wAddrLOH, rPattV, oldPattIndc[i*4+j]);
         end
      end

      oldPattV_fifo.enq(oldPattV);
      oldPatt_fifo.enq(oldPatt);

      // detect if old pattern has multi-occurence in segment
      Bool oldPattMultiOcc = (pack(oldPattIndc) != 0);
      oldPattMultiOcc_fifo.enq(oldPattMultiOcc);
      oldPattMultiOcc_reg <= oldPattMultiOcc;
      if (verbose) $display("setram %d: oldPattMultiOcc=%x", cycle, oldPattMultiOcc);
      oldPattIndc_fifo.enq(pack(oldPattIndc));
      oldPattIndc_reg <= pack(oldPattIndc);
      if (verbose) $display("setram %d: oldPattIndc=%x", cycle, pack(oldPattIndc));

      // compute new pattern
      Vector#(32, Bool) newPattIndc_prv;
      for (Integer i=0; i<8; i=i+1) begin
         for (Integer j=0; j<4; j=j+1) begin
            Bit#(9) rPatt = fromMaybe(?, data[i].rpatt[j]);
            Bool rPattV = isValid(data[i].rpatt[j]);
            newPattIndc_prv[i*4+j] = (rPatt == wPatt_setram) && rPattV;
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
      newPattMultiOcc_fifo.enq(vld);
      newPattMultiOcc_reg <= vld;
      if (verbose) $display("setram %d: bin=%x, vld=%x", cycle, bin, vld);
      if (verbose) $display("setram %d: newPattMultiOcc=%x, newPattOccFLoc=%x", cycle, vld, bin);
   endrule

   interface Put writeServer;
      // Cycle 0.
      method Action put(BcamWriteReq#(camSz, 9) req);
         Bit#(camSz) wAddr = req.addr;
         Bit#(9) wData = req.data;
         Vector#(wAddrHWidth, Bit#(1)) wAddrH = takeAt(5, unpack(wAddr));
         //setram.writeServer.put(tuple2(wAddr, wData));

         // setRam control
         wAddr_setram <= wAddr;
         wPatt_setram <= wData;
         setram_write.enq(?);
         setram_read.enq(?);

         // idxram control
         ivram.wAddr.put(wAddr);
         wPatt_fifo.enq(wData);

         // ram9b control
         ram9b.wAddr_indx.enq(pack(wAddrH));
         ram9b.wPatt.enq(wData);
      endmethod
   endinterface

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
            ,PriorityEncoder#(indcWidth) //??
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
         BcamWriteReq#(camSz, 9) req = BcamWriteReq{addr: wAddr, data: pack(data)};
         //cam9b[i].writeServer.put(tuple2(wAddr, pack(data)));
         cam9b[i].writeServer.put(req);
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

// Generated by compiler
(* synthesize *)
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


