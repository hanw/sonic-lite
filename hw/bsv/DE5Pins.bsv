import Ethernet::*;

(* always_ready, always_enabled *)
interface DE5Pins;
   method Action osc_50(Bit#(1) b3d, Bit#(1) b4a, Bit#(1) b4d, Bit#(1) b7a, Bit#(1) b7d, Bit#(1) b8a, Bit#(1) b8d);
   method Action sfp(Bit#(1) refclk);
   method Action buttons(Bit#(4) v);
   interface SFPCtrl#(4) sfpctrl;
`ifdef DEBUG_ETH
   method Bit#(4) serial_tx_data;
   method Action serial_rx(Bit#(4) data);
   method Bit#(1) led0;
   method Bit#(1) led1;
`endif
   method Bit#(1) led2;
   method Bit#(1) led3;
   method Bit#(4) led_bracket;
`ifndef BSIM
   interface Clock deleteme_unused_clock;
   interface Clock deleteme_unused_clock2;
   interface Clock deleteme_unused_clock3;
   interface Reset deleteme_unused_reset;
`endif
endinterface

