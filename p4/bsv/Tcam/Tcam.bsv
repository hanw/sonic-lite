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
import TcamTypes::*;
import Ram9b::*;
import SetRam::*;
import BcamReg::*;
import BcamTypes::*;
import PriorityEncoder::*;

typedef struct {
   Vector#(4, Maybe#(Bit#(9))) rpatt;
} RPatt deriving (Bits, Eq);

typedef enum {S0, S1, S2, S3, S4, S5} StateType
   deriving (Bits, Eq);

// camDepth=256
// camSz = 8
// cdep = 1
interface Tcam9b#(numeric type camDepth);
   interface Put#(TcamWriteReq#(Bit#(TLog#(camDepth)), Bit#(9))) writeServer;
   interface Server#(ReadRequest, ReadResponse#(TSub#(TLog#(camDepth), 7))) readServer;
endinterface
module mkTcam9b(Tcam9b#(camDepth))
   provisos(Add#(cdep, 7, camSz)
           ,Log#(camDepth, camSz)
           ,Add#(a__, 2, TLog#(TDiv#(camDepth, 4)))
           ,Add#(2, b__, camSz)
           ,Add#(a__, c__, camSz)
           ,Log#(TDiv#(camDepth, 4), TAdd#(TAdd#(TLog#(cdep), 4), 2))
           ,Add#(TAdd#(TLog#(cdep), 4), d__, camSz)
           ,PriorityEncoder::PEncoder#(camDepth)
           );

   let verbose = True;
   let verbose_setram = verbose && True;
   let verbose_indxram = verbose && True;
   let verbose_indcram = verbose && True;

   FIFO#(TcamWriteReq#(Bit#(camSz), Bit#(9))) ramRequestFifo <- mkSizedFIFO(4);

   Ram9b#(cdep) ram9b <- mkRam9b();
   SetRam#(camDepth) setram <- mkSetRam();
   BinaryCam#(16, 16) indcbcam <- mkBinaryCamReg();

   Reg#(Bit#(9)) cPatt <- mkReg(0);
   Reg#(StateType) curr_state <- mkReg(S0);

   Reg#(Bit#(camSz)) wAddr <- mkReg(0);
   Reg#(Bool) write_started <- mkReg(False);

   FIFO#(Bit#(16)) setIndcFifo <- mkSizedFIFO(4);
   FIFO#(Maybe#(Bit#(4))) mAddrSetIndcFifo <- mkSizedFIFO(4);

   rule setram_read_idle if (!write_started);
      let v <- toGet(ramRequestFifo).get;
      write_started <= True;
      cPatt <= 0;
      wAddr <= v.addr;
      $display("setram read idle %h", v);
   endrule

   rule setram_read_req if (write_started);
      cPatt <= cPatt + 1;
      setram.readServer.request.put(tuple2(wAddr, cPatt));
      if (cPatt == maxBound) begin
         write_started <= False;
      end
      $display("setram read req %h", cPatt);
   endrule

   rule indc_cam_read;
      let setIndc <- setram.readServer.response.get;
      setIndcFifo.enq(setIndc);
      indcbcam.readServer.request.put(setIndc);
   endrule

   rule indc_cam_read_resp;
      let v <- indcbcam.readServer.response.get;
      mAddrSetIndcFifo.enq(v);
   endrule

   // write iitram
   rule setram_read_response;
      let setIndc <- toGet(setIndcFifo).get;
      let mAddr_setIndc <- toGet(mAddrSetIndcFifo).get;
      let pattIndc = reduceOr(setIndc);
      Vector#(TAdd#(TLog#(cdep), 4), Bit#(1)) wAddr_indx = takeAt(4, unpack(wAddr));
      $display("setram read response %h", setIndc);
      if (setIndc != 0) begin
         Bit#(1) wEnb_iVld = 1'b1;
         Bit#(1) wEnb_indx = pattIndc;
         Bit#(1) wEnb_indc = pattIndc;
         WriteRequest#(cdep) request = WriteRequest {
            wPatt : cPatt,
            wIndx : fromMaybe(0, mAddr_setIndc),
            wIndc : setIndc,
            wAddr_indx : pack(wAddr_indx),
            wAddr_indc : fromMaybe(0, mAddr_setIndc),
            wIVld : pattIndc,
            wEnb_iVld : wEnb_iVld,
            wEnb_indx : wEnb_indx,
            wEnb_indc : wEnb_indc
         };
         ram9b.writeRequest.put(request);
         if (verbose) $display("camctrl: write new pattern to iitram");
      end
   endrule

   interface Put writeServer;
      method Action put(TcamWriteReq#(Bit#(camSz), Bit#(9)) req);
         Bit#(camSz) wAddr = req.addr;
         Bit#(9) wData = req.data;
         if (verbose) $display("tcam9b: req %h %h %h", req.addr, req.data, req.mask);
         setram.writeServer.put(req);
         ramRequestFifo.enq(req);
      endmethod
   endinterface
   interface Server readServer;
      interface Put request = ram9b.readRequest;
      interface Get response = ram9b.readResponse;
   endinterface
endmodule

interface TernaryCam#(numeric type camDepth, numeric type pattWidth);
   interface Put#(TcamWriteReq#(Bit#(TLog#(camDepth)), Bit#(pattWidth))) writeServer;
   interface Server#(Bit#(pattWidth), Maybe#(Bit#(TLog#(camDepth)))) readServer;
endinterface

module mkTernaryCam(TernaryCam#(camDepth, pattWidth))
   provisos(Add#(cdep, 7, camSz)
            ,Mul#(cdep, 256, indcWidth)
            ,Log#(camDepth, camSz)
            ,Log#(indcWidth, camSz)
            ,Mul#(pwid, 9, pattWidth)
            ,Add#(TAdd#(TLog#(cdep), 4), 2, TLog#(TDiv#(camDepth, 4)))
            ,Log#(TDiv#(camDepth, 16), TAdd#(TLog#(cdep), 4))
            ,Add#(9, h__, pattWidth)
            ,PEncoder#(indcWidth)
            ,Add#(2, a__, camSz)
            ,Add#(4, b__, camSz)
            ,Add#(TAdd#(TLog#(cdep), 4), c__, camSz)
            ,Log#(TDiv#(camDepth, 4), TAdd#(TAdd#(TLog#(cdep), 4), 2))
            ,PriorityEncoder::PEncoder#(camDepth)
         );

   Clock defaultClock <- exposeCurrentClock;
   Reset defaultReset <- exposeCurrentReset;

   let verbose = True;
   FIFO#(Maybe#(Bit#(camSz))) readFifo <- mkSizedFIFO(4);
   FIFO#(Maybe#(Bit#(pattWidth))) printFifo <- mkSizedFIFO(4);

   Vector#(pwid, Tcam9b#(camDepth)) cam9b <- replicateM(mkTcam9b());

   rule cam9b_fifo_out;
      Bit#(indcWidth) mIndc = maxBound;
      for (Integer i=0; i < valueOf(pwid); i=i+1) begin
         let v_mIndc <- toGet(cam9b[i].readServer.response).get;
         mIndc = mIndc & pack(v_mIndc);
      end
      if (verbose) $display("tcam cascading mindc=%x", mIndc);
   endrule

   interface Server readServer;
      interface Put request;
         method Action put(Bit#(pattWidth) v);
            for (Integer i=0; i<valueOf(pwid); i=i+1) begin
               Vector#(9, Bit#(1)) data = takeAt(fromInteger(i) * 9, unpack(v));
               cam9b[i].readServer.request.put(ReadRequest{mPatt: pack(data)});
            end
         endmethod
      endinterface
      interface Get response = toGet(readFifo);
   endinterface
   interface Put writeServer;
      method Action put(TcamWriteReq#(Bit#(camSz),Bit#(pattWidth)) v);
         for (Integer i=0; i<valueOf(pwid); i=i+1) begin
            Vector#(9, Bit#(1)) data = takeAt(fromInteger(i) * 9, unpack(v.data));
            Vector#(9, Bit#(1)) mask = takeAt(fromInteger(i) * 9, unpack(v.mask));
            let req = TcamWriteReq{addr: v.addr, data: pack(data), mask: pack(mask)};
            cam9b[i].writeServer.put(req);
         end
      endmethod
   endinterface
endmodule

