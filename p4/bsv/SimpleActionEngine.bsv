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

/*
* SimpleActionEngine, which:
* - only support subset of instructions
* - implements the same interface as full action engine
* - is used for development and debugging purposes only
*/
import Clocks::*;
import DefaultValue::*;
import FIFO::*;
import FIFOF::*;
import GetPut::*;
import Vector::*;
import Pipe::*;

import Types::*;

// Action Types
interface ActionEngineIfc;
   interface Put#(PHV_port_mapping) phv_in;
   interface PipeIn#(ActionEntry) action_in;
   interface PipeOut#(PHV_port_mapping) phv_out;
endinterface

(* synthesize *)
module mkSimpleActionEngine(ActionEngineIfc);
   FIFOF#(ActionEntry) fifo_in_action <- mkSizedFIFOF(1);
   FIFOF#(PHV_port_mapping) fifo_in <- mkSizedFIFOF(1);
   FIFOF#(PHV_port_mapping) fifo_out <- mkSizedFIFOF(1);
   // Action should implement individual actions, and only generate used one.
   // Typical one action is implemented as a single rule, with:
   // - one set of input and output
   // - one rule to compute change
   // - action behaves as guard
   rule getAction;
      let v <- toGet(fifo_in_action).get;
      $display("Received Action");
   endrule

   // implement primitive actions
   rule modify_dst_addr if (fifo_out.notFull);
      let v <- toGet(fifo_in).get;
      fifo_out.enq(v);
   endrule

   interface Put phv_in;
      method Action put(PHV_port_mapping p) if (fifo_in.notFull);
         fifo_in.enq(p);
      endmethod
   endinterface
   interface PipeIn action_in = toPipeIn(fifo_in_action);
   interface PipeOut phv_out = toPipeOut(fifo_out);
endmodule

