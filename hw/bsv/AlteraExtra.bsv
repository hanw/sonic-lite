package AlteraExtra;

import Clocks ::*;

(* always_ready, always_enabled *)
interface AltClkCtrl;
    interface Clock     outclk;
endinterface
import "BVI" altera_clkctrl =
module mkAltClkCtrl#(Clock inclk)(AltClkCtrl);
    default_clock no_clock;
    no_reset;
    input_clock inclk(inclk) = inclk;
    output_clock outclk(outclk);
endmodule

(* always_ready, always_enabled *)
interface PLL644;
    interface Clock       outclk_0;
endinterface
import "BVI" pll_644 =
module mkPLL644#(Clock refclk, Reset rst)(PLL644);
    default_clock no_clock;
    no_reset;
    input_clock refclk(refclk) = refclk;
    input_reset rst(rst) clocked_by (refclk) = rst;
    output_clock outclk_0(outclk_0);
endmodule

(* always_ready, always_enabled *)
interface PLL156;
    interface Clock       outclk_0;
endinterface
import "BVI" pll_156 =
module mkPLL156#(Clock refclk, Reset rst)(PLL156);
    default_clock no_clock;
    no_reset;
    input_clock refclk(refclk) = refclk;
    input_reset rst(rst) clocked_by (refclk) = rst;
    output_clock outclk_0(outclk_0);
endmodule


endpackage: AlteraExtra
