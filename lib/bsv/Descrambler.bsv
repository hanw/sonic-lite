
// Copyright (c) 2014 Cornell University.

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

package Descrambler;

import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;

import Pipe::*;
import MemTypes::*;

interface Descrambler;
   interface PipeOut#(Bit#(66)) descrambledOut;
endinterface

// Scrambler poly G(x) = 1 + x^39 + x^58;
module mkDescrambler#(PipeOut#(Bit#(66)) descramblerIn)(Descrambler);
   let verbose = True;

   Reg#(Bit#(32))       cycle <- mkReg(0);
   Reg#(Bit#(58)) scram_state <- mkReg(58'h3ff_ffff_ffff_ffff);
   Vector#(64, Reg#(Bit#(1))) dout_w <- replicateM(mkReg(0));
   Vector#(122, Reg#(Bit#(1))) history <- replicateM(mkReg(0));
   FIFOF#(Bit#(66))  fifo_out <- mkBypassFIFOF;
   FIFOF#(Bit#(66))  fifo_in  <- mkBypassFIFOF;
   Vector#(2, Reg#(Bit#(1))) synchdr <- replicateM(mkReg(0));

   rule cyc;
      cycle <= cycle + 1;
   endrule

   rule descramble;
      let v = fifo_in.first;
      fifo_in.deq;

      writeVReg(take(synchdr), unpack(v[1:0]));
      writeVReg(take(history), unpack({v[65:2], scram_state}));
      for (Integer i=0; i<64; i=i+1) begin
         dout_w[i] <= history[58+i-58] ^ history[58+i-39] ^ history[58+i];
      end
      scram_state <= pack(readVReg(history))[121:64];
      fifo_out.enq({pack(readVReg(dout_w)), pack(readVReg(synchdr))});

      if(verbose) $display("%d: history=%h", cycle, pack(readVReg(history)));
   endrule

   rule incoming;
      let v <- toGet(descramblerIn).get;
      fifo_in.enq(v);
   endrule

   interface descrambledOut = toPipeOut(fifo_out);
endmodule
endpackage
