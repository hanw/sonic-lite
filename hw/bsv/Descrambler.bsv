
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

interface Descrambler;
   interface PipeIn#(Bit#(66)) descramblerIn;
   interface PipeOut#(Bit#(66)) descrambledOut;
   (* always_ready, always_enabled *)
   method Action rx_ready(Bool v);
endinterface

// Scrambler poly G(x) = 1 + x^39 + x^58;
(* synthesize *)
module mkDescrambler(Descrambler);

   let verbose = False;
   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

   Reg#(Bit#(32))       cycle <- mkReg(0);
   Reg#(Bit#(58)) scram_state <- mkReg(58'h3ff_ffff_ffff_ffff);
   FIFOF#(Bit#(66))  fifo_in <- mkFIFOF;
   FIFOF#(Bit#(66))  fifo_out <- mkBypassFIFOF;
   Wire#(Bool) rx_ready_wire <- mkDWire(False);

   rule cyc;
      cycle <= cycle + 1;
   endrule

   rule descramble(rx_ready_wire);
      let v <- toGet(fifo_in).get;
      Bit#(2) sync_hdr = v[1:0];
      Bit#(64) pre_descramble = v[65:2];
      Bit#(122) history = {pre_descramble, scram_state};
      Vector#(64, Bit#(1)) dout_w;
      Bit#(66) descramble_out;
      if(verbose) $display("%d: descrambler %h input=%h synchdr=%h", cycle, v, pre_descramble, v[1:0]);

      for (Integer i=0; i<64; i=i+1) begin
         dout_w[i] = history[58+i-58] ^ history[58+i-39] ^ history[58+i];
      end
      scram_state <= history[121:64];

      descramble_out = {pack(dout_w), sync_hdr};
      fifo_out.enq(descramble_out);
      if(verbose) $display("%d: descrambler dataout=%h", cycle, descramble_out);
   endrule

   method Action rx_ready (Bool v);
      rx_ready_wire <= v;
   endmethod

   interface descramblerIn = toPipeIn(fifo_in);
   interface descrambledOut = toPipeOut(fifo_out);
endmodule
endpackage
