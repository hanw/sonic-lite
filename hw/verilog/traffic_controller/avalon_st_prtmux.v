// ____________________________________________________________________
//	Copyright(C) 2010: Altera Corporation
//	Altera corporation Confidential 
//	IP to be used with altera devices only
// ____________________________________________________________________

 module avalon_st_prtmux 
      (
      //  first avalon-st port input to this module
	  input  wire	    avl_st_iport_0_eop,
	  input  wire[5:0]  avl_st_iport_0_error,
	  input  wire	    avl_st_iport_0_sop,
	  input  wire	    avl_st_iport_0_val,
	  input  wire[63:0] avl_st_iport_0_data,
	  input  wire[2:0]  avl_st_iport_0_empty, 
	  output reg	    avl_st_lpmx_iport_0_ready,
	  
      //  second avalon-st port input to this module
	  input  wire	    avl_st_iport_1_eop,
	  input  wire[5:0]  avl_st_iport_1_error,
	  input  wire	    avl_st_iport_1_sop,
	  input  wire	    avl_st_iport_1_val,
	  input  wire[63:0] avl_st_iport_1_data,
	  input  wire[2:0]  avl_st_iport_1_empty, 
	  output reg	    avl_st_lpmx_iport_1_ready,
          input  wire	    avl_st_default_iport_1_ready, // one from mactx
	  
      //  output port connected to one of the two
      //  input ports as listed in lines above
	  output reg	    avl_st_oport_eop,
	  output reg[5:0]   avl_st_oport_error,
	  output reg	    avl_st_oport_sop,
	  output reg	    avl_st_oport_val,
	  output reg[63:0]  avl_st_oport_data,
	  output reg[2:0]   avl_st_oport_empty, 
	  input  wire	    avl_st_oport_ready, // avl_st_snk_lpmx_ready
	  
	  input  wire	    cfg_lpmx_sel_iport_1
	);

 // ____________________________________________________________________

 //          iport0: macrx outputs, iport1: avl st tx outputs
 //	     and oport is the avl st rx inputs. Please note that
 //	     the direction of ready is opposite to rest of signals
 //

  always@(*)
    begin
	if (cfg_lpmx_sel_iport_1)
	    begin
	    // when loopback is enabled, the avl st rx bus
	    // is connected to avl st tx bus (iport_1)
	    // the ready signal for avl st tx will be connected
	    // to the oport ready signal
		avl_st_oport_eop  = avl_st_iport_1_eop;
		avl_st_oport_error= avl_st_iport_1_error;
		avl_st_oport_sop  = avl_st_iport_1_sop;
		avl_st_oport_val  = avl_st_iport_1_val;
		avl_st_oport_data = avl_st_iport_1_data;
		avl_st_oport_empty = avl_st_iport_1_empty; 
	        avl_st_lpmx_iport_1_ready = avl_st_oport_ready; // avl_st_snk_lpmx_ready;
	    //	we are not considering port0 (default) to outport
	    //	connection here, so it is dont care, we can leave 
	    //	the default  connection for iport-0 ready as such
	        avl_st_lpmx_iport_0_ready = avl_st_oport_ready; // avl_st_snk_lpmx_ready;
	    end
	else 
	    begin
		avl_st_oport_eop  = avl_st_iport_0_eop;
		avl_st_oport_error= avl_st_iport_0_error;
		avl_st_oport_sop  = avl_st_iport_0_sop;
		avl_st_oport_val  = avl_st_iport_0_val;
		avl_st_oport_data = avl_st_iport_0_data;
		avl_st_oport_empty = avl_st_iport_0_empty; 
	        avl_st_lpmx_iport_0_ready = avl_st_oport_ready; // avl_st_snk_lpmx_ready;
	        avl_st_lpmx_iport_1_ready = avl_st_default_iport_1_ready; 
	    end
    end


 // ____________________________________________________________________
 //

 endmodule


