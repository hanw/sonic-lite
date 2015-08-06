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

package PacketBuffer;

import Clocks::*;
import Vector::*;
import GetPut::*;
import BRAM::*;
import Connectable::*;
import Pipe::*;

typedef 12  PktAddrWidth;
typedef 128 PktDataWidth;

interface PktBuffIfc;
   interface PipeIn#(Bit#(PktDataWidth)) write;
   interface PipeOut#(Bit#(PktDataWidth)) read;
endinterface

module mkPacketBuffer(PktBuffIfc);
   Clock current_clock <- exposeCurrentClock;
   Reset current_reset <- exposeCurrentReset;

   // Memory
   BRAM_Configure bramConfig = defaultValue;
   bramConfig.latency = 2;
   BRAM2Port#(Bit#(PktAddrWidth), Bit#(PktDataWidth)) memBuffer <- mkBRAM2Server(bramConfig);

   //TODO: identify packet boundary


endmodule
endpackage: PacketBuffer
