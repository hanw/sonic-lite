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

package DTP;

`ifdef USE_4_CHANNELS
typedef 4 N_CHAN;
`elsif USE_2_CHANNELS
typedef 2 N_CHAN;
`endif

interface DTP#(numeric type np);
   method Vector#(np, Bit#(54)) local_clock;
   method Bit#(54) global_clock;
endinterface

(* synthesize *)
module mkDTP#(Clock clk_156_25, Reset rst_156_25)(DTP#(N_CHAN));
   DtpGlobalWrap dtpg <- mkDtpGlobalWrap(clk_156_25, rst_156_25, rst_156_25);

   interface DTP;
      method Vector#(N_CHAN, Bit#(54)) local_clock;
         Vector#(N_CHAN, Bit#(54)) cnt;
         for (Integer i=0; i < N_CHAN; i=i+1) begin
            cnt[i] = dtpg.
         end
      endmethod
   endinterface
endmodule

endpackage
