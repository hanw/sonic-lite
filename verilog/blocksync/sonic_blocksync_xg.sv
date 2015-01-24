//                              -*- Mode: Verilog -*-
// Filename        : sonic_blocksync_xg.sv
// Description     : lock to sync header
// Author          : Han Wang
// Created On      : Wed Nov 23 17:41:03 2011
// Last Modified By: Han Wang
// Last Modified On: Wed Nov 23 17:41:03 2011
// Update Count    : 1
// Status          : Need to fix the bit order!

/*
 * BLOCKSYNC State Machine
 * 
 */
  
module sonic_blocksync_xg (clk, reset, valid, data_in, block_lock, data_out);
   /* blocksync block for 10G ethernet stack*/
   input [65:0] data_in;
   input 	valid;
   input 	clk;
   input 	reset;
   output 	block_lock; //latch.
   output [65:0] data_out;
   
   reg [2:0]  state;
   reg [31:0] sh_cnt; //latch
   reg [31:0] sh_invalid_cnt; //latch
   reg 	      sh_valid;
   reg 	      slip_done; //latch
   reg	      test_sh;
   reg 	      block_lock;
   reg [65:0] rx_coded;

   /* 66-bit block in cur cycle */
   reg [65:0] rx_b1;
   /* 66-bit block in prev cycle */
   reg [65:0] rx_b2;

   /* verilator lint_off UNOPTFLAT */
   reg [7:0]  offset; //latch
      
   parameter LOCK_INIT = 0, RESET_CNT = 1, TEST_SH = 2;
   parameter VALID_SH = 3, INVALID_SH = 4, GOOD_64 = 5, SLIP = 6;

   assign data_out = rx_coded;
   
   /* output depends on state */
   always @ (posedge clk) begin
      case (state)
	LOCK_INIT: begin
	   block_lock = 0;
	   offset = 0;
	   test_sh = 0;
	end

	RESET_CNT: begin
	   sh_cnt = 0;
	   sh_invalid_cnt = 0;
	   slip_done = 0;
	   test_sh = valid;
	end

	TEST_SH: begin
	   test_sh = 0;
	end

	VALID_SH: begin
	   sh_cnt = sh_cnt + 1;
	   test_sh = valid;
	end

	INVALID_SH: begin
	   sh_cnt = sh_cnt + 1;
	   sh_invalid_cnt = sh_invalid_cnt + 1;
	   test_sh = valid;
	end

	GOOD_64: begin
	   block_lock = 1;
	   test_sh = valid;
	end

	SLIP: begin	   
	   if (offset >= 66) offset = 0;
	   else offset = offset + 8'h1;
	   slip_done = 1;
	   block_lock = 0;
	   test_sh = valid;
	end	
      endcase // case (state)
   end

  
   /* determine next state */
   always @ (posedge clk or posedge reset) begin
     if (reset) begin
	state <= LOCK_INIT;
     end
     else begin
	case (state)
	    LOCK_INIT:
	      state <= RESET_CNT;
	  
	    RESET_CNT:
	      if (test_sh) begin
		 state <= TEST_SH;
	      end
 
	    TEST_SH:
	      if (sh_valid) begin
		 state <= VALID_SH;
	      end
	      else begin
		 state <= INVALID_SH;
	      end
	  
	    VALID_SH:
	      if (test_sh & (sh_cnt < 64)) begin
		 state <= TEST_SH;
	      end
	      else if (sh_cnt == 64 & sh_invalid_cnt == 0) begin
		 state <= GOOD_64;
	      end
	      else if (sh_cnt == 64 & sh_invalid_cnt > 0) begin
		 state <= RESET_CNT;
	      end
	  	 
	    INVALID_SH:
	      if (sh_cnt == 64 & sh_invalid_cnt < 16 & block_lock) begin
		 state <= RESET_CNT;
	      end
	      else if (sh_invalid_cnt == 16 | !block_lock) begin
		 state <= SLIP;
	      end
	      else if (test_sh & sh_cnt < 64 & sh_invalid_cnt < 16 & block_lock) begin
		 state <= TEST_SH;
	      end
	  	 
	    GOOD_64:
	      state <= RESET_CNT;

	    SLIP:
	      if (slip_done) begin
		 state <= RESET_CNT;
	      end
	  
	endcase // case (state)
     end
   end

   /* barrel shifter */
   always @ (posedge clk) begin
      if (valid) begin
	 rx_b1 <= data_in;
	 rx_b2 <= rx_b1;
	 rx_coded <= (rx_b1 << offset) | rx_b2 >> (66 - offset) ;
      end
   end
  
   /* generate sh_valid */
   always @ (posedge clk) begin
      if (test_sh & valid) begin
	 sh_valid <= rx_coded[0] ^ rx_coded[1];
      end
   end

   /* generate slip_done 
   always @ (state) begin
      // slip one bit to the right
      case (state) 
	SLIP: begin
	   if (offset >= 66) offset = 0;
	   else offset = offset + 1;
	   slip_done = 1;
	end
      endcase // case (state)
   end
   */
/*   always @ (state) begin
      test_sh = (state == LOCK_INIT || state == TEST_SH) ? 0 : valid;
   end
*/      
endmodule // sonic_blocksync_xg


//-----------------------------------------------------------------------------------------
// Copyright 2011 Cornell University. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification, are
// permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this list of
// conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice, this list
// of conditions and the following disclaimer in the documentation and/or other materials
// provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY CORNELL UNIVERSITY ''AS IS'' AND ANY EXPRESS OR IMPLIED
// WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
// FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
// ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
// NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// The views and conclusions contained in the software and documentation are those of the
// authors and should not be interpreted as representing official policies, either expressed
// or implied, of Cornell University.
//------------------------------------------------------------------------------------------
