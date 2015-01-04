//                              -*- Mode: Verilog -*-
// Filename        : sonic_rxtx_loopback.sv
// Description     : loopback circuitry before 40bit pma interface
//                   RxChan <--- loopback ---|
//                   TxChan ---> loopback ---|
// Author          : Han Wang
// Created On      : Sun Nov 27 17:30:06 2011
// Last Modified By: Han Wang
// Last Modified On: Sun Nov 27 17:30:06 2011
// Update Count    : 0
// Status          : Unknown, Use with caution!

module sonic_rxtx_loopback (/*AUTOARG*/
   // Outputs
   data_out_xcvr, data_out_chan,
   // Inputs
   clk_in, reset, loopback_en, data_in_chan, data_in_xcvr
   ) ;

   input clk_in;
   input reset;
   input loopback_en;
   input [39:0] data_in_chan;
   input [39:0] data_in_xcvr;
   output [39:0] data_out_xcvr;
   output [39:0] data_out_chan;

   logic         loopback_reg;

   always @ ( posedge clk_in or posedge reset) begin
      if (reset)
	     loopback_reg <= 0;
      else if (loopback_en)
	     loopback_reg <= 1;
      else
	     loopback_reg <= 0;
   end
   
   assign data_out_chan = (loopback_reg == 1) ? data_in_chan : data_in_xcvr;
   assign data_out_xcvr = (loopback_reg == 1) ? data_in_xcvr : data_in_chan;
   
endmodule // sonic_rxtx_loopback
