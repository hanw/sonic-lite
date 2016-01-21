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
import ConnectalBram::*;

import BcamTypes::*;

typedef struct {
   Bit#(9) wPatt;
   Bit#(5) wIndx;
   Bit#(32) wIndc; // sqrt(256)
   Bit#(5) wAddr_indx; // log(depth)/2
   Bit#(5) wAddr_indc; // log(depth)/2
   Bit#(1) wIVld;
   Bit#(1) wEnb_iVld;
   Bit#(1) wEnb_indx;
   Bit#(1) wEnb_indc;
} Ram9bWriteRequest deriving (Bits, Eq);

typedef struct {
   Bit#(9) mPatt;
} Ram9bReadRequest deriving (Bits, Eq);

typedef struct {
   Bit#(1024) mIndc;
} Ram9bReadResponse deriving (Bits, Eq);

interface Ram9bx1024;
   interface Put#(Ram9bWriteRequest) writeReq;
   interface Put#(Ram9bReadRequest) readReq;
   interface Get#(Ram9bReadResponse) readResp;
endinterface
module mkRam9bx1024(Ram9bx1024);
   let verbose = False;
   Reg#(Bit#(32)) cycle <- mkReg(0);
   rule every1 if (verbose);
      cycle <= cycle + 1;
   endrule

   FIFOF#(Bit#(32)) iVld_fifo <- mkFIFOF;
   FIFOF#(Bit#(1024)) mIndc_fifo <- mkBypassFIFOF();

   // WWID = 1, RWID = 32, WDEP = 16384, OREG = 1, INIT = 1
`define VLDRAM AsymmetricBRAM#(Bit#(9), Bit#(32), Bit#(14), Bit#(1))
   `VLDRAM vldram <- mkAsymmetricBRAM(True, False, "VLDram");

   // WWID = 5, RWID = 40, WDEP = 4096, OREG = 0, INIT = 1
`define INDXRAM AsymmetricBRAM#(Bit#(9), Bit#(40), Bit#(12), Bit#(5))
   Vector#(4, `INDXRAM) indxram <- replicateM(mkAsymmetricBRAM(True, False, "indxRam"));
   // DWID = 32, DDEP = 32, MRDW = "DONT_CARE", RREG=ALL, INIT=1
   BRAM_Configure bramCfg = defaultValue;
   bramCfg.memorySize = 32;
   bramCfg.latency=1;
   Vector#(32, BRAM2Port#(Bit#(5), Bit#(32))) dpmlab <- replicateM(ConnectalBram::mkBRAM2Server(bramCfg));

   Vector#(4, Wire#(Bit#(40))) indx <- replicateM(mkDWire(0));

   rule vldram_output;
      let v <- vldram.readServer.response.get;
      if (verbose) $display("vldram %d: read v=%x", cycle, v);
      iVld_fifo.enq(v);
   endrule

   for (Integer i=0; i<4; i=i+1) begin
      rule indxram_output;
         let v <- indxram[i].readServer.response.get;
         for (Integer j=0; j<8; j=j+1) begin
            Bit#(5) addr = v[(j+1)*5-1 : j*5];
            //dpmlab[i*8+j].readServer.request.put(addr);
            dpmlab[i*8+j].portB.request.put(BRAMRequest{write: False, responseOnWrite: False, address: addr, datain: ?});
            //$display("dpmlab %d: read i=%d, j=%d index=%d", cycle, i, j, i*8+j);
         end
      endrule
   end

   rule dpmlab_read_response;
      let ivld <- toGet(iVld_fifo).get;
      Bit#(1024) mIndc = 0;
      for (Integer i=0; i<4; i=i+1) begin
         for (Integer j=0; j<8; j=j+1) begin
            //let v <- dpmlab[i*8+j].readServer.response.get;
            let v <- dpmlab[i*8+j].portB.response.get;
            Vector#(32, Bit#(1)) ivld_vec = replicate(ivld[8*i+j]);
            Bit#(32) mIndcV = v & pack(ivld_vec);
            mIndc[(i*8+j+1)*32-1 : (i*8+j)*32] = mIndcV;
            if (verbose) $display("dpmlab %d: read i=%d, j=%d index=%d v=%x", cycle, i, j, i*8+j, v);
         end
      end
      mIndc_fifo.enq(mIndc);
      if (verbose) $display("dpmlab %d: mIndc=%x", cycle, pack(mIndc));
   endrule

   interface Put writeReq;
      method Action put(Ram9bWriteRequest req);
         let wIVld  = req.wIVld;
         let wEnb_iVld = req.wEnb_iVld;
         let wEnb_indx = req.wEnb_indx;
         if (wEnb_iVld == 1) begin
            Bit#(14) wAddr = {req.wPatt, req.wAddr_indx};
            vldram.writeServer.put(tuple2(wAddr, pack(wIVld)));
            if (verbose) $display("vldram %d: write to vldram wAddr=%x, data=%x", cycle, wAddr, pack(wIVld));
         end

         if (wEnb_indx == 1) begin
            for (Integer i=0; i<4; i=i+1) begin
               if (req.wAddr_indx[4:3] == fromInteger(i)) begin
                  Bit#(12) wAddr = {req.wPatt, req.wAddr_indx[2:0]};
                  indxram[i].writeServer.put(tuple2(wAddr, req.wIndx));
                  if (verbose) $display("indxram %d: write i=%x wAddr=%x, wIndx=%x", cycle, i, wAddr, req.wIndx);
               end
            end
         end

         let wAddr_indc = req.wAddr_indc;
         let wIndc = req.wIndc;
         let wEnb_indc = req.wEnb_indc;
         if (wEnb_indc == 1) begin
            for (Integer i=0; i<4; i=i+1) begin
               for (Integer j=0; j<8; j=j+1) begin
                  if ((req.wAddr_indx[4:3] == fromInteger(i)) && req.wAddr_indx[2:0] == fromInteger(j)) begin
                     if (verbose) $display("dpmlab %d: write i=%d, j=%d index=%d, wIndc=%x", cycle, i, j, i*8+j, wIndc);
                     //dpmlab[i*8+j].writeServer.put(tuple2(wAddr_indc, wIndc));
                     dpmlab[i*8+j].portA.request.put(BRAMRequest{write:True, responseOnWrite:False, address: wAddr_indc, datain: wIndc});
                  end
               end
            end
         end
      endmethod
   endinterface
   interface Put readReq;
      method Action put(Ram9bReadRequest req);
         // put
         let mPatt = req.mPatt;
         vldram.readServer.request.put(mPatt);
         for (Integer i=0; i<4; i=i+1) begin
            indxram[i].readServer.request.put(mPatt);
         end
      endmethod
   endinterface
   interface Get readResp;
      method ActionValue#(Ram9bReadResponse) get();
         let _mIndc <- toGet(mIndc_fifo).get;
         return Ram9bReadResponse{mIndc: _mIndc};
      endmethod
   endinterface
