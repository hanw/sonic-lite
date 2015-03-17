// sonic_pma_v1_03

`timescale 1 ps / 1 ps
module sonic_pma_v1_05 (
		input  wire         phy_mgmt_clk,         //       phy_mgmt_clk.clk
		input  wire         phy_mgmt_clk_reset,   // phy_mgmt_clk_reset.reset
		input  wire [8:0]   phy_mgmt_address,     //           phy_mgmt.address
		input  wire         phy_mgmt_read,        //                   .read
		output wire [31:0]  phy_mgmt_readdata,    //                   .readdata
		output wire         phy_mgmt_waitrequest, //                   .waitrequest
		input  wire         phy_mgmt_write,       //                   .write
		input  wire [31:0]  phy_mgmt_writedata,   //                   .writedata
		output wire [3:0]   tx_ready,             //           tx_ready.export
		output wire [3:0]   rx_ready,             //           rx_ready.export
		input  wire [0:0]   pll_ref_clk,          //        pll_ref_clk.clk
		output wire [3:0]   pll_locked,           //         pll_locked.export
		output wire [3:0]   tx_serial_data,       //     tx_serial_data.export
		input  wire [3:0]   rx_serial_data,       //     rx_serial_data.export
		output wire [3:0]   rx_is_lockedtoref,    //  rx_is_lockedtoref.export
		output wire [3:0]   rx_is_lockedtodata,   // rx_is_lockedtodata.export
		output wire         tx_clkout0,           //         tx_clkout0.clk
		output wire         tx_clkout1,           //         tx_clkout0.clk
		output wire         tx_clkout2,           //         tx_clkout0.clk
		output wire         tx_clkout3,           //         tx_clkout0.clk
		output wire         rx_clkout0,           //         rx_clkout0.clk
		output wire         rx_clkout1,           //         rx_clkout0.clk
		output wire         rx_clkout2,           //         rx_clkout0.clk
		output wire         rx_clkout3,           //         rx_clkout0.clk
		input  wire [39:0]  tx_parallel_data0,    //  tx_parallel_data0.data
		input  wire [39:0]  tx_parallel_data1,    //  tx_parallel_data0.data
		input  wire [39:0]  tx_parallel_data2,    //  tx_parallel_data0.data
		input  wire [39:0]  tx_parallel_data3,    //  tx_parallel_data0.data
		output wire [39:0]  rx_parallel_data0,    //  rx_parallel_data0.data
		output wire [39:0]  rx_parallel_data1,    //  rx_parallel_data0.data
		output wire [39:0]  rx_parallel_data2,    //  rx_parallel_data0.data
		output wire [39:0]  rx_parallel_data3    //  rx_parallel_data0.data
	);

	wire [3:0] pll_powerdown;
	wire [3:0] tx_digitalreset;
	wire [3:0] tx_analogreset;
	wire [3:0] rx_digitalreset;
	wire [3:0] rx_analogreset;
	wire [3:0] tx_pma_clkout;
	wire [3:0] rx_pma_clkout;
	wire [3:0] tx_cal_busy;
	wire [3:0] rx_cal_busy;
	wire reconfig_busy;
	wire [159:0] rx_pma_parallel_data;
	wire [159:0] tx_pma_parallel_data;
	wire [367:0] reconfig_from_xcvr;
	wire [559:0] reconfig_to_xcvr;
	
  //----------------------------------------------------------------------
	// Reconfiguration Controller
	//----------------------------------------------------------------------
	altera_xgbe_pma_reconfig_wrapper altera_xgbe_pma_reconfig_wrapper_inst(
	/* inputs */
	//----------------------------------------------------------------------
	// Transceiver Reconfiguration Interface
	.reconfig_from_xcvr			(reconfig_from_xcvr),
	.reconfig_mgmt_address		(phy_mgmt_address),
	.reconfig_mgmt_read			(phy_mgmt_read),
	.reconfig_mgmt_write			(phy_mgmt_write),
	.reconfig_mgmt_writedata	(phy_mgmt_writedata),

	// Reconfiguration mMnagement
	.mgmt_rst_reset				(phy_mgmt_clk_reset),
	.mgmt_clk_clk					(phy_mgmt_clk),
	//----------------------------------------------------------------------

	/* outputs */
	//----------------------------------------------------------------------
	// Transceiver Reconfiguration Interface
	.reconfig_to_xcvr				(reconfig_to_xcvr),
	.reconfig_busy					(reconfig_busy),
	.reconfig_mgmt_readdata		(phy_mgmt_readdata),
	.reconfig_mgmt_waitrequest	(phy_mgmt_waitrequest)
	//----------------------------------------------------------------------
	);

	//----------------------------------------------------------------------
	// Native PHY IP Transceiver Instance
	//----------------------------------------------------------------------
	altera_xcvr_native_sv_wrapper altera_xcvr_native_sv_wrapper_inst (
	/*inputs */
	//----------------------------------------------------------------------
	// FPGA Fabric interface
	.tx_pma_parallel_data		(tx_pma_parallel_data),
	.unused_tx_pma_parallel_data (),
	
	// PLL, CDR, and Loopback
	.tx_pll_refclk					(pll_ref_clk),
	.rx_cdr_refclk					(pll_ref_clk),
	.pll_powerdown					(pll_powerdown),
	.rx_seriallpbken				(2'b0), // loopback mode

	// Speed Serial I/O
	.rx_serial_data				(rx_serial_data),

	// Reset And Calibration Status
	.tx_digitalreset				(tx_digitalreset),
	.tx_analogreset				(tx_analogreset),
	.rx_digitalreset				(rx_digitalreset),
	.rx_analogreset				(rx_analogreset),

	// Transceiver Reconfiguration Interface
	.reconfig_to_xcvr				(reconfig_to_xcvr),
	//----------------------------------------------------------------------
	
	/* outputs */
	//----------------------------------------------------------------------
	// FPGA Fabric interface
	.tx_pma_clkout					(tx_pma_clkout),
	.rx_pma_clkout					(rx_pma_clkout),
	.rx_pma_parallel_data		(rx_pma_parallel_data),
	.unused_rx_pma_parallel_data (),
	
	// PLL, CDR, and Loopback
	.pll_locked						(pll_locked),
	.rx_is_lockedtodata			(rx_is_lockedtodata),
	.rx_is_lockedtoref			(rx_is_lockedtoref),

	// Speed Serial I/O
	.tx_serial_data				(tx_serial_data),

	// Reset And Calibration Status
	.tx_cal_busy					(tx_cal_busy),
	.rx_cal_busy					(rx_cal_busy),

	// Transceiver Reconfiguration Interface
	.reconfig_from_xcvr			(reconfig_from_xcvr)
	//----------------------------------------------------------------------
	);

	
	//----------------------------------------------------------------------
	// Reset Controller 
	//----------------------------------------------------------------------
	altera_xcvr_reset_control_wrapper altera_xcvr_reset_control_wrapper_inst (
	/* inputs  */
	//----------------------------------------------------------------------
	// PLL and Calibration Status
	.pll_locked						(pll_locked),
	.pll_select						(2'b11), // only needed for multiple PLLs
	.tx_cal_busy					(tx_cal_busy),
	.rx_cal_busy					(rx_cal_busy),
	.rx_is_lockedtodata			(rx_is_lockedtodata),

	// Clock and Reset 
	.clock							(phy_mgmt_clk),
	.reset							(phy_mgmt_clk_reset),
	//----------------------------------------------------------------------
	
	/* outputs */
	//----------------------------------------------------------------------
	// TX and RX Resets and Status
	.tx_digitalreset				(tx_digitalreset),
	.tx_analogreset				(tx_analogreset),
	.tx_ready						(tx_ready),
	.rx_digitalreset				(rx_digitalreset),
	.rx_analogreset				(rx_analogreset),
	.rx_ready						(rx_ready),

	// PLL Powerdown 
	.pll_powerdown					(pll_powerdown)
	//----------------------------------------------------------------------
);

assign tx_pma_parallel_data = {tx_parallel_data3,tx_parallel_data2,tx_parallel_data1,tx_parallel_data0};
assign rx_parallel_data3 = rx_pma_parallel_data[159:120];
assign rx_parallel_data2 = rx_pma_parallel_data[119:80];
assign rx_parallel_data1 = rx_pma_parallel_data[79:40];
assign rx_parallel_data0 = rx_pma_parallel_data[39:0];
assign tx_clkout = tx_pma_clkout;
assign rx_clkout = rx_pma_clkout;

endmodule
