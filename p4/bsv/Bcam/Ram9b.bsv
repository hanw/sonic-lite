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

interface Ram9bx1k;
   interface PipeIn#(Bool) wEnb_iVld;
   interface PipeIn#(Bool) wEnb_indx;
   interface PipeIn#(Bool) wEnb_indc;
   interface PipeIn#(Bit#(9)) mPatt;
   interface Put#(Bit#(9)) wPatt;
   interface Put#(Bit#(5)) wAddr_indx;
   interface PipeIn#(Bit#(5)) wAddr_indc;
   interface PipeIn#(Bit#(5)) wIndx;
   interface PipeIn#(Bit#(32)) wIndc;
   interface PipeIn#(Bool) wIVld;
   interface PipeOut#(Bit#(1024)) mIndc;
endinterface
module mkRam9bx1k(Ram9bx1k);
   FIFOF#(Bool) wEnb_iVld_fifo <- mkFIFOF();
   FIFOF#(Bool) wEnb_indx_fifo <- mkFIFOF();
   FIFOF#(Bool) wEnb_indc_fifo <- mkFIFOF();
   FIFOF#(Bit#(9)) mPatt_fifo <- mkFIFOF();
   FIFOF#(Bit#(9)) wPatt_fifo <- mkFIFOF();
   FIFOF#(Bit#(5)) wAddr_indx_fifo <- mkFIFOF();
   FIFOF#(Bit#(5)) wAddr_indc_fifo <- mkFIFOF();
   FIFOF#(Bit#(5)) wIndx_fifo <- mkFIFOF();
   FIFOF#(Bit#(32)) wIndc_fifo <- mkFIFOF();
   FIFOF#(Bool) wIVld_fifo <- mkFIFOF();
   FIFOF#(Bit#(1024)) mIndc_fifo <- mkBypassFIFOF();

   FIFOF#(Bit#(32)) iVld_fifo <- mkFIFOF;

   let verbose = True;
   Reg#(Bit#(32)) cycle <- mkReg(0);
   rule every1 if (verbose);
      cycle <= cycle + 1;
   endrule

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

   // change the following to registers..
   Reg#(Bit#(9)) wPatt_reg <- mkReg(0);
   Reg#(Bit#(5)) wAddr_indx_reg <- mkReg(0);

   rule vldram_write;
      let wIVld <- toGet(wIVld_fifo).get;
      let wEnb_iVld <- toGet(wEnb_iVld_fifo).get;
      if (wEnb_iVld) begin
         Bit#(14) wAddr = {wPatt_reg, wAddr_indx_reg};
         vldram.writeServer.put(tuple2(wAddr, pack(wIVld)));
         if (verbose) $display("vldram %d: write to vldram wAddr=%x, data=%x", cycle, wAddr, pack(wIVld));
      end
   endrule

   rule ram_read;
      let mPatt <- toGet(mPatt_fifo).get;
      vldram.readServer.request.put(mPatt);
      for (Integer i=0; i<4; i=i+1) begin
         indxram[i].readServer.request.put(mPatt);
      end
   endrule

   rule indxram_write;
      let wIndx <- toGet(wIndx_fifo).get;
      let wEnb_indx <- toGet(wEnb_indx_fifo).get;
      if (wEnb_indx) begin
         for (Integer i=0; i<4; i=i+1) begin
            if (wAddr_indx_reg[4:3] == fromInteger(i)) begin
               Bit#(12) wAddr = {wPatt_reg, wAddr_indx_reg[2:0]};
               indxram[i].writeServer.put(tuple2(wAddr, wIndx));
               if (verbose) $display("indxram %d: write i=%x wAddr=%x, wIndx=%x", cycle, i, wAddr, wIndx);
            end
         end
      end
   endrule

   rule dpmlab_write;
      let wAddr_indc <- toGet(wAddr_indc_fifo).get;
      let wIndc <- toGet(wIndc_fifo).get;
      let wEnb_indc <- toGet(wEnb_indc_fifo).get;
      if (wEnb_indc) begin
         for (Integer i=0; i<4; i=i+1) begin
            for (Integer j=0; j<8; j=j+1) begin
               if ((wAddr_indx_reg[4:3] == fromInteger(i)) && wAddr_indx_reg[2:0] == fromInteger(j)) begin
                  if (verbose) $display("dpmlab %d: write i=%d, j=%d index=%d, wIndc=%x", cycle, i, j, i*8+j, wIndc);
                  //dpmlab[i*8+j].writeServer.put(tuple2(wAddr_indc, wIndc));
                  dpmlab[i*8+j].portA.request.put(BRAMRequest{write:True, responseOnWrite:False, address: wAddr_indc, datain: wIndc});
               end
            end
         end
      end
   endrule

   rule vldram_output;
      let v <- vldram.readServer.response.get;
      $display("vldram %d: read v=%x", cycle, v);
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
            $display("dpmlab %d: read i=%d, j=%d index=%d v=%x", cycle, i, j, i*8+j, v);
         end
      end
      mIndc_fifo.enq(mIndc);
      if (verbose) $display("dpmlab %d: mIndc=%x", cycle, pack(mIndc));
   endrule

   interface PipeIn wEnb_iVld = toPipeIn(wEnb_iVld_fifo);
   interface PipeIn wEnb_indx = toPipeIn(wEnb_indx_fifo);
   interface PipeIn wEnb_indc = toPipeIn(wEnb_indc_fifo);
   interface PipeIn mPatt = toPipeIn(mPatt_fifo);
   interface Put wPatt;
      method Action put (Bit#(9) v);
         wPatt_reg <= v;
         $display("ram9b %d: wPatt_reg = %x", cycle, v);
      endmethod
   endinterface
   interface Put wAddr_indx;
      method Action put (Bit#(5) v);
         wAddr_indx_reg <= v;
         $display("ram9b %d: wAddr_indx_reg = %x", cycle, v);
      endmethod
   endinterface
   interface PipeIn wAddr_indc = toPipeIn(wAddr_indc_fifo);
   interface PipeIn wIndx = toPipeIn(wIndx_fifo);
   interface PipeIn wIndc = toPipeIn(wIndc_fifo);
   interface PipeIn wIVld = toPipeIn(wIVld_fifo);
   interface PipeOut mIndc = toPipeOut(mIndc_fifo);
endmodule

interface Ram9b#(numeric type cdep);
   interface Put#(Bool) wEnb_iVld;
   interface Put#(Bool) wEnb_indx;
   interface Put#(Bool) wEnb_indc;
   interface Put#(Bit#(9)) mPatt;
   interface Put#(Bit#(9)) wPatt;
   interface Put#(Bit#(TAdd#(TLog#(cdep), 5))) wAddr_indx;
   interface Put#(Bit#(5)) wAddr_indc;
   interface Put#(Bit#(5)) wIndx;
   interface Put#(Bit#(32)) wIndc;
   interface Put#(Bool) wIVld;
   interface PipeOut#(Bit#(TMul#(cdep, 1024))) mIndc;
endinterface
module mkRam9b(Ram9b#(cdep))
   provisos(Mul#(cdep, 1024, indcWidth)
            ,Add#(TLog#(cdep), 5, wAddrHWidth));

   let verbose = True;
   Reg#(Bit#(32)) cycle <- mkReg(0);
   rule every1 if (verbose);
      cycle <= cycle + 1;
   endrule

   Reg#(Bit#(TAdd#(TLog#(cdep), 5))) wAddr_indx_reg <- mkReg(0);
   FIFOF#(Bit#(indcWidth)) mIndc_fifo <- mkBypassFIFOF();

   Vector#(cdep, Ram9bx1k) ram <- replicateM(mkRam9bx1k());

   function PipeOut#(Bit#(1024)) to_mIndc(Ram9bx1k a);
      return a.mIndc;
   endfunction
   PipeOut#(Bit#(TMul#(cdep, 1024))) mIndcPipe <- mkJoinVector(pack, map(to_mIndc, ram));

   interface Put wEnb_iVld;
      method Action put (Bool v);
         Vector#(cdep, Bool) wEnb = replicate(False);
         for (Integer i=0; i < valueOf(cdep); i=i+1) begin
            wEnb[i] = ((wAddr_indx_reg >> 5) == fromInteger(i));
            ram[i].wEnb_iVld.enq(v && wEnb[i]);
         end
         if (verbose) $display("ram9b %d: wEnb_ivld=%x", cycle, v);
      endmethod
   endinterface
   interface Put wEnb_indx;
      method Action put (Bool v);
         Vector#(cdep, Bool) wEnb = replicate(False);
         for (Integer i=0; i < valueOf(cdep); i=i+1) begin
            wEnb[i] = ((wAddr_indx_reg >> 5) == fromInteger(i));
            ram[i].wEnb_indx.enq(v && wEnb[i]);
         end
         if (verbose) $display("ram9b %d: wEnb_indx=%x", cycle, v);
      endmethod
   endinterface
   interface Put wEnb_indc;
      method Action put (Bool v);
         Vector#(cdep, Bool) wEnb = replicate(False);
         for (Integer i=0; i < valueOf(cdep); i=i+1) begin
            wEnb[i] = ((wAddr_indx_reg >> 5) == fromInteger(i));
            ram[i].wEnb_indc.enq(v && wEnb[i]);
         end
         if (verbose) $display("ram9b %d: wEnb_indc=%x", cycle, v);
      endmethod
   endinterface 
   interface Put mPatt;
      method Action put (Bit#(9) v);
         for (Integer i=0; i < valueOf(cdep); i=i+1) begin
            ram[i].mPatt.enq(v);
         end
         if (verbose) $display("ram9b %d: mPatt=%x", cycle, v);
      endmethod
   endinterface
   interface Put wPatt;
      method Action put (Bit#(9) v);
         for (Integer i=0; i < valueOf(cdep); i=i+1) begin
            ram[i].wPatt.put(v);
         end
         if (verbose) $display("ram9b %d: wPatt=%x", cycle, v);
      endmethod
   endinterface
   interface Put wAddr_indx;
      method Action put (Bit#(wAddrHWidth) v);
         for (Integer i=0; i < valueOf(cdep); i=i+1) begin
            ram[i].wAddr_indx.put(v[4:0]);
            wAddr_indx_reg <= v;
         end
         if (verbose) $display("ram9b %d: write wEnb to all ram blocks", cycle);
      endmethod
   endinterface 
   interface Put wAddr_indc;
      method Action put (Bit#(5) v);
         for (Integer i=0; i < valueOf(cdep); i=i+1) begin
            ram[i].wAddr_indc.enq(v);
         end
         if (verbose) $display("ram9b %d: wAddr_indc=%x", cycle, v);
      endmethod
   endinterface
   interface Put wIndx;
      method Action put (Bit#(5) v);
         for (Integer i=0; i < valueOf(cdep); i=i+1) begin
            ram[i].wIndx.enq(v);
         end
         if (verbose) $display("ram9b %d: wIndx=%x", cycle, v);
      endmethod
   endinterface
   interface Put wIndc;
      method Action put (Bit#(32) v);
         for (Integer i=0; i < valueOf(cdep); i=i+1) begin
            ram[i].wIndc.enq(v);
         end
         if (verbose) $display("ram9b %d: wIndc=%x", cycle, v);
      endmethod
   endinterface
   interface Put wIVld;
      method Action put (Bool v);
         for (Integer i=0; i < valueOf(cdep); i=i+1) begin
            ram[i].wIVld.enq(v);
         end
         if (verbose) $display("ram9b %d: wIVld=%x", cycle, v);
      endmethod
   endinterface
   interface PipeOut mIndc = mIndcPipe;
endmodule
