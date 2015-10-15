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

interface Idxram#(numeric type camDepth);
   interface Put#(Bit#(TLog#(camDepth))) wAddr;
   interface PipeIn#(Bit#(5)) vacFLoc;
   interface PipeIn#(Bit#(5)) newPattOccFLoc;
   interface PipeOut#(Bit#(5)) oldIdx;
   interface PipeOut#(Bit#(5)) newIdx;
endinterface
module mkIdxram(Idxram#(camDepth))
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
         );
   let verbose = True;
   Reg#(Bit#(32)) cycle <- mkReg(0);
   rule every1;
      cycle <= cycle + 1;
   endrule

   FIFOF#(Bit#(camSz)) writeReqFifo <- mkFIFOF;
   FIFOF#(Bit#(5)) vacFLoc_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(5)) newPattOccFLoc_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(5)) oldIdx_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(5)) newIdx_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(5)) wAddrL_fifo <- mkFIFOF();
   FIFOF#(Bit#(160)) data_oldPatt_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(160)) data_newPatt_fifo <- mkBypassFIFOF();

`define IDXRAM AsymmetricBRAM#(Bit#(readDepthSz), Bit#(readSz), Bit#(writeDepthSz), Bit#(writeSz))
   Vector#(4, `IDXRAM) idxRam <- replicateM(mkAsymmetricBRAM(False, False));

   Vector#(2, PipeOut#(Bit#(camSz))) wAddrPipes <- mkForkVector(toPipeOut(writeReqFifo));

   rule idxram_write;
      let wAddr <- toGet(wAddrPipes[0]).get;
      let wData <- toGet(vacFLoc_fifo).get;
      Vector#(2, Bit#(1)) wAddrLH = takeAt(3, unpack(wAddr));
      Vector#(3, Bit#(1)) wAddrLL = take(unpack(wAddr));
      Vector#(wAddrHWidth, Bit#(1)) wAddrH = takeAt(5, unpack(wAddr));
      Bit#(writeDepthSz) writeAddr = {pack(wAddrH), pack(wAddrLL)};
      if (verbose) $display("%d: wAddrLH %x", cycle, pack(wAddrLH));
      if (verbose) $display("%d: wAddrLL %x", cycle, pack(wAddrLL));
      if (verbose) $display("%d: wAddrH %x", cycle, pack(wAddrH));
      for (Integer i=0; i<4; i=i+1) begin
         if (fromInteger(i) == pack(wAddrLH)) begin
            if (verbose) $display("idxram %d: write memory %x, addr=%x data=%x", cycle, i, writeAddr, pack(wData));
            idxRam[i].writeServer.put(tuple2(writeAddr, pack(wData)));
         end
      end
   //endrule

   //rule idxram_read;
      //let wAddr <- toGet(wAddrPipes[1]).get;
      Vector#(5, Bit#(1)) wAddrL = take(unpack(wAddr));
      //Vector#(wAddrHWidth, Bit#(1)) wAddrH = takeAt(5, unpack(wAddr));
      for (Integer i=0; i<4; i=i+1) begin
         idxRam[i].readServer.request.put(pack(wAddrH));
      end
      if (verbose) $display("idxram %d: wAddrL %x", cycle, pack(wAddrL));
      wAddrL_fifo.enq(pack(wAddrL));
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
      $display("idxram %d: readRam", cycle);
   endrule

   rule oldPatt_indx;
      let wAddrL <- toGet(wAddrL_fifo).get;
      let data <- toGet(data_oldPatt_fifo).get;
      Bit#(5) oldIdx = data[wAddrL*5+5 : wAddrL*5];
      oldIdx_fifo.enq(oldIdx);
      $display("idxram %d: oldIdx=%x", cycle, oldIdx);
   endrule

   rule newPattOccFloc_idx;
      let data <- toGet(data_newPatt_fifo).get;
      let newPattOccFLoc <- toGet(newPattOccFLoc_fifo).get;
      Bit#(5) newIdx = data[newPattOccFLoc*5 + 5: newPattOccFLoc*5];
      newIdx_fifo.enq(newIdx);
      $display("idxram %d: newIdx=%x", cycle, newIdx);
   endrule

   interface Put wAddr = toPut(writeReqFifo);
   interface PipeIn vacFLoc = toPipeIn(vacFLoc_fifo);
   interface PipeIn newPattOccFLoc = toPipeIn(newPattOccFLoc_fifo);
   interface PipeOut oldIdx = toPipeOut(oldIdx_fifo);
   interface PipeOut newIdx = toPipeOut(newIdx_fifo);
endmodule

