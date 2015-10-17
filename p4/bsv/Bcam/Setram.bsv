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

interface Setram#(numeric type camDepth);
   interface Put#(Tuple2#(Bit#(TLog#(camDepth)), Bit#(9))) writeServer;
   interface PipeIn#(Bool) wEnb_setram;
   interface PipeOut#(Bit#(9)) oldPatt;
   interface PipeOut#(Bool) oldPattV;
   interface PipeOut#(Bool) oldPattMultiOcc;
   interface PipeOut#(Bool) newPattMultiOcc;
   interface PipeOut#(Bit#(5)) newPattOccFLoc;
   interface PipeOut#(Bit#(32)) oldPattIndc;
   interface PipeOut#(Bit#(32)) newPattIndc;
endinterface
module mkSetram(Setram#(camDepth))
   provisos(Add#(cdep, 9, camSz)
            ,Log#(camDepth, camSz)
            ,Add#(writeSz, 0, 10)
            ,Add#(dataSz, 1, writeSz)
            ,Add#(readSz, 0, 40)
            ,Div#(readSz, writeSz, ratio)
            ,Log#(ratio, ratioSz)
            ,Div#(camDepth, 8, writeDepth)
            ,Add#(a__, 2, TLog#(TDiv#(camDepth, 8)))
            ,Add#(5, b__, camSz)
            ,Add#(2, d__, camSz)
            ,Add#(3, e__, camSz)
            ,Add#(TLog#(cdep), 5, wAddrHWidth)
            ,Add#(wAddrHWidth, c__, camSz)
            ,Log#(writeDepth, writeDepthSz)
            ,Add#(readDepthSz, ratioSz, writeDepthSz)
            ,Add#(readDepthSz, 0, wAddrHWidth)
         );
   let verbose = True;

   Reg#(Bit#(32)) cycle <- mkReg(0);
   rule every1;
      cycle <= cycle + 1;
   endrule

   FIFOF#(Tuple2#(Bit#(camSz), Bit#(9))) writeReqFifo <- mkBypassFIFOF;
   FIFOF#(Bool) wEnb_setram_fifo <- mkBypassFIFOF;
   FIFOF#(Bit#(9)) oldPatt_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) oldPattV_fifo<- mkBypassFIFOF();
   FIFOF#(Bool) oldPattMultiOcc_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) newPattMultiOcc_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(5)) newPattOccFLoc_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(32)) oldPattIndc_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(32)) newPattIndc_fifo <- mkBypassFIFOF();
   FIFOF#(Vector#(8, RPatt)) rpatt_fifo <- mkBypassFIFOF();

`define SETRAM AsymmetricBRAM#(Bit#(readDepthSz), Bit#(readSz), Bit#(writeDepthSz), Bit#(writeSz))

   Vector#(8, `SETRAM) setRam <- replicateM(mkAsymmetricBRAM(False, False, "Setram"));

   Vector#(3, PipeOut#(Tuple2#(Bit#(camSz), Bit#(9)))) writeRequestPipes <- mkForkVector(toPipeOut(writeReqFifo));

   PEnc32 pe_multiOcc <- mkPriorityEncoder32();

   rule setram_input;
      let v <- toGet(writeRequestPipes[0]).get;
      let wEnb <- toGet(wEnb_setram_fifo).get;
      let wAddr = tpl_1(v);
      let wPatt = tpl_2(v);
      if (verbose) $display("setram %d: writeReq wAddr=%x, wPatt=%x", cycle, wAddr, wPatt);
      Vector#(3, Bit#(1)) wAddrLH = takeAt(2, unpack(wAddr));
      Vector#(2, Bit#(1)) wAddrLL = take(unpack(wAddr));
      Vector#(wAddrHWidth, Bit#(1)) wAddrH = takeAt(5, unpack(wAddr));
      Vector#(5, Bit#(1)) wAddrL = take(unpack(wAddr));
      OInt#(32) wAddrLOH = toOInt(pack(wAddrL));

      Bit#(writeDepthSz) writeAddr = {pack(wAddrH), pack(wAddrLL)};
      Maybe#(Bit#(dataSz)) writeData = tagged Valid wPatt;
      if (verbose) $display("setram %d: toRam writeAddr=%x, writeData=%x", cycle, writeAddr, writeData);
      for (Integer i=0; i<8; i=i+1) begin
         if (fromInteger(i) == pack(wAddrLH)) begin
            setRam[i].writeServer.put(tuple2(writeAddr, pack(writeData)));
         end
      end
   endrule

   rule setram_read_request;
      let v <- toGet(writeRequestPipes[1]).get;
      let wAddr = tpl_1(v);
      Vector#(wAddrHWidth, Bit#(1)) wAddrH = takeAt(5, unpack(wAddr));
      if (verbose) $display("setram %d: setram read Addr=%x", cycle, pack(wAddrH));
      for (Integer i=0; i<8; i=i+1) begin
         setRam[i].readServer.request.put(pack(wAddrH));
      end
   endrule

   rule setram_read_response;
      let v <- toGet(writeRequestPipes[2]).get;
      let wAddr = tpl_1(v);
      let wPatt = tpl_2(v);
      Vector#(5, Bit#(1)) wAddrL = take(unpack(wAddr));
      OInt#(32) wAddrLOH = toOInt(pack(wAddrL));
      Vector#(8, RPatt) data = newVector;
      for (Integer i=0; i<8; i=i+1) begin
         let setram_data <- setRam[i].readServer.response.get;
         Vector#(4, Maybe#(Bit#(9))) m = unpack(setram_data);
         data[i] = unpack(setram_data);
      end
      Bit#(3) wAddrL_ram = pack(wAddrL)[4:2];
      Bit#(2) wAddrL_word = pack(wAddrL)[1:0];
      Bool oldPattV = isValid(data[wAddrL_ram].rpatt[wAddrL_word]);
      Bit#(9) oldPatt = fromMaybe(?, data[wAddrL_ram].rpatt[wAddrL_word]);
      if(verbose) $display("setram %d: lastWritten oldPatt=%x oldPattV=%d", cycle, oldPatt, oldPattV);

      Vector#(32, Bool) oldPattIndc;
      for (Integer i=0; i<8; i=i+1) begin
         for (Integer j=0; j<4; j=j+1) begin
            Bit#(9) rPatt = fromMaybe(?, data[i].rpatt[j]);
            Bool rPattV = isValid(data[i].rpatt[j]);
            Bit#(32) indx = pack(wAddrLOH);
            oldPattIndc[i*4+j] = (rPatt == oldPatt) && !unpack(indx[i*4+j]) && rPattV;
            //$display("%d: rPatt=%x, wAddrLOH=%x, rPattV=%d oldPattIndc=%d", cycle, rPatt, wAddrLOH, rPattV, oldPattIndc[i*4+j]);
         end
      end
      oldPattIndc_fifo.enq(pack(oldPattIndc));
      if (verbose) $display("setram %d: oldPattIndc=%x", cycle, pack(oldPattIndc));

      Vector#(32, Bool) newPattIndc_prv;
      for (Integer i=0; i<8; i=i+1) begin
         for (Integer j=0; j<4; j=j+1) begin
            Bit#(9) rPatt = fromMaybe(?, data[i].rpatt[j]);
            Bool rPattV = isValid(data[i].rpatt[j]);
            newPattIndc_prv[i*4+j] = (rPatt == wPatt) && rPattV;
            //$display("%d: rPatt=%x, rPattV=%d newPattIndc_prv=%d", cycle, fromMaybe(?, data[i].rpatt[j]), isValid(data[i].rpatt[j]), newPattIndc_prv[i*4+j]);
         end
      end

      pe_multiOcc.oht.put(pack(newPattIndc_prv));

      Bit#(32) newPattIndc = pack(newPattIndc_prv) | pack(wAddrLOH);
      newPattIndc_fifo.enq(newPattIndc);
      if (verbose) $display("setram %d: newPattIndc=%x", cycle, newPattIndc);

      // detect if old pattern has multi-occurence in segment
      Bool oldPattMultiOcc = (pack(oldPattIndc) != 0);
      oldPattMultiOcc_fifo.enq(oldPattMultiOcc);
      if (verbose) $display("setram %d: oldPattMultiOcc=%x", cycle, oldPattMultiOcc);

      oldPatt_fifo.enq(oldPatt);
      oldPattV_fifo.enq(oldPattV);
   endrule

   rule setram_encoder;
      let bin <- toGet(pe_multiOcc.bin).get;
      let vld <- toGet(pe_multiOcc.vld).get;
      newPattOccFLoc_fifo.enq(bin);
      newPattMultiOcc_fifo.enq(vld);
      if (verbose) $display("setram %d: bin=%x, vld=%x", cycle, bin, vld);
      if (verbose) $display("setram %d: newPattMultiOcc=%x, newPattOccFLoc=%x", cycle, vld, bin);
   endrule

   interface Put writeServer = toPut(writeReqFifo);
   interface PipeIn wEnb_setram = toPipeIn(wEnb_setram_fifo);
   interface PipeOut oldPatt = toPipeOut(oldPatt_fifo);
   interface PipeOut oldPattV = toPipeOut(oldPattV_fifo);
   interface PipeOut oldPattMultiOcc = toPipeOut(oldPattMultiOcc_fifo);
   interface PipeOut newPattMultiOcc = toPipeOut(newPattMultiOcc_fifo);
   interface PipeOut newPattOccFLoc = toPipeOut(newPattOccFLoc_fifo);
   interface PipeOut oldPattIndc = toPipeOut(oldPattIndc_fifo);
   interface PipeOut newPattIndc = toPipeOut(newPattIndc_fifo);
endmodule

