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

import Vector      :: *;
import Clocks      :: *;
import DefaultValue ::*;
import GetPut      :: *;
import FIFO        :: *;
import BRAMFIFO    :: *;
//import Pipe::*;
import Parser      :: *;
import Types    :: *;

interface NicPins;
   method Action osc_50(Bit#(1) b3d, Bit#(1) b4a, Bit#(1) b4d, Bit#(1) b7a, Bit#(1) b7d, Bit#(1) b8a, Bit#(1) b8d);
   (* prefix="" *)
   method Action user_reset_n(Bit#(1) user_reset_n);
endinterface

interface NicTopIndication;
   method Action sonic_read_version_resp(Bit#(32) version);
endinterface

interface NicTopRequest;
   method Action sonic_read_version();
   method Action sonic_start_parsing();
   method Action writePacketData(Bit#(64) data_hi, Bit#(64) data_lo, Bit#(1) sop, Bit#(1) eop);
endinterface

interface NicTop;
   interface NicTopRequest request;
   interface NicPins pins;
endinterface

//`define ENABLE_PCIE
module mkNicTop#(Clock derivedClock, Reset derivedReset, NicTopIndication indication)(NicTop);
   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

   Parser pr <- mkParser();

   interface NicTopRequest request;
      method Action sonic_read_version();
         let v= `NicVersion;
         indication.sonic_read_version_resp(v);
      endmethod
      method Action sonic_start_parsing();
         EtherData beat = defaultValue;
         pr.startParse(beat);
      endmethod
      method Action writePacketData(Bit#(64) dataHi, Bit#(64) dataLo, Bit#(1) sop, Bit#(1) eop);
         EtherData beat = defaultValue;
         beat.data = {dataHi, dataLo};
         beat.sop = unpack(sop);
         beat.eop = unpack(eop);
         pr.enqPacket(beat);
      endmethod
   endinterface
   interface NicPins pins;
   endinterface
endmodule
