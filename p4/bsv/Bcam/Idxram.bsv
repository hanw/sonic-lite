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
            Add#(TAdd#(TLog#(cdep), 5), 0, wAddrHWidth)
         );

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
            Add#(TAdd#(TLog#(cdep), 5), 0, wAddrHWidth)
         );

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


