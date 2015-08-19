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

import StmtFSM::*;
import Types::*;

interface Parser;
   method Action startParse(EtherData d);
   method Action enqPacket(EtherData b);
endinterface

(* synthesize *)
module mkParser(Parser);

   Reg#(Bit#(32)) cycle <- mkReg(0);
   Reg#(Bool) notStarted <- mkReg(False);

   rule every;
      cycle <= cycle + 1;
   endrule

   // One Stmt that says it all
   Stmt parseSeq =
   seq
   // Actions are pipelined
   action
      // let data <- extract_l2_fifo();
      $display("%d: extract dst mac 6 bytes = 48 bits", cycle);
      $display("%d: extract src mac 6 bytes = 48 bits", cycle);
      $display("%d: extract type = 2 bytes = 16 bits", cycle);
      //Bit#(48) dst_mac = xxx;
      //Bit#(48) src_mac = xxx;
      //Bit#(16) type = xxx;
      // use data in table ??
   endaction
   action
      // let data <- extract_l3_fifo();
      $display("%d: extract ip", cycle);
   endaction
   endseq;

   // control parsing FSM
   FSM parseFSM <- mkFSM(parseSeq);
   Once parseOnce <- mkOnce(parseFSM.start);

   rule parse_starts(notStarted);
      parseOnce.start;
      notStarted <= False;
   endrule

   method Action startParse(EtherData d);
      notStarted <= True;
   endmethod

   method Action enqPacket(EtherData b);
      // store packet header to be parsed
      // store 128/256 bit at a time.
      // A typical packet would take 8 to 10 cycles to receive headers
   endmethod
endmodule

