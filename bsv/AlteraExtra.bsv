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

endpackage: AlteraExtra
