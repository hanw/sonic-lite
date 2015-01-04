//                              -*- Mode: Verilog -*-
// Filename        : sonic_single_port.sv
// Description     : basic PHY with gearbox and blocksync
// Author          : Han Wang
// Created On      : Fri Apr 25 21:17:48 2014
// Last Modified By: Han Wang
// Last Modified On: Fri Apr 25 21:17:48 2014
// Update Count    : 0
// Status          : initial design for OSDI

module sonic_single_port (/*AUTOARG*/
   // Outputs
   xcvr_tx_dataout, c_local, xgmii_rx_data, export_data, export_valid,
   export_delay,
   // Inputs
   xcvr_rx_datain, xcvr_tx_clkout, xcvr_rx_clkout, xcvr_tx_ready,
   xcvr_rx_ready, bypass, clksync_disable, clear, mode,
   disable_filter, thres, c_global, xgmii_tx_data, xgmii_clock, reset,
   endec_loopback, init_timeout, sync_timeout
   ) ;

   // lower layer xcvr interface
   output [39:0]  xcvr_tx_dataout;
   input [39:0]   xcvr_rx_datain;
   input          xcvr_tx_clkout;
   input          xcvr_rx_clkout;
   input          xcvr_tx_ready;
   input          xcvr_rx_ready;
   input          bypass; //bypass clocksync
   input          clksync_disable; //disable clocksync
   input          clear; //clear c_local counters
   input          mode; //0 for NIC mode, 1 for switch mode
   input          disable_filter;
   input [31:0]   thres;

   input [52:0]   c_global;
   output [52:0]  c_local;
   
   // upper layer xgmii interface
   input [71:0]   xgmii_tx_data;
   output [71:0]  xgmii_rx_data;

   output [511:0] export_data;
   output         export_valid;
   output [15:0]  export_delay;
   
   wire [63:0]    xgmii_txd;
   wire [7:0]     xgmii_txc;
   wire [63:0]    xgmii_rxd;
   wire [7:0]     xgmii_rxc;

   input          xgmii_clock;

   // system interface
   input          reset, endec_loopback;
   
   input [31:0]   init_timeout;
   input [31:0]   sync_timeout;

   logic          lock;
   logic [65:0]   encoded_datain, decoded_dataout, clksync_dataout, loopback_dataout;

   parameter INIT_TYPE=2'b01, ACK_TYPE=2'b10, BEACON_TYPE=2'b11;

   // xgmii data conversion
   assign xgmii_txc[7] = xgmii_tx_data[71];
   assign xgmii_txc[6] = xgmii_tx_data[62];
   assign xgmii_txc[5] = xgmii_tx_data[53];
   assign xgmii_txc[4] = xgmii_tx_data[44];
   assign xgmii_txc[3] = xgmii_tx_data[35];
   assign xgmii_txc[2] = xgmii_tx_data[26];
   assign xgmii_txc[1] = xgmii_tx_data[17];
   assign xgmii_txc[0] = xgmii_tx_data[8];
   assign xgmii_txd[63:56] = xgmii_tx_data[70:63];
   assign xgmii_txd[55:48] = xgmii_tx_data[61:54];
   assign xgmii_txd[47:40] = xgmii_tx_data[52:45];
   assign xgmii_txd[39:32] = xgmii_tx_data[43:36];
   assign xgmii_txd[31:24] = xgmii_tx_data[34:27];
   assign xgmii_txd[23:16] = xgmii_tx_data[25:18];
   assign xgmii_txd[15:8] = xgmii_tx_data[16:9];
   assign xgmii_txd[7:0] = xgmii_tx_data[7:0];

   assign xgmii_rx_data = {xgmii_rxc[7], xgmii_rxd[63:56],
                           xgmii_rxc[6], xgmii_rxd[55:48],
                           xgmii_rxc[5], xgmii_rxd[47:40],
                           xgmii_rxc[4], xgmii_rxd[39:32],
                           xgmii_rxc[3], xgmii_rxd[31:24],
                           xgmii_rxc[2], xgmii_rxd[23:16],
                           xgmii_rxc[1], xgmii_rxd[15:8],
                           xgmii_rxc[0], xgmii_rxd[7:0]};

   // Clock synchronisation layer
   // Use the link_fault_status, 00=No link fault, 01=Local Fault, 10=Remote Fault
   // if transceiver ready, assume link ok.
   // NOTE: this is not entirely safe, because we also need to make sure data in
   //       phy is valid (fifos, gearbox, etc). For testing purpose, we ignore the
   //       corner cases.
   clocksync_sm clocksync_sm (
                              .reset(reset || clksync_disable),
                              .clear(clear),
                              .mode(mode),
                              .disable_filter(disable_filter),
                              .thres(thres),
                              .clock(xgmii_clock),
                              .link_ok(xcvr_rx_ready && lock),
                              // axillary data saved to DDR3 ram
                              .export_data(export_data),
                              .export_valid(export_valid),
                              .export_delay(export_delay),

                              .c_global(c_global),
                              .c_local_o(c_local),
                              .encoded_datain(encoded_datain),  // data from encoder
                              .clksync_dataout(clksync_dataout), // data from clksync to txchan
                              .decoded_dataout(decoded_dataout), // data from decoder

                              .init_timeout(init_timeout),
                              .sync_timeout(sync_timeout)
                              );

   logic [65:0]   bypass_dataout;

   xgmii_mux mux_bypass (
                         .data0x(clksync_dataout),
                         .data1x(encoded_datain),
                         .data2x(),
                         .data3x(),
                         .sel({1'b0, bypass}),
                         .clock(xgmii_clock),
                         .result(bypass_dataout)
                         );

   // XGMII encoder
   encoder encoder_block (
                          .clk(xgmii_clock), 
                          .xgmii_txd(xgmii_txd), 
                          .xgmii_txc(xgmii_txc), 
                          .data_out(encoded_datain), 
                          .t_type(),
                          .init(reset), 
                          .enable(xcvr_tx_ready)
                          );

   // TX channel
   sonic_tx_chan_66 tx_chan (
                             .data_in(bypass_dataout),
                             .wr_clock(xgmii_clock),
                             .data_out(xcvr_tx_dataout),
                             .rd_clock(xcvr_tx_clkout),
                             .reset(reset),
                             .xcvr_tx_ready(xcvr_tx_ready)
                             );

   // XGMII decoder
   decoder decoder_block (
                          .clk(xgmii_clock),
                          .data_in(loopback_dataout),
                          .xgmii_rxd(xgmii_rxd), 
                          .xgmii_rxc(xgmii_rxc), 
                          .r_type(), 
                          .sync_lock(lock),
                          .init(reset), 
                          .idle_bus()
                          );
   
   // RX channel
   sonic_rx_chan_66 rx_chan (
                             .data_in(xcvr_rx_datain),
                             .wr_clock(xcvr_rx_clkout),
                             .data_out(decoded_dataout),
                             .rd_clock(xgmii_clock),
                             .reset(reset),
                             .lock(lock),
                             .xcvr_rx_ready(xcvr_rx_ready)
                             );

   // encoder to decoder loopback
   xgmii_loopback lpbk (
                        .data0x(decoded_dataout),
                        .data1x(bypass_dataout),
                        .sel(endec_loopback),
                        .result(loopback_dataout)
                        );

endmodule // sonic_single_port
