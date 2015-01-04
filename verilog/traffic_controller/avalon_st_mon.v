//-----------------------------------------------------------------------------
// Title         : avalon_st_mon
// Project       : 10G Ethernet reference design
//-----------------------------------------------------------------------------
// File          : avalon_st_mon.v
// Author        : Altera Corporation
//-----------------------------------------------------------------------------
// Functional Description:
// This module is the top level of the 10G Ethernet Packet Monitor
//-------------------------------------------------------------------------------
//
// Copyright 2010 Altera Corporation. All rights reserved.  Altera products are
// protected under numerous U.S. and foreign patents, maskwork rights, copyrights and
// other intellectual property laws.
// This reference design file, and your use thereof, is subject to and governed by
// the terms and conditions of the applicable Altera Reference Design License Agreement.
// By using this reference design file, you indicate your acceptance of such terms and
// conditions between you and Altera Corporation.  In the event that you do not agree with
// such terms and conditions, you may not use the reference design file. Please promptly
// destroy any copies you have made.
//
// This reference design file being provided on an "as-is" basis and as an accommodation
// and therefore all warranties, representations or guarantees of any kind
// (whether express, implied or statutory) including, without limitation, warranties of
// merchantability, non-infringement, or fitness for a particular purpose, are
// specifically disclaimed.  By making this reference design file available, Altera
// expressly does not recommend, suggest or require that this reference design file be
// used in combination with any other product not provided by Altera

