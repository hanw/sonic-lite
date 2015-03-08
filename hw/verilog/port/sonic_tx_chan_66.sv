//                              -*- Mode: Verilog -*-
// Filename        : sonic_tx_chan_66.sv
// Description     : combines tx_cbuf and gearbox_66_40
// Author          : Han Wang
// Created On      : Sat Nov 26 22:35:34 2011
// Last Modified By: Han Wang
// Last Modified On: Sat Nov 26 22:35:34 2011
// Update Count    : 0
// Status          : Unknown, Use with caution!

module sonic_tx_chan_66 (/*AUTOARG*/
   // Outputs
   data_out,
   // Inputs
   data_in, rd_clock, wr_clock, reset, xcvr_tx_ready
   ) ;

   input [65:0] data_in;
   output [39:0] data_out;
   input 	 rd_clock;
   input 	 wr_clock;
   input 	 reset;
   input 	 xcvr_tx_ready;
   
   logic 	 gearbox_ena;


   logic empty;
   logic [65:0] fifo_data_out;
   logic gearbox_rdreq, gearbox_rdreq2, gearbox_rdreq3;

   fifo fifo(
      .aclr(reset),
      .data(data_in),
      .rdclk(rd_clock),
      .rdreq(gearbox_rdreq3 & xcvr_tx_ready),
      .wrclk(wr_clock),
      .wrreq(xcvr_tx_ready),
      .q(fifo_data_out),
      .rdempty(),
      .wrfull()
   );

   //assign fifo_data_out = 66'h00000000000000079;

   logic [63:0] altera_scram_out;
   logic [65:0] scram_out;
   logic xcvr_tx_ready_r;

   scrambler # (.WIDTH(64)) scram (
      .clk(rd_clock),
      .arst(reset),
      .ena(gearbox_rdreq2 & xcvr_tx_ready_r),
      .din(fifo_data_out[65:2]),
      .dout(altera_scram_out)
   );

   logic [1:0] sync_header;
   always_ff @ (posedge wr_clock) begin
      sync_header <= fifo_data_out[1:0];
      xcvr_tx_ready_r <= xcvr_tx_ready;
   end

   assign scram_out = {altera_scram_out, sync_header};

   gearbox_66_40 gearbox (
      .clk(rd_clock),
      .sclr(reset & ~xcvr_tx_ready_r),
      .din(scram_out),
      .din_ack(gearbox_rdreq),
      .din_pre_ack(gearbox_rdreq2),
      .din_pre2_ack(gearbox_rdreq3),
      .dout(data_out)
   );

   /*
   * Altera Scrambler
   */
//   logic [63:0] altera_scram_out;
//   logic [65:0] scram_out;
//   scrambler # (.WIDTH(64)) scram (
//      .clk(wr_clock),
//      .arst(reset),
//      .ena(1'b1),
//      .din(data_in[65:2]),
//      .dout(altera_scram_out)
//   );
//
//   logic [1:0] sync_header;
//   always_ff @ (posedge wr_clock) begin
//      sync_header <= data_in[1:0];
//   end
//
//   assign scram_out = {altera_scram_out, sync_header};
//
//   /* CDC */
//   logic [65:0] fifo_out;
//   logic gearbox_rdreq, gearbox_rdreq2, gearbox_rdreq3;
//   /* CDC for scrambled data */
//   async_fifo fifo (
//      .i_reset(reset),
//      .i_wdata(scram_out),
//      .i_wclk(wr_clock),
//      .i_push(xcvr_tx_ready),
//      .i_rclk(rd_clock),
//      .i_pop(gearbox_rdreq & xcvr_tx_ready),
//      .o_rdata(fifo_out),
//      .o_full(),
//      .o_empty()
//   );
//
//   /*
//   * Altera Gearbox
//   */
//   gearbox_66_40 gearbox (
//      .clk(rd_clock),
//      .sclr(reset),
//      .din(fifo_out),
//      .din_ack(gearbox_rdreq),
//      .din_pre_ack(gearbox_rdreq2),
//      .din_pre2_ack(gearbox_rdreq3),
//      .dout(data_out)
//   );

endmodule // sonic_tx_chan_66

