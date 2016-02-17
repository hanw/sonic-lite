import Clocks::*;
import Vector::*;
import DefaultValue::*;

import XilinxCells::*;
import LedController::*;
import ConnectalClocks::*;
import ConnectalXilinxCells::*;

(* always_ready, always_enabled *)
interface NfsumePins;
`ifndef SIMULATION
   method Action sfp(Bit#(1) refclk_p, Bit#(1) refclk_n);
   method Bit#(2) leds;
   method Bit#(4) serial_tx_p;
   method Bit#(4) serial_tx_n;
   method Action serial_rx_p(Vector#(4, Bit#(1)) v);
   method Action serial_rx_n(Vector#(4, Bit#(1)) v);
   interface Clock deleteme_unused_clock;
`endif
endinterface

interface NfsumeLeds;
   method Bit#(2) led_out;
endinterface

module mkNfsumeLeds#(Clock clk0, Clock clk1)(NfsumeLeds);
   Clock defaultClock <- exposeCurrentClock;
   Reset defaultReset <- exposeCurrentReset;

   Reset reset0 <- mkSyncReset(2, defaultReset, clk0);
   Reset reset1 <- mkSyncReset(2, defaultReset, clk1);

   LedController led0 <- mkLedController(False, clocked_by clk0, reset_by reset0);
   LedController led1 <- mkLedController(False, clocked_by clk1, reset_by reset1);

   rule led0_run;
      led0.setPeriod(led_off, 500, led_on_max, 500);
   endrule

   rule led1_run;
      led1.setPeriod(led_off, 500, led_on_max, 500);
   endrule

   method led_out = {
                     led1.ifc.out,
                     led0.ifc.out
                     };
endmodule

//(* synthesize *)
//module mkNfsumeClocks#(Clock sys_clk)(NfsumeClocks);
//`ifndef SIMULATION
//   ClockGenerator7AdvParams clockParams = defaultValue;
//   clockParams.bandwidth          = "OPTIMIZED";
//   clockParams.compensation       = "ZHOLD";
//   clockParams.clkfbout_mult_f    = 9.375;
//   clockParams.clkfbout_phase     = 0.0;
//   clockParams.clkin1_period      = 5.000;
//   clockParams.clkin2_period      = 10.0;
//   clockParams.clkout0_divide_f   = 18.75;
//   clockParams.clkout0_duty_cycle = 0.5;
//   clockParams.clkout0_phase      = 0.0000;
//   clockParams.clkout1_divide     = 6;
//   clockParams.clkout1_duty_cycle = 0.5;
//   clockParams.clkout1_phase      = 0.0000;
//   clockParams.divclk_divide      = 2;
//   clockParams.ref_jitter1        = 0.010;
//   clockParams.ref_jitter2        = 0.010;
//   XClockGenerator7 clockGen <- mkClockGenerator7Adv(clockParams, clocked_by sys_clk);
//   C2B c2b_fb <- mkC2B(clockGen.clkfbout, clocked_by clockGen.clkfbout);
//   rule txoutrule5;
//      clockGen.clkfbin(c2b_fb.o());
//   endrule
//   Clock clk_50 <- mkClockBUFG(clocked_by clockGen.clkout0); // 156.25 MHz
//   Clock clk_156_25 <- mkClockBUFG(clocked_by clockGen.clkout1);    // 50 MHz
//`else
//
//   Clock defaultClock <- exposeCurrentClock();
//   interface clock_50 = defaultClock;
//   interface clock_156_25 = defaultClock;
//`endif
//   interface clock_50 = clk_50;
//   interface clock_156_25 = clk_156_25;
//endmodule
