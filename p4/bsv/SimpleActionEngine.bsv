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

// Generate interface from match table
typedef struct {
   Bit#(48) src_mac;
   Bit#(48) dst_mac;
} PacketFieldIn deriving (Bits, Eq);

instance DefaultValue#(PacketFieldIn);
   defaultValue =
   PacketFieldIn {
      src_mac : 0,
      dst_mac : 0
   };
endinstance

// Generate interface to next match table
typedef struct {
   Bit#(48) src_mac;
   Bit#(48) dst_mac;
} PacketFieldOut deriving (Bits, Eq);

instance DefaultValue#(PacketFieldOut);
   defaultValue =
   PacketFieldOut {
      src_mac : 0,
      dst_mac : 0
   };
endinstance

// Action Types

interface ActionEngineIfc;
   interface Put#(PacketFieldIn) actionPacketIn;
   interface PipeIn#(ActionEntry) actionIn;
   interface PipeOut#(PacketFieldOut) actionOut;
endinterface

(* synthesize *)
module mkSimpleActionEngine(ActionEngineIfc);
   FIFOF#(ActionEntry) fifo_in_action <- mkSizedFIFOF(1);
   FIFOF#(PacketFieldIn) fifo_in <- mkSizedFIFOF(1);
   FIFOF#(PacketFieldOut) fifo_out <- mkSizedFIFOF(1);
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
   // swap mac address
   rule swap_mac_address if (fifo_out.notFull);
      let v <- toGet(fifo_in).get;
      PacketFieldOut vout = defaultValue;
      vout.src_mac = v.dst_mac;
      vout.dst_mac = v.src_mac;
      fifo_out.enq(vout);
   endrule

   interface Put actionPacketIn;
      method Action put(PacketFieldIn p) if (fifo_in.notFull);
         fifo_in.enq(p);
      endmethod
   endinterface
   interface PipeIn actionIn = toPipeIn(fifo_in_action);
   interface PipeOut actionOut = toPipeOut(fifo_out);
endmodule
