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
   interface PipeIn#(Bit#(9)) wPatt;
   interface PipeIn#(Bit#(5)) wAddr_indx;
   interface PipeIn#(Bit#(5)) wAddr_indc;
   interface PipeIn#(Bit#(5)) wIndx;
   interface PipeIn#(Bit#(32)) wIndc;
   interface PipeIn#(Bool) wIVld;
   interface PipeOut#(Bit#(1024)) mIndc;
endinterface
module mkRam9bx1k(Ram9bx1k);
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

   FIFOF#(Bit#(32)) iVld_fifo <- mkBypassFIFOF;

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
//`define DPMLAB AsymmetricBRAM#(Bit#(5), Bit#(32), Bit#(5), Bit#(32))
//   Vector#(32, `DPMLAB) dpmlab <- replicateM(mkAsymmetricBRAM(False, False, "dpmlab"));

   Vector#(4, Wire#(Bit#(40))) indx <- replicateM(mkDWire(0));

   Vector#(2, PipeOut#(Bit#(9))) wPattPipes <- mkForkVector(toPipeOut(wPatt_fifo));
   Vector#(3, PipeOut#(Bit#(5))) wAddrIndxPipes <- mkForkVector(toPipeOut(wAddr_indx_fifo));

   rule vldram_write;
      let wPatt <- toGet(wPattPipes[0]).get;
      let wAddr_indx <- toGet(wAddrIndxPipes[0]).get;
      let wEnb_iVld <- toGet(wEnb_iVld_fifo).get;
      let wIVld <- toGet(wIVld_fifo).get;
      Bit#(14) wAddr = {wPatt, wAddr_indx};
      vldram.writeServer.put(tuple2(wAddr, pack(wIVld)));
      $display("vldram %d: write to vldram wAddr=%x, data=%x", cycle, wAddr, pack(wIVld));
   endrule

   rule ram_read;
      let mPatt <- toGet(mPatt_fifo).get;
      vldram.readServer.request.put(mPatt);
      for (Integer i=0; i<4; i=i+1) begin
         indxram[i].readServer.request.put(mPatt);
      end
   endrule

   rule indxram_write;
      let wPatt <- toGet(wPattPipes[1]).get;
      let wAddr_indx <- toGet(wAddrIndxPipes[1]).get;
      let wEnb_indx <- toGet(wEnb_indx_fifo).get;
      let wIndx <- toGet(wIndx_fifo).get;
      for (Integer i=0; i<4; i=i+1) begin
         if (wAddr_indx[4:3] == fromInteger(i)) begin
            Bit#(12) wAddr = {wPatt, wAddr_indx[2:0]};
            indxram[i].writeServer.put(tuple2(wAddr, wIndx));
            $display("indxram %d: write i=%x wAddr=%x, data=%x", cycle, i, wAddr, wIndx);
         end
      end
   endrule

   rule dpmlab_write;
      let wAddr_indx <- toGet(wAddrIndxPipes[2]).get;
      let wAddr_indc <- toGet(wAddr_indc_fifo).get;
      let wEnb_indc <- toGet(wEnb_indc_fifo).get;
      let wIndc <- toGet(wIndc_fifo).get;
      for (Integer i=0; i<4; i=i+1) begin
         for (Integer j=0; j<8; j=j+1) begin
            if ((wAddr_indx[4:3] == fromInteger(i)) && wAddr_indx[2:0] == fromInteger(j)) begin
               $display("dpmlab %d: write i=%d, j=%d index=%d, data=%x", cycle, i, j, i*8+j, wIndc);
               //dpmlab[i*8+j].writeServer.put(tuple2(wAddr_indc, wIndc));
               dpmlab[i*8+j].portA.request.put(BRAMRequest{write:True, responseOnWrite:False, address: wAddr_indc, datain: wIndc});
            end
         end
      end
   endrule

   rule vldram_output;
      let v <- vldram.readServer.response.get;
      iVld_fifo.enq(v);
   endrule

   for (Integer i=0; i<4; i=i+1) begin
      rule indxram_output;
         let v <- indxram[i].readServer.response.get;
         for (Integer j=0; j<8; j=j+1) begin
            Bit#(5) addr = v[(j+1)*5-1 : j*5];
            //dpmlab[i*8+j].readServer.request.put(addr);
            dpmlab[i*8+j].portB.request.put(BRAMRequest{write: False, responseOnWrite: False, address: addr, datain: ?});
            //$display("dpmlab %d: write i=%d, j=%d index=%d", cycle, i, j, i*8+j);
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
         end
      end
      mIndc_fifo.enq(mIndc);
      $display("dpmlab %d: mIndc=%x", cycle, pack(mIndc));
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

