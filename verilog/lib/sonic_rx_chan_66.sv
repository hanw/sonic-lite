//                              -*- Mode: Verilog -*-
// Filename        : sonic_rx_chan_66.sv
// Description     : combines gearbox, blocksync, and cbuf.
//                   implement logic to indicate amount of available data.
// Author          : Han Wang
// Created On      : Sat Nov 26 15:27:23 2011
// Last Modified By: Han Wang
// Last Modified On: Sat Nov 26 15:27:23 2011
// Update Count    : 0
// Status          : Unknown, Use with caution!

module sonic_rx_chan_66 (/*AUTOARG*/
   // Outputs
   data_out, lock,
   // Inputs
   data_in, rd_clock, wr_clock, reset, xcvr_rx_ready
   ) ;

   input [39:0] data_in;
   input        rd_clock;
   input        wr_clock;
   input        reset;

   input        xcvr_rx_ready;
   output [65:0] data_out;
   output       lock;

   logic [65:0] gearbox_data_out;

   logic        gearbox_valid;
   logic        blocksync_lock;

   logic [65:0] blocksync_data_out;

   parameter WIDTH = 64;

   /* 
   * Altera gearbox 
   */
/*
   gearbox_40_66 gearbox (
      .clk(wr_clock),
      .slip_to_frame(1'b0),
      .din(data_in),
      .dout(gearbox_data_out),
      .dout_valid(gearbox_valid),
      .slipping(),
      .word_locked()
   );
*/

   sonic_gearbox_40_66 gearbox (.data_in(data_in),
      .clk_in(wr_clock),
      .reset(reset),
      .data_out(gearbox_data_out),
      .data_valid(gearbox_valid)
   );

   logic gearbox_valid_r;
  
   always_ff @(posedge wr_clock) begin
      gearbox_valid_r <= gearbox_valid;
   end

   /*
    * blocksync
    */
   sonic_blocksync_xg blocksync (.data_in(gearbox_data_out),
				                     .clk(wr_clock),
				                     .reset(reset),
				                     .valid(gearbox_valid),
				                     .data_out(blocksync_data_out),
				                     .block_lock(blocksync_lock)
				                     );
   /*
   * Altera Descrambler
   */
   logic [WIDTH-1:0] recover_out;
   descrambler #(.WIDTH(WIDTH)) descram (
      .clk(wr_clock),
      .arst(reset),
      .ena(gearbox_valid_r),
      .din(blocksync_data_out[65:2]),
      .dout(recover_out)
   );

   logic [1:0] sync_header;
   always_ff @(posedge wr_clock) begin
      sync_header <= blocksync_data_out[1:0];
   end

   logic [65:0] data_out_wr;
   assign data_out_wr = {recover_out, sync_header};
   assign lock = blocksync_lock;

   /* CDC for descrambled data */
   fifo fifo(
      .aclr(reset),
      .data(data_out_wr),
      .rdclk(rd_clock),
      .rdreq(blocksync_lock),
      .wrclk(wr_clock),
      .wrreq(gearbox_valid_r & xcvr_rx_ready),
      .q(data_out),
      .rdempty(),
      .wrfull()
   );

endmodule // sonic_rx_chan_66