endmodule

typedef struct {
   Bit#(9) wPatt;
   Bit#(5) wIndx;
   Bit#(32) wIndc; // sqrt(256)
   Bit#(TAdd#(TLog#(cdep), 5)) wAddr_indx; // log(depth)/2
   Bit#(5) wAddr_indc; // log(depth)/2
   Bit#(1) wIVld;
   Bit#(1) wEnb_iVld;
   Bit#(1) wEnb_indx;
   Bit#(1) wEnb_indc;
} WriteRequest#(numeric type cdep) deriving (Bits, Eq);

typedef struct {
   Bit#(9) mPatt;
} ReadRequest deriving (Bits, Eq);

typedef struct {
   Bit#(TMul#(cdep, 1024)) mIndc;
} ReadResponse#(numeric type cdep) deriving (Bits, Eq);

interface Ram9b#(numeric type cdep);
   interface Put#(WriteRequest#(cdep)) writeRequest;
   interface Put#(ReadRequest) readRequest;
   interface Get#(ReadResponse#(cdep)) readResponse;
endinterface
module mkRam9b(Ram9b#(cdep))
   provisos(Mul#(cdep, 1024, indcWidth)
            ,Add#(TLog#(cdep), 5, wAddrHWidth));

   let verbose = False;
   Reg#(Bit#(32)) cycle <- mkReg(0);
   rule every1 if (verbose);
      cycle <= cycle + 1;
   endrule

   Vector#(cdep, Ram9bx1024) ram <- replicateM(mkRam9bx1024());

   interface Put writeRequest;
      method Action put(WriteRequest#(cdep) req);
         Vector#(cdep, Bool) wEnb = replicate(False);
         Vector#(cdep, Ram9bWriteRequest) requests;
         for (Integer i=0; i < valueOf(cdep); i=i+1) begin
            wEnb[i] = ((req.wAddr_indx >> 5) == fromInteger(i));
            requests[i] = Ram9bWriteRequest { wPatt: req.wPatt,
               wIndx: req.wIndx,
               wIndc: req.wIndc,
               wAddr_indx: req.wAddr_indx[4:0],
               wAddr_indc: req.wAddr_indc,
               wIVld: req.wIVld,
               wEnb_iVld: pack(unpack(req.wEnb_iVld) && wEnb[i]),
               wEnb_indx: pack(unpack(req.wEnb_indx) && wEnb[i]),
               wEnb_indc: pack(unpack(req.wEnb_indc) && wEnb[i])
            };
            ram[i].writeReq.put(requests[i]);
         end
      endmethod
   endinterface
   interface Put readRequest;
      method Action put (ReadRequest req);
         Vector#(cdep, Ram9bReadRequest) requests;
         for (Integer i=0; i < valueOf(cdep); i=i+1) begin
            requests[i] = Ram9bReadRequest{mPatt: req.mPatt};
            ram[i].readReq.put(requests[i]);
         end
         if (verbose) $display("ram9b %d: mPatt=%x", cycle, req.mPatt);
      endmethod
   endinterface
   interface Get readResponse;
      method ActionValue#(ReadResponse#(cdep)) get();
         Vector#(cdep, Bit#(1024)) _mIndc;
         for (Integer i=0; i < valueOf(cdep); i=i+1) begin
            let v <- toGet(ram[i].readResp).get;
            _mIndc[i] = v.mIndc;
         end
         return ReadResponse{mIndc: pack(_mIndc)};
      endmethod
   endinterface
endmodule


