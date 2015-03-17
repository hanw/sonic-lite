
/*
   /home/hwang/dev/sonic-lite/hw/scripts/../../../connectal//generated/scripts/importbvi.py
   -o
   ALTERA_PLL_644.bsv
   -I
   PLL644
   -P
   PLL644
   -c
   refclk
   -r
   rst
   -c
   outclk_0
   ../verilog/pll/pll_644/pll_644.v
*/

import Clocks::*;
import DefaultValue::*;
import GetPut::*;

(* always_ready, always_enabled *)
interface PLL644;
    method Bit#(1)  locked();
    interface Clock outclk;
endinterface

import "BVI" pll_644 =
module mkPLL644#(Clock refclk, Reset refclk_reset)(PLL644);
   default_clock clk();
   default_reset rst();
   input_clock refclk(refclk) = refclk;
   input_reset refclk_reset(rst) = refclk_reset; /* from clock*/
   method locked locked();
   output_clock outclk(outclk_0);
   schedule (locked) CF (locked);
endmodule
