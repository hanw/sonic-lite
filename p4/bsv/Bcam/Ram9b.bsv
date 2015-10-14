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


