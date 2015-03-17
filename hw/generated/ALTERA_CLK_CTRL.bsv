
/*
   /home/hwang/dev/sonic-lite/hw/scripts/../../../connectal//generated/scripts/importbvi.py
   -o
   ALTERA_CLK_CTRL.bsv
   -I
   AltClkCtrl
   -P
   AltClkCtrl
   -c
   inclk
   -c
   outclk
   ../verilog/pll/altera_clkctrl/synthesis/altera_clkctrl.v
*/

import Clocks::*;
import DefaultValue::*;
import XilinxCells::*;
import GetPut::*;

(* always_ready, always_enabled *)
interface AltClkCtrl#(numeric type wire);
    interface Clock     outclk;
endinterface
import "BVI" altera_clkctrl =
module mkAltClkCtrl#(Clock inclk, Reset inclk_reset)(AltClkCtrl#(wire));
    let wire = valueOf(wire);
    default_clock clk();
    default_reset rst();
    input_clock inclk(inclk) = inclk;
    input_reset inclk_reset() = inclk_reset; /* from clock*/
    output_clock outclk(outclk);
endmodule
