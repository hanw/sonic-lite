
(* always_ready, always_enabled *)
interface DE5Pins;
   method Action osc_50(Bit#(1) b3d, Bit#(1) b4a, Bit#(1) b4d, Bit#(1) b7a, Bit#(1) b7d, Bit#(1) b8a, Bit#(1) b8d);
   method Action user(Bit#(1) reset_n);
   method Action sfp(Bit#(1) refclk);
   method Bit#(4) serial_tx_data;
   method Action serial_rx(Bit#(4) data);
   interface Clock deleteme_unused_clock;
   interface Clock deleteme_unused_clock2;
   interface Clock deleteme_unused_clock3;
   interface Reset deleteme_unused_reset;
endinterface