interface Ram9b#(numeric type cdep);//camDepth);
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
module mkRam9b(Ram9b#(cdep))
   provisos(Mul#(cdep, 1024, indcWidth)
            ,Add#(TLog#(cdep), 5, wAddrHWidth));

   let verbose = True;
   Reg#(Bit#(32)) cycle <- mkReg(0);
   rule every1 if (verbose);
      cycle <= cycle + 1;
   endrule

   FIFOF#(Bool) wEnb_iVld_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) wEnb_indx_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) wEnb_indc_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(9)) mPatt_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(9)) wPatt_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(wAddrHWidth)) wAddr_indx_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(5)) wAddr_indc_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(5)) wIndx_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(32)) wIndc_fifo <- mkBypassFIFOF();
   FIFOF#(Bool) wIVld_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(indcWidth)) mIndc_fifo <- mkBypassFIFOF();

   Vector#(cdep, Ram9bx1k) ram <- replicateM(mkRam9bx1k());

   rule ram_wEnb;
      let wEnb_iVld <- toGet(wEnb_iVld_fifo).get;
      let wEnb_indx <- toGet(wEnb_indx_fifo).get;
      let wEnb_indc <- toGet(wEnb_indc_fifo).get;
      let wAddr_indx <- toGet(wAddr_indx_fifo).get;
      Vector#(cdep, Bool) wEnb = replicate(False);
      for (Integer i=0; i < valueOf(cdep); i=i+1) begin
         wEnb[i] = ((wAddr_indx >> 5) == fromInteger(i));
         ram[i].wEnb_iVld.enq(wEnb_iVld && wEnb[i]);
         ram[i].wEnb_indx.enq(wEnb_indx && wEnb[i]);
         ram[i].wEnb_indc.enq(wEnb_indc && wEnb[i]);
         ram[i].wAddr_indx.enq(wAddr_indx[4:0]);
      end
      $display("ram9b %d: write wEnb to all ram blocks", cycle);
   endrule

   rule ram_mPatt;
      let mPatt <- toGet(mPatt_fifo).get;
      for (Integer i=0; i < valueOf(cdep); i=i+1) begin
         ram[i].mPatt.enq(mPatt);
      end
      $display("ram9b %d: mPatt=%x", cycle, mPatt);
   endrule

   rule ram_wPatt;
      let wPatt <- toGet(wPatt_fifo).get;
      for (Integer i=0; i < valueOf(cdep); i=i+1) begin
          ram[i].wPatt.enq(wPatt);
      end
      $display("ram9b %d: wPatt=%x", cycle, wPatt);
   endrule

   rule ram_wAddr;
      let wAddr_indc <- toGet(wAddr_indc_fifo).get;
      let wIndx <- toGet(wIndx_fifo).get;
      let wIVld <- toGet(wIVld_fifo).get;
      let wIndc <- toGet(wIndc_fifo).get;
      for (Integer i=0; i < valueOf(cdep); i=i+1) begin
         ram[i].wAddr_indc.enq(wAddr_indc);
         ram[i].wIndx.enq(wIndx);
         ram[i].wIVld.enq(wIVld);
         ram[i].wIndc.enq(wIndc);
      end
      $display("ram9b %d: wAddr=%x, wIndc=%x", cycle, wAddr_indc, wIndc);
   endrule

   rule ram_output;
      Vector#(cdep, Bit#(1024)) mIndc;
      for (Integer i=0; i < valueOf(cdep); i=i+1) begin
         let v <- toGet(ram[i].mIndc).get;
         mIndc[i] = v;
      end
      mIndc_fifo.enq(pack(mIndc));
      $display("ram9b %d: mIndc=%x", cycle, pack(mIndc));
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


