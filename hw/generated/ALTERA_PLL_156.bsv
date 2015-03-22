
/*
   /home/hwang/dev/sonic-lite/hw/scripts/../../../connectal//generated/scripts/importbvi.py
   -o
   ALTERA_PLL_156.bsv
   -I
   PLL156
   -P
   PLL156
   -c
   refclk
   -r
   rst
   -c
   outclk_0
   ../verilog/pll/pll_156/pll_156.v
*/

import Clocks::*;
import DefaultValue::*;
import GetPut::*;

(* always_ready, always_enabled *)
interface PLL156;
    interface Clock    outclk0;
endinterface

import "BVI" pll_156 =
module mkPLL156#(Clock refclk, Reset refclk_reset)(PLL156);
   default_clock clk();
   default_reset rst();
   input_clock refclk(refclk) = refclk;
   input_reset refclk_reset(rst) = refclk_reset; /* from clock*/
   output_clock outclk0(outclk_0);
endmodule

