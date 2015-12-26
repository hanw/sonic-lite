import Clocks::*;
import ConnectalClocks::*;

import Ethernet::*;
import AlteraExtra::*;
import ALTERA_SI570_WRAPPER::*;

(* always_ready, always_enabled *)
interface DE5Pins;
`ifndef SIMULATION
   method Action osc_50(Bit#(1) b3d, Bit#(1) b4a, Bit#(1) b4d, Bit#(1) b7a, Bit#(1) b7d, Bit#(1) b8a, Bit#(1) b8d);
   method Action buttons(Bit#(4) v);
   method Action sfp(Bit#(1) refclk);
   interface SFPCtrl#(4) sfpctrl;
   method Bit#(4) serial_tx_data;
   method Action serial_rx(Bit#(4) data);
   method Bit#(1) led0;
   method Bit#(1) led1;
   method Bit#(1) led2;
   method Bit#(1) led3;
   method Bit#(4) led_bracket;
   interface Si570wrapI2c i2c;
   interface Clock deleteme_unused_clock;
   interface Clock deleteme_unused_clock2;
   interface Clock deleteme_unused_clock3;
   interface Reset deleteme_unused_reset;
`endif
endinterface

interface De5Clocks;
   interface Si570wrapI2c i2c;
   interface Clock clock_50;
   interface Clock clock_156_25;
   interface Reset reset_156_25_n;
   interface Clock clock_644_53;
endinterface

module mkDe5Clocks#(Bit#(1) clk_50, Bit#(1) clk_644)(De5Clocks);
   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

   B2C1 iclock_50 <- mkB2C1();
   B2C1 iclock_644 <- mkB2C1();

   //Reset reset_50 <- mkResetInverter(reset_n, clocked_by clk_50_b4a_buf.outclk);
   Reset reset_50_n <- mkAsyncReset(2, defaultReset, iclock_50.c);
   Reset reset_644 <- mkResetInverter(defaultReset, clocked_by iclock_644.c);
   //Reset reset_644_53_n <- mkAsyncReset(2, reset_n, sfp_refclk);

   // ===================================
   // PLL:
   // Input:   SFP REFCLK from SI570
   // Output:  156.25MHz
   // Reset: Active High, must invert default Reset
   PLL156 pll156 <- mkPLL156(iclock_644.c, reset_644, clocked_by iclock_644.c, reset_by reset_644);
   Clock clk_156_25 = pll156.outclk_0;
   Reset rst_156   <- mkResetInverter(defaultReset, clocked_by clk_156_25);
   Reset rst_156_n <- mkAsyncReset(2, defaultReset, clk_156_25, clocked_by clk_156_25);

   // ===================================
   // PLL: SI570 configurable clock
   // Input:
   // Output:
   // Reset: Active Low, use default Reset
   Si570Wrap si570 <- mkSi570Wrap(iclock_50.c, reset_50_n, clocked_by iclock_50.c, reset_by reset_50_n);

   rule si570_connections;
      let ifreq_mode = 3'b110;  //644.53125 MHZ
      si570.ifreq.mode(ifreq_mode);
      si570.istart.go(1'b0);
   endrule

   rule input_clock_50;
      iclock_50.inputclock(clk_50);
   endrule

   rule input_clock_644;
      iclock_644.inputclock(clk_644);
   endrule

   interface i2c = si570.i2c;
   interface clock_50 = iclock_50.c;
   interface clock_156_25 = clk_156_25;
   interface reset_156_25_n = rst_156_n;
   interface clock_644_53 = iclock_644.c;
endmodule
