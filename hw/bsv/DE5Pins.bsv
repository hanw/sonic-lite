import Clocks::*;
import Vector::*;

import ConnectalClocks::*;
import LedController::*;
import PushButtonController::*;

import AlteraExtra::*;
import ALTERA_SI570_WRAPPER::*;

(* always_ready, always_enabled *)
interface DE5Pins;
`ifndef SIMULATION
   method Action osc_50(Bit#(1) b3d, Bit#(1) b4a, Bit#(1) b4d, Bit#(1) b7a, Bit#(1) b7d, Bit#(1) b8a, Bit#(1) b8d);
   method Action sfp(Bit#(1) refclk);
   method Bit#(4) serial_tx_data;
   method Action serial_rx(Bit#(4) data);
   method Bit#(1) led0;
   method Bit#(1) led1;
   method Bit#(1) led2;
   method Bit#(1) led3;
   method Bit#(4) led_bracket;
   method Action buttons(Vector#(4, Bit#(1)) v);
   interface Si570wrapI2c i2c;
   interface De5SfpCtrl#(4) sfpctrl;
   interface Clock deleteme_unused_clock;
   interface Clock deleteme_unused_clock2;
   interface Clock deleteme_unused_clock3;
   interface Reset deleteme_unused_reset;
`endif
endinterface

interface De5Clocks;
   interface Si570wrapI2c i2c;
   interface Clock clock_50;
   interface Reset reset_50_n;
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
   Reset rst_50_n <- mkAsyncReset(2, defaultReset, iclock_50.c);
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
   Si570Wrap si570 <- mkSi570Wrap(iclock_50.c, rst_50_n, clocked_by iclock_50.c, reset_by rst_50_n);

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
   interface reset_50_n = rst_50_n;
   interface clock_156_25 = clk_156_25;
   interface reset_156_25_n = rst_156_n;
   interface clock_644_53 = iclock_644.c;
endmodule

interface De5Leds;
   method Bit#(1) led0_out;
   method Bit#(1) led1_out;
   method Bit#(1) led2_out;
   method Bit#(1) led3_out;
endinterface

module mkDe5Leds#(Clock clk0, Clock clk1, Clock clk2, Clock clk3)(De5Leds);
   Clock defaultClock <- exposeCurrentClock;
   Reset defaultReset <- exposeCurrentReset;

   Reset reset0 <- mkSyncReset(2, defaultReset, clk0);
   Reset reset1 <- mkSyncReset(2, defaultReset, clk1);
   Reset reset2 <- mkSyncReset(2, defaultReset, clk2);
   Reset reset3 <- mkSyncReset(2, defaultReset, clk3);

   LedController led0 <- mkLedController(False, clocked_by clk0, reset_by reset0);
   LedController led1 <- mkLedController(False, clocked_by clk1, reset_by reset1);
   LedController led2 <- mkLedController(False, clocked_by clk2, reset_by reset2);
   LedController led3 <- mkLedController(False, clocked_by clk3, reset_by reset3);

   rule led0_run;
      led0.setPeriod(led_off, 500, led_on_max, 500);
   endrule

   rule led1_run;
      led1.setPeriod(led_off, 500, led_on_max, 500);
   endrule

   rule led2_run;
      led2.setPeriod(led_off, 500, led_on_max, 500);
   endrule

   rule led3_run;
      led3.setPeriod(led_off, 500, led_on_max, 500);
   endrule

   method led0_out = led0.ifc.out;
   method led1_out = led1.ifc.out;
   method led2_out = led2.ifc.out;
   method led3_out = led3.ifc.out;
endmodule

interface De5SfpCtrl#(numeric type nPorts);
   method Action los (Vector#(nPorts, Bit#(1)) v);
   method Action mod0_presnt_n (Vector#(nPorts, Bit#(1)) v);
   method Action txfault (Vector#(nPorts, Bit#(1)) v);
   // SCL/SDA not implemented
   method Vector#(nPorts, Bit#(1)) ratesel0;
   method Vector#(nPorts, Bit#(1)) ratesel1;
   method Vector#(nPorts, Bit#(1)) txdisable;
endinterface

module mkDe5SfpCtrl(De5SfpCtrl#(nPorts));
   Vector#(nPorts, Wire#(Bit#(1))) los_wire <- replicateM(mkDWire(0));
   Vector#(nPorts, Wire#(Bit#(1))) mod0_presnt_n_wire <- replicateM(mkDWire(0));
   Vector#(nPorts, Wire#(Bit#(1))) txfault_wire <- replicateM(mkDWire(0));
   Vector#(nPorts, Wire#(Bit#(1))) ratesel0_wire <- replicateM(mkDWire(0));
   Vector#(nPorts, Wire#(Bit#(1))) ratesel1_wire <- replicateM(mkDWire(0));
   Vector#(nPorts, Wire#(Bit#(1))) txdisable_wire <- replicateM(mkDWire(0));

   for (Integer i=0; i<valueOf(nPorts); i=i+1) begin
      rule set_output;
         ratesel0_wire[i] <= 1'b1;
         ratesel1_wire[i] <= 1'b1;
         txdisable_wire[i] <= 1'b0;
      endrule
   end

   method los = writeVReg(los_wire);
   method mod0_presnt_n = writeVReg(mod0_presnt_n_wire);
   method txfault = writeVReg(txfault_wire);
   method ratesel0 = readVReg(ratesel0_wire);
   method ratesel1 = readVReg(ratesel1_wire);
   method txdisable = readVReg(txdisable_wire);
endmodule

interface De5Buttons#(numeric type nButtons);
   method Action pins(Vector#(nButtons, Bit#(1)) v);
   method Vector#(nButtons, Bool) pressed;
endinterface

module mkDe5Buttons(De5Buttons#(nButtons));
   Clock defaultClock <- exposeCurrentClock;
   Reset defaultReset <- exposeCurrentReset;
   Vector#(nButtons, Wire#(Bit#(1))) button_in <- replicateM(mkDWire(0));
   Vector#(nButtons, Wire#(Bool)) button_pressed <- replicateM(mkDWire(False));

   Vector#(4, PushButtonController) buttons <- replicateM(mkPushButtonController(defaultClock));
   for (Integer i=0; i<valueOf(nButtons); i=i+1) begin
      rule setPushButtonInput;
         buttons[i].ifc.button(button_in[i]);
      endrule

      rule setPushButtonParam;
         buttons[i].setRepeatParams(10, 10);
      endrule

      rule setPushButtonOutput;
         button_pressed[i] <= buttons[i].pressed;
      endrule
   end

   method pins = writeVReg(button_in);
   method pressed = readVReg(button_pressed);
endmodule
