
// Copyright (c) 2013 Nokia, Inc.

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

import FIFO::*;
import Vector::*;

interface SonicUserRequest;
    method Action readCycleCount(Bit#(64) cmd);
    method Action writeDelay(Bit#(64) host_cnt);
endinterface

interface SonicUser;
   interface SonicUserRequest request;
endinterface

module mkSonicUser#(SonicUserRequest indication)(SonicUser);
   let verbose = False;
   Reg#(Bit#(64))  cycle_count <- mkReg(0);
   Reg#(Bit#(64))  last_count  <- mkReg(0);

   rule count;
      cycle_count <= cycle_count + 1;
   endrule

   interface SonicUserRequest request;
   method Action readCycleCount(Bit#(64) cmd);
      indication.readCycleCount(truncate(cycle_count));
   endmethod
   method Action writeDelay(Bit#(64) host_cnt);
      Bit#(64) delay = (host_cnt - cycle_count) >> 1;
      indication.writeDelay(truncate(delay));
   endmethod
   endinterface
endmodule