// turn off bogus verilog processor warnings
// altera message_off 10034 10035 10036 10037 10230
 
 module avalon_st_mon
 (
  input clk               
 ,input reset             
 ,input [7:0]  avalon_mm_address           
 ,input avalon_mm_write             
 ,input avalon_mm_read              
 ,output wire avalon_mm_waitrequest              
 ,input [31:0] avalon_mm_writedata         
 ,output reg[31:0] avalon_mm_readdata          
 
 ,input  mac_rx_status_valid    
 ,input  mac_rx_status_error    
 //,input [38:0] mac_rx_status_data    
 ,input [39:0] mac_rx_status_data    
 
 ,input [63:0] avalon_st_rx_data           
 ,input avalon_st_rx_valid          
 ,input avalon_st_rx_sop            
 ,input avalon_st_rx_eop            
 ,input [2:0]  avalon_st_rx_empty          
 ,input [5:0]  avalon_st_rx_error          
 ,output reg   avalon_st_rx_ready          
 ,input wire   stop_mon
 ,output wire  mon_active
 ,output wire  mon_done
 ,output reg   mon_error
 ,output reg   gen_lpbk
 );

 wire crcbad;
 wire crcvalid;

 reg rddly, wrdly;
 always@(posedge clk or posedge reset)
 begin
    if(reset) 
	begin 
	    wrdly <= 1'b0; 
	    rddly <= 1'b0; 
	end 
    else 
	begin 
	    wrdly <= avalon_mm_write; 
	    rddly <= avalon_mm_read; 
	end 
 end
 
 wire wredge = avalon_mm_write& ~wrdly;
 wire rdedge = avalon_mm_read & ~rddly;

 assign avalon_mm_waitrequest = (wredge|rdedge); 

 // _______________________________________________________________________
 //	avalon mm R/W registers
 // _______________________________________________________________________

 reg [31:0] number_packet;            
 reg [31:0] good_pkts;                
 reg [31:0] bad_pkts;                 
 reg [63:0] byte_count;               
 reg [63:0] cycle_rx_count;          
 reg [9:0]  mon_csr;      
 reg [39:0] rx_mac_status;      

  reg[31:0]   inspection_start_frame;
  reg[31:0]   inspection_start_cycle;
  reg[31:0]   inspection_number_cycles;
  reg[63:0]   rx_frame_words_01 ;
  reg[63:0]   rx_frame_words_23 ;
  reg[63:0]   rx_frame_words_45 ;
  reg[63:0]   rx_frame_words_67 ;
  reg[63:0]   rx_frame_words_89 ;
  reg[63:0]   rx_frame_words_ab ;
  reg[63:0]   rx_frame_words_cd ;
  reg[63:0]   rx_frame_words_ef ;
  
 reg init_dly;
 wire init_reg =  mon_csr[0];

 always @ (posedge reset or posedge clk)
   begin
      if (reset) init_dly<= 1'b0;
      else init_dly<= init_reg; 
   end

 reg[3:0] stop_sync;
 wire stop_pedge = stop_sync[2] & ~stop_sync[3]; 
 always @ (posedge reset or posedge clk)
   begin
      if (reset) stop_sync<= 4'd0;
      else stop_sync<= {stop_sync[2:0],stop_mon}; 
   end

 wire mon_init = init_reg & ~init_dly;
 assign mon_done =  mon_csr[2];

 always @(posedge reset or posedge clk)
   begin
      if (reset) 
	begin
	 // set the expected number to max
	 // so that process is not done at
	 // very first pkt (dont need start)
	 // - ajay dubey
            number_packet <= 32'hffff_ffff;
            gen_lpbk <= 1'b0;
	    inspection_start_frame <= 32'h0;
      	    inspection_start_cycle <= 32'h0;
      	    inspection_number_cycles <= 32'h0;
	end
      else if (avalon_mm_write)
	 begin
	    case(avalon_mm_address)
              8'h00: number_packet <= avalon_mm_writedata;
              8'h0a: gen_lpbk <= avalon_mm_writedata[0];
	      8'h80: inspection_start_frame <= avalon_mm_writedata;
      	      8'h81: inspection_start_cycle <= avalon_mm_writedata;
      	      8'h82: inspection_number_cycles <= avalon_mm_writedata;
	      default:inspection_start_frame <= inspection_start_frame;
	    endcase
	end
   end

 // _____________________________________________________
 //	RW/CoR Register
 // _____________________________________________________
 always @ (posedge reset or posedge clk)
   begin
      if (reset)  mon_csr <= 10'h0;
      else begin
            if (avalon_mm_write & avalon_mm_address == 8'h07)  mon_csr[1:0] <= avalon_mm_writedata[1:0];
            else if ( init_reg)  mon_csr[2:0] <= 3'd0; // reset at the start/restart
            else if (stop_pedge |((good_pkts + bad_pkts) == number_packet))  mon_csr[2] <= 1'b1;

            if (avalon_st_rx_valid & avalon_st_rx_eop) mon_csr[9:4] <= avalon_st_rx_error;

            if (avalon_mm_read & avalon_mm_address == 8'h07) mon_csr[3] <= 1'b0;
	    else if (avalon_st_rx_valid & crcvalid & crcbad) mon_csr[3] <= 1'b1;
         end   
   end

 // ____________________________________________
 //	packet counters
 // ____________________________________________

 always @ (posedge reset or posedge clk)
   begin
      if (reset) begin
          good_pkts <= 32'h0;
      	  bad_pkts <= 32'h0;
      end 
      else if(mon_init) begin
          good_pkts <= 32'h0;
          bad_pkts <= 32'h0;
      end
      else if (mon_active) begin
          if (crcvalid & ~crcbad) good_pkts <= good_pkts + 32'h1;
          if (crcvalid & crcbad) bad_pkts <= bad_pkts + 32'h1;
      end
   end

 // ______________________________________________
 //	performance registers

 reg[1:0] monstate, next_monstate;
 parameter MONIDLE = 2'd0; 
 parameter MONACTIVE = 2'd1;
 parameter MONDONE = 2'd2;
 
 always@(posedge clk or posedge reset)
    begin
      if (reset) monstate <= MONIDLE;
      else monstate <= next_monstate;
    end

 always@(*)
    begin
	next_monstate = monstate;
	case(monstate)
           MONIDLE: if (avalon_st_rx_valid & avalon_st_rx_sop) next_monstate = MONACTIVE;
           MONACTIVE: if (mon_done) next_monstate = MONDONE;
           MONDONE: if (mon_init) next_monstate = MONIDLE;
	   default: next_monstate = monstate;
	endcase
    end

 assign mon_active = (monstate == MONACTIVE);
 always @ (posedge reset or posedge clk)
   begin // (
      if (reset) byte_count <= 64'h0;
      else if (mon_init) byte_count <= 64'h0;
      else if (mon_active && avalon_st_rx_valid) 
	begin // (
	   if (avalon_st_rx_eop)
	       begin // (
               case (avalon_st_rx_empty)
                  3'b000:  byte_count<= byte_count + 64'h8;
                  3'b001:  byte_count<= byte_count + 64'h7;
                  3'b010:  byte_count<= byte_count + 64'h6;
                  3'b011:  byte_count<= byte_count + 64'h5;
                  3'b100:  byte_count<= byte_count + 64'h4;
                  3'b101:  byte_count<= byte_count + 64'h3;
                  3'b110:  byte_count<= byte_count + 64'h2;
                  3'b111:  byte_count<= byte_count + 64'h1;
                  default: byte_count<= byte_count + 64'h8;
               endcase
	       end // )
           else byte_count <= byte_count + 64'h8;
         end // )
     else byte_count <= byte_count;
   end // )
   
 // ______________________________________________________
 //

 always @ (posedge reset or posedge clk)
   begin
      if (reset) cycle_rx_count <= 64'h0;
      else if (mon_init) cycle_rx_count <= 64'h0;
      else if (mon_active) cycle_rx_count <= cycle_rx_count + 64'h1;
   end

 // ______________________________________________________
 //






 always @ (posedge reset or posedge clk)
   begin
      if (reset) avalon_mm_readdata <= 0;
      else if (avalon_mm_read) begin
         case (avalon_mm_address)
            8'h00:avalon_mm_readdata <= number_packet;
            8'h01:avalon_mm_readdata <= good_pkts;
            8'h02:avalon_mm_readdata <= bad_pkts;
            8'h03:avalon_mm_readdata <= byte_count[31:0];
            8'h04:avalon_mm_readdata <= byte_count[63:32];
            8'h05:avalon_mm_readdata <= cycle_rx_count[31:0];
            8'h06:avalon_mm_readdata <= cycle_rx_count[63:32];
            8'h07:avalon_mm_readdata <= {22'd0, mon_csr};
            8'h08:avalon_mm_readdata <= rx_mac_status[31:0]; // TBD: enhance later
            8'h09:avalon_mm_readdata <= {mac_rx_status_error, rx_mac_status[38:32]}; 
            8'h0a:avalon_mm_readdata <= {31'd0,gen_lpbk}; 

            8'h80:avalon_mm_readdata <= inspection_start_frame; 
            8'h81:avalon_mm_readdata <= inspection_start_cycle; 
            8'h82:avalon_mm_readdata <= inspection_number_cycles; 
       	    8'h83:avalon_mm_readdata <= rx_frame_words_01;
       	    8'h84:avalon_mm_readdata <= rx_frame_words_23;
       	    8'h85:avalon_mm_readdata <= rx_frame_words_45;
       	    8'h86:avalon_mm_readdata <= rx_frame_words_67;
       	    8'h87:avalon_mm_readdata <= rx_frame_words_89;
       	    8'h88:avalon_mm_readdata <= rx_frame_words_ab;
       	    8'h89:avalon_mm_readdata <= rx_frame_words_cd;
       	    8'h8a:avalon_mm_readdata <= rx_frame_words_ef;
            default: avalon_mm_readdata <= 32'h0;
         endcase
      end
   end
 // ______________________________________________________
 //

 always @ (posedge reset or posedge clk)
   begin
      if (reset) avalon_st_rx_ready <= 1'b0;
      else avalon_st_rx_ready <= 1'b1;
   end
