// _________________________________________________________________________
//	
//	Author: Ajay Dubey, IP Apps engineering
// __________________________________________________________________________

 module avalon_st_traffic_controller (
	input 	wire		avl_mm_read      ,
	input 	wire		avl_mm_write     ,
	output 	wire		avl_mm_waitrequest,
	input 	wire[23:0]	avl_mm_baddress   ,
	output 	wire[31:0]	avl_mm_readdata  ,
	input 	wire[31:0]	avl_mm_writedata ,

	input 	wire 		clk_in	,
	input 	wire 		reset_n	,

	input 	wire[39:0] 	mac_rx_status_data	,
	input 	wire		mac_rx_status_valid	,
	input 	wire		mac_rx_status_error	,
	input   wire	        stop_mon	,
	output  wire	        mon_active	,
	output  wire	        mon_done	,
	output  wire	        mon_error	,

	output 	wire[63:0] 	avl_st_tx_data	,
	output 	wire[2:0]  	avl_st_tx_empty	,
	output 	wire 		avl_st_tx_eop	,
	output 	wire 		avl_st_tx_error	,
	input 	wire 		avl_st_tx_rdy	,
	output 	wire 		avl_st_tx_sop	,
	output 	wire 		avl_st_tx_val	,             

	input 	wire[63:0] 	avl_st_rx_data	,
	input 	wire[2:0]  	avl_st_rx_empty	,
	input 	wire 		avl_st_rx_eop	,
	input 	wire [5:0]	avl_st_rx_error	,
	output 	wire 		avl_st_rx_rdy	,
	input 	wire 		avl_st_rx_sop	,
	input 	wire 		avl_st_rx_val
    );


 // ________________________________________________
 //  traffic generator

	wire  avl_st_rx_lpmx_mon_eop;
	wire[5:0]  avl_st_rx_lpmx_mon_error;
	wire  avl_st_rx_mon_lpmx_rdy;
	wire  avl_st_rx_lpmx_mon_sop;
	wire  avl_st_rx_lpmx_mon_val; 
	wire[63:0] avl_st_rx_lpmx_mon_data;
	wire[2:0]  avl_st_rx_lpmx_mon_empty;

	wire[23:0] avl_mm_address = {2'b00, avl_mm_baddress[23:2]}; // byte to word address
	wire[31:0] avl_mm_readdata_gen, avl_mm_readdata_mon;
	wire  blk_sel_gen = (avl_mm_address[23:16] == 8'd0);
	wire  blk_sel_mon = (avl_mm_address[23:16] == 8'd1);
 	wire waitrequest_gen, waitrequest_mon;
   	assign avl_mm_waitrequest = blk_sel_gen?waitrequest_gen:blk_sel_mon? waitrequest_mon:1'b0;
	assign avl_mm_readdata = blk_sel_gen? avl_mm_readdata_gen:blk_sel_mon? avl_mm_readdata_mon:32'd0;

	wire gen_lpbk;

        wire sync_reset;
// _______________________________________________________________
   traffic_reset_sync reset_sync
// _______________________________________________________________

    ( .clk      (clk_in),
      .data_in  (1'b0),
      .reset    (~reset_n),
      .data_out (sync_reset)
    );


// _______________________________________________________________
 	avalon_st_gen  GEN (
// _______________________________________________________________
	.clk         (clk_in), 	 			// Tx clock
	.reset       (sync_reset), 			// Reset signal
	.address     (avl_mm_address[7:0]), 		// Avalon-MM Address
	.write       (avl_mm_write & blk_sel_gen), 	// Avalon-MM Write Strobe
	.writedata   (avl_mm_writedata), 		// Avalon-MM Write Data
	.read        (avl_mm_read & blk_sel_gen), 	// Avalon-MM Read Strobe
	.readdata    (avl_mm_readdata_gen), 		// Avalon-MM Read Data
	.waitrequest (waitrequest_gen),   		
	 
	.tx_data     (avl_st_tx_data), 			// Avalon-ST Data
	.tx_valid    (avl_st_tx_val), 			// Avalon-ST Valid
	.tx_sop      (avl_st_tx_sop), 			// Avalon-ST StartOfPacket
	.tx_eop      (avl_st_tx_eop), 			// Avalon-ST EndOfPacket
	.tx_empty    (avl_st_tx_empty), 		// Avalon-ST Empty
	.tx_error    (avl_st_tx_error), 		// Avalon-ST Error
	.tx_ready    (avl_st_tx_rdy) 
	);
  // ___________________________________________________________________
 	avalon_st_mon  	MON (
  // ___________________________________________________________________
	.clk       		(clk_in ),     			// RX clock
	.reset     		(sync_reset ),     		// Reset Signal
	.avalon_mm_address   	(avl_mm_address[7:0]),     	// Avalon-MM Address
	.avalon_mm_write     	(avl_mm_write & blk_sel_mon),  	// Avalon-MM Write Strobe
	.avalon_mm_writedata 	(avl_mm_writedata),     	// Avalon-MM write Data
	.avalon_mm_read    	(avl_mm_read & blk_sel_mon),   	// Avalon-MM Read Strobe
	.avalon_mm_waitrequest 	(waitrequest_mon),   		
	.avalon_mm_readdata  	(avl_mm_readdata_mon),     	// Avalon-MM Read Data
	.mac_rx_status_valid	(mac_rx_status_valid),     		
	.mac_rx_status_error	(mac_rx_status_error),     		
	.mac_rx_status_data 	(mac_rx_status_data),     		
	.stop_mon 		(stop_mon),     		
	.mon_active 		(mon_active),     		
	.mon_done 		(mon_done),     		
	.mon_error 		(mon_error),     		
	.gen_lpbk 		(gen_lpbk),     		
	 
	.avalon_st_rx_data   	(avl_st_rx_data),    	// Avalon-ST RX Data
	.avalon_st_rx_valid  	(avl_st_rx_val),     	// Avalon-ST RX Valid
	.avalon_st_rx_sop    	(avl_st_rx_sop),     	// Avalon-ST RX StartOfPacket
	.avalon_st_rx_eop    	(avl_st_rx_eop),     	// Avalon-ST RX EndOfPacket
	.avalon_st_rx_empty  	(avl_st_rx_empty),   	// Avalon-ST RX Data Empty
	.avalon_st_rx_error  	(avl_st_rx_error),   	// Avalon-ST RX Error
	.avalon_st_rx_ready  	(avl_st_rx_rdy)    	// Avalon-ST RX Ready Output
	);

  // ___________________________________________________________________

 endmodule
// ____________________________________________________________________________________________
//	reset synchronizer 
// ____________________________________________________________________________________________

// turn off superfluous verilog processor warnings 
// altera message_level Level1 
// altera message_off 10034 10035 10036 10037 10230 10240 10030 

module traffic_reset_sync ( clk, data_in, reset, data_out) ;

  output data_out;
  input  clk;
  input  data_in;
  input  reset;

  reg   data_in_d1 /* synthesis ALTERA_ATTRIBUTE = "{-from \"*\"} CUT=ON ; PRESERVE_REGISTER=ON ; SUPPRESS_DA_RULE_INTERNAL=R101"  */;
  reg   data_out /* synthesis ALTERA_ATTRIBUTE = "PRESERVE_REGISTER=ON ; SUPPRESS_DA_RULE_INTERNAL=R101"  */;
  always @(posedge clk or posedge reset)
    begin
      if (reset == 1) data_in_d1 <= 1;
      else data_in_d1 <= data_in;
    end


  always @(posedge clk or posedge reset)
    begin
      if (reset == 1) data_out <= 1;
      else data_out <= data_in_d1;
    end



endmodule
