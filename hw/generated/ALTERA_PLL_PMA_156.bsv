
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
   ../verilog/pll/pll_pma/pll_pma.v
*/

import Clocks::*;
import DefaultValue::*;
import GetPut::*;

(* always_ready, always_enabled *)
interface PllPma;
    interface Clock    outclk0;
endinterface

import "BVI" pll_pma =
module mkPllPma#(Clock refclk, Reset refclk_reset)(PllPma);
   default_clock clk();
   default_reset rst();
   input_clock refclk(refclk_clk) = refclk;
   input_reset refclk_reset(rst_reset) = refclk_reset; /* from clock*/
   output_clock outclk0(outclk_0_clk);
endmodule