/*
 crcchk crcchk_inst
 (
   .clk           (clk),
   .data          (avalon_st_rx_data),
   .datavalid     (avalon_st_rx_valid),
   .empty         (avalon_st_rx_empty),
   .endofpacket   (avalon_st_rx_eop),
   .reset_n       (~reset),
   .startofpacket (avalon_st_rx_sop),
   .crcbad        (crcbad),
   .crcvalid      (crcvalid)
 );
*/
 // __________________________________________________________
 //synopsys translate_off
  always@(good_pkts)    begin $display("_INFO_: Received Packet %d", good_pkts); end
  always@(bad_pkts) begin $display("_ERROR_: CRC Error Found %d", bad_pkts); end
 //synopsys translate_on
 // __________________________________________________________

 reg state, next_state;
 parameter IDLE = 1'b0; 
 parameter CHCK = 1'b1;
 

 wire inspection_frame_match = (inspection_start_frame == (good_pkts + bad_pkts));
 wire inspection_cycle_match = (inspection_start_cycle == cycle_rx_count);
 wire inspection_begin = inspection_frame_match & inspection_cycle_match;

 always@(posedge clk or posedge reset)
    begin
      if (reset) state <= IDLE;
      else state <= next_state;
    end

 reg[7:0] inspection_cycle_count;
 always@(*)
    begin
	next_state = state;
	case(state)
           IDLE: if (avalon_st_rx_sop & avalon_st_rx_valid & inspection_begin) next_state = CHCK;
           CHCK: if (inspection_cycle_count == inspection_number_cycles) next_state = IDLE;
	   default: next_state = state;
	endcase
    end

 always@(posedge clk or posedge reset)
    begin
      if (reset) inspection_cycle_count <= 8'd0;
      else if (state == CHCK) inspection_cycle_count <= inspection_cycle_count + 8'd1;
    end

 reg[63:0] avalon_st_rxd_dly;
 always@(posedge clk or posedge reset)
    begin
      if (reset)
     	begin
	   avalon_st_rxd_dly <= 64'd0;
       	   rx_frame_words_01 <= 64'd0;
       	   rx_frame_words_23 <= 64'd0;
       	   rx_frame_words_45 <= 64'd0;
       	   rx_frame_words_67 <= 64'd0;
       	   rx_frame_words_89 <= 64'd0;
       	   rx_frame_words_ab <= 64'd0;
       	   rx_frame_words_cd <= 64'd0;
       	   rx_frame_words_ef <= 64'd0;
     	end
      else begin
	  avalon_st_rxd_dly <= avalon_st_rx_data;
          if(state == CHCK) 
     	     case(inspection_cycle_count) 
    	   	8'd0: rx_frame_words_01 <= avalon_st_rxd_dly[63:0];	
    	   	8'd1: rx_frame_words_23 <= avalon_st_rxd_dly[63:0];	
    	   	8'd2: rx_frame_words_45 <= avalon_st_rxd_dly[63:0];	
    	   	8'd3: rx_frame_words_67 <= avalon_st_rxd_dly[63:0];	
    	   	8'd4: rx_frame_words_89 <= avalon_st_rxd_dly[63:0];	
    	   	8'd5: rx_frame_words_ab <= avalon_st_rxd_dly[63:0];	
    	   	8'd6: rx_frame_words_cd <= avalon_st_rxd_dly[63:0];	
    	   	8'd7: rx_frame_words_ef <= avalon_st_rxd_dly[63:0];	
    	    	default: rx_frame_words_01 <= 64'hdead_feed_dead_feed;
     	    endcase
     	end
    end

  // __________________________________________________________________________________
  // 

 
 always@(posedge clk or posedge reset)
    begin
      if (reset) mon_error <= 1'b0;
      else if (mon_done && (|bad_pkts)) mon_error <= 1'b1;
    end
endmodule

