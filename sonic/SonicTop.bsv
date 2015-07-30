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

import Top                ::*;
import Portal             ::*;
import PcieHost           ::*;
`ifndef BSIM
import PcieTop            ::*;
`endif
import SonicUser          ::*;
import HostInterface      ::*;

`ifndef PinType
`define PinType Empty
`endif
typedef `PinType PinType;

interface SonicTopIfc;
`ifndef BSIM
   interface PcieTop#(PinType) pcie;
`endif
endinterface

(* synthesize, no_default_clock, no_default_reset *)
(* clock_prefix="", reset_prefix="" *)
module mkSonicTop #(Clock pcie_refclk_p,
                    Clock osc_50_b3b,
                    Clock osc_50_b3d,
                    Clock osc_50_b4a,
                    Clock osc_50_b4d,
                    Clock osc_50_b7a,
                    Clock osc_50_b7d,
                    Clock osc_50_b8a,
                    Clock osc_50_b8d,
                    //Clock sfp_refclk,
                    Reset pcie_perst_n,
                    Reset user_reset_n)(SonicTopIfc);

`ifdef ALTERA
   PcieTop#(PinType) pcie_top <- mkPcieTop(pcie_refclk_p, osc_50_b3b, pcie_perst_n);
`endif

   // packet buffer

`ifndef BSIM
   interface pcie = pcie_top;
`endif
endmodule
