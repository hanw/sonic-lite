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

import GetPut::*;
import SpecialFIFOs::*;
import Pipe::*;
import FIFOF::*;
import Vector::*;

interface M20k#(numeric type wwid, numeric type rwid, numeric type wdep);
   interface PipeIn#(Bool) wEnb;
   interface PipeIn#(Bit#(TLog#(wdep))) wAddr;
   interface PipeIn#(Bit#(wwid)) wData;
   interface PipeIn#(Bit#(TLog#(TDiv#(wdep,TDiv#(rwid, wwid))))) rAddr;
   interface PipeOut#(Bit#(rwid)) rData;
endinterface

`ifdef BSIM
module mkM20k(M20k#(wwid, rwid, wdep))
      provisos(Add#(TLog#(wdep), 0, wAddrWidth),
               Add#(TLog#(TDiv#(wdep, TDiv#(rwid, wwid))), 0, rAddrWidth),
               Add#(TDiv#(rwid, wwid), 0, ratio),
               Mul#(TDiv#(rwid, wwid), wwid, rwid)
              );
   Vector#(rAddrWidth, Vector#(ratio, Reg#(Bit#(wwid)))) ram <- replicateM(replicateM(mkReg(0)));

   FIFOF#(Bool)              wEnb_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(wAddrWidth)) wAddr_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(wwid))       wData_fifo <- mkBypassFIFOF();
   FIFOF#(Bit#(rAddrWidth)) rAddr_fifo <- mkFIFOF();
   FIFOF#(Bit#(rwid))       rData_fifo <- mkBypassFIFOF();

   Reg#(Bit#(32)) cycle <- mkReg(0);
   rule every1;
      cycle <= cycle + 1;
   endrule

   rule port1_write;
      let wEnb <- toGet(wEnb_fifo).get;
      let wAddr <- toGet(wAddr_fifo).get;
      let wData <- toGet(wData_fifo).get;
      Int#(wAddrWidth) addr1 = unpack(wAddr) / fromInteger(valueOf(ratio));
      Int#(wAddrWidth) addr2 = unpack(wAddr) % fromInteger(valueOf(ratio));
      if (wEnb) begin
         ram[pack(addr1)][pack(addr2)] <= wData;
      end
   endrule
   rule port2_read;
      let rAddr <- toGet(rAddr_fifo).get;
      Vector#(ratio, Bit#(wwid)) v = replicate(0);
      for (Integer i=0; i<valueOf(ratio); i=i+1) begin
         v[i] = readReg(ram[rAddr][i]);
      end
      rData_fifo.enq(pack(v));
   endrule

   interface PipeIn wEnb = toPipeIn(wEnb_fifo);
   interface PipeIn wAddr = toPipeIn(wAddr_fifo);
   interface PipeIn wData = toPipeIn(wData_fifo);
   interface PipeIn rAddr = toPipeIn(rAddr_fifo);
   interface PipeOut rData = toPipeOut(rData_fifo);
endmodule
`endif

