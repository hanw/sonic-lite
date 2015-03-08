/*
 Gearbox 40 in 66 out
 Data is stored in SR0 first, and shifted to SR1 if 'shift/valid' is 1. 
 Output copies SR1 if 'valid' is 1.
 'SHIFT' and 'VALID' are the same.
 
 |State |     SR0 (66 bits)           |         SR1 (66 bits)         | Valid | Shift | 
    0    -----------------------------------------[39               0]    0       0
    1    -------------------[13     0] [65     40][39               0]    1       1
    2    -------------------------------------[53           14][13  0]    0       0
    3    ----------------[27        0] [65:54][53           14][13  0]    1       1
    4    ------------------------[1:0] [65          28][27          0]    1       1
    5    ----------------------------------------[41           2][1:0]    0       0
    6    ------------------[15      0] [65    42][41           2][1:0]    1       1
    7    -------------------------------------[55          16][15   0]    0       0
    8    -----------------[29       0] [65:56][55          16][15   0]    1       1
    9    ------------------------[3:0] [65            30][29        0]    1       1
   10    -------------------------------------[43          4][3     0]    0       0
   11    --------------    [17      0] [65 44][43          4][3     0]    1       1
   12    -------------------------------------[58       18][17      0]    0       0
   13    ----------------[31        0] [65 58][57       18][17      0]    1       1
   14    ----------------------- [5:0] [65            32][31        0]    1       1
   15    --------------------------------------[45          6][5    0]    0       0
   16    ------------------[19      0] [65  46][45          6][5    0]    1       1
   17    -------------------------------------[59       20][19      0]    0       0
   18    ----------------[33        0] [65  60][59      20][19      0]    1       1
   19    ------------------------[7:0] [65        34][33            0]    1       1
   20    -------------------------------------[47         8][7      0]    0       0
   21    ------------------[21      0] [65   48][47       8][7      0]    1       1
   22    ---------------------------------[61      22][21           0]    0       0
   23    ------------[35            0] [65:62][61  22][21           0]    1       1
   24    --------------------[9     0] [65      36][35              0]    1       1
   25    -----------------------------------[49           10][9     0]    0       0
   26    ------------------[23      0] [65   50][49       10][9     0]    1       1
   27    ---------------------------------[63         24][23        0]    0       0
   28    -----------[37             0] [65:64][63     24][23        0]    1       1
   29    ---------------------[11   0] [65          38][37          0]    1       1
   30    -----------------------------------[51         12][11      0]    0       0
   31    ---------------[25         0] [65  52][51      12][11      0]    1       1
   32    ------------------------------[65           26][25         0]    1       1
 */

module sonic_gearbox_40_66 (/*AUTOARG*/
   // Outputs
   data_out, data_valid,
   // Inputs
   clk_in, reset, data_in
   );
   input clk_in;
   input reset;
   input [39:0]  data_in;
   output [65:0] data_out;
   output 	 data_valid;

   logic [65:0]  data_out;
   logic 	 data_valid;
      
   reg [6:0]    state;
   reg [65:0] 	sr0;
   reg [65:0] 	sr1;
   reg 		valid;

   always @ (posedge clk_in /*AUTOSENSE*/ or posedge reset) begin
      if (reset == 1'b1) begin
	 sr0 <= 66'h0;
	 sr1 <= 66'h0;
	 valid <= 1'b0;
      end
      else begin
	 case (state)
	   0: begin
	      sr1[39:0]  <= data_in[39:0];
	      sr1[65:40] <= 0;
	      sr0[65:0]  <= 0;
	      valid      <= 0;
	   end
	   1: begin
	      sr1[65:40] <= data_in[25:0];
	      sr0[13:0]  <= data_in[39:26];
	      sr0[65:14] <= 0;
	      valid      <= 1;
	   end
	   2: begin
	      sr1[13:0]  <= sr0[13:0];
	      sr1[53:14] <= data_in[39:0];
	      sr0[65:0]  <= 0;
	      valid      <= 0;
	   end
	   3: begin
	      sr1[65:54] <= data_in[11:0];
	      sr0[27:0]  <= data_in[39:12];
	      sr0[65:28] <= 0;
	      valid      <= 1;
	   end
	   4: begin
	      sr1[27:0]  <= sr0[27:0];
	      sr1[65:28] <= data_in[37:0];
	      sr0[1:0]   <= data_in[39:38];
	      sr0[65:2]  <= 0;
	      valid      <= 1;
	   end
	   5: begin
	      sr1[1:0]   <= sr0[1:0];
	      sr1[41:2]  <= data_in[39:0];
	      sr0        <= 0;
	      valid      <= 0;
	   end
	   6: begin
	      sr1[65:42] <= data_in[23:0];
	      sr0[15:0]  <= data_in[39:24];
	      sr0[65:16] <= 0;
	      valid      <= 1;
	   end
	   7: begin
	      sr1[15:0]  <= sr0[15:0];
	      sr1[55:16] <= data_in[39:0];
	      sr0[65:0]  <= 0;
	      valid      <= 0;
	      
	   end
	   8: begin
	      sr1[65:56] <= data_in[9:0];
	      sr0[29:0]  <= data_in[39:10];
	      sr0[65:30] <= 0;
	      valid      <= 1;
	   end
	   9: begin
	      sr1[29:0]  <= sr0[29:0];
	      sr1[65:30] <= data_in[35:0];
	      sr0[3:0]   <= data_in[39:36];
	      sr0[65:4]  <= 0;
	      valid      <= 1;
	   end
	   10: begin
	      sr1[43:4]  <= data_in[39:0];
	      sr1[3:0]   <= sr0[3:0];
	      sr1[65:44] <= 0;
	      sr0        <= 0;
	      valid      <= 0;
	   end
	   11: begin
	      sr1[65:44] <= data_in[21:0];
	      sr0[17:0]  <= data_in[39:22];
	      sr0[65:18] <= 0;
	      valid      <= 1;
	   end
	   12: begin
	      sr1[17:0]  <= sr0[17:0];
	      sr1[57:18] <= data_in[39:0];
	      sr0[65:0]  <= 0;
	      valid      <= 0;
	   end
	   13: begin
	      sr1[65:58] <= data_in[7:0];
	      sr0[31:0]  <= data_in[39:8];
	      sr0[65:32] <= 0;
	      valid      <= 1;
	   end
	   14: begin
	      sr1[31:0]  <= sr0[31:0];
	      sr1[65:32] <= data_in[33:0];
	      sr0[5:0]   <= data_in[39:34];
	      sr0[39:6]  <= 0;
	      valid      <= 1;
	   end
	   15: begin
	      sr1[45:6]  <= data_in[39:0];
	      sr1[5:0]   <= sr0[5:0];
	      sr0[65:0]  <= 0;
	      valid      <= 0;
	   end
	   16: begin
	      sr1[65:46] <= data_in[19:0];
	      sr0[19:0]  <= data_in[39:20];
	      sr0[65:20] <= 0;
	      valid      <= 1;
	   end
	   17: begin
	      sr1[19:0]  <= sr0[19:0];
	      sr1[59:20] <= data_in[39:0];
	      sr0[59:0]  <= 0;
	      valid      <= 0;
	      
	   end
	   18: begin
	      sr1[65:60] <= data_in[5:0];
	      sr0[33:0]  <= data_in[39:6];
	      sr0[65:34] <= 0;
	      valid      <= 1;
	      
	   end
	   19: begin
	      sr1[33:0]  <= sr0[33:0];
	      sr1[65:34] <= data_in[31:0];
	      sr0[7:0]   <= data_in[39:32];
	      sr0[65:8]  <= 0;
	      valid      <= 1;
	   end
	   20: begin
	      sr1[7:0]   <= sr0[7:0];
	      sr1[47:8]  <= data_in[39:0];
	      sr0[65:0]  <= 0;
	      valid      <= 0;
	   end
	   21: begin
	      sr1[65:48] <= data_in[17:0];
	      sr0[21:0]  <= data_in[39:18];
	      sr0[65:22] <= 0;
	      valid      <= 1;
	   end
	   22: begin
	      sr1[21:0]  <= sr0[21:0];
	      sr1[61:22] <= data_in[39:0];
	      sr0[65:0]  <= 0;
	      valid      <= 0;
	   end
	   23: begin
	      sr1[65:62] <= data_in[3:0];
	      sr0[35:0]  <= data_in[39:4];
	      sr0[65:36] <= 0;
	      valid      <= 1;
	   end
	   24: begin
	      sr1[35:0]  <= sr0[35:0];
	      sr1[65:36] <= data_in[29:0];
	      sr0[9:0]   <= data_in[39:30];
	      valid      <= 1;
	   end
	   25: begin
	      sr1[9:0]   <= sr0[9:0];
	      sr1[49:10] <= data_in[39:0];
	      sr0[65:0]  <= 0;
	      valid      <= 0;
	   end
	   26: begin
	      sr1[65:50] <= data_in[15:0];
	      sr0[23:0]  <= data_in[39:16];
	      sr0[65:24] <= 0;
	      valid      <= 1;
	   end
	   27: begin
	      sr1[23:0]  <= sr0[23:0];
	      sr1[63:24] <= data_in[39:0];
	      sr0[65:0]  <= 0;
	      valid      <= 0;
	   end
	   28: begin
	      sr1[65:64] <= data_in[1:0];
	      sr0[37:0]  <= data_in[39:2];
	      sr0[65:38] <= 0;
	      valid      <= 1;
	   end
	   29: begin
	      sr1[37:0]  <= sr0[37:0];
	      sr1[65:38] <= data_in[27:0];
	      sr0[11:0]  <= data_in[39:28];
	      valid      <= 1;
	   end
	   30: begin
	      sr1[11:0]  <= sr0[11:0];
	      sr1[51:12] <= data_in[39:0];
	      sr0[65:0]  <= 0;
	      valid      <= 0;
	   end
	   31: begin
	      sr1[65:52] <= data_in[13:0];
	      sr0[25:0]  <= data_in[39:14];
	      sr0[65:26] <= 0;
	      valid      <= 1;
	   end
	   32: begin
	      sr1[25:0]  <= sr0[25:0];
	      sr1[65:26] <= data_in[39:0];
	      sr0[65:0]  <= 0;
	      valid      <= 1;
	   end
	 endcase // case (state)
      end
   end

   always @ (posedge clk_in /*AUTOSENSE*/ or posedge reset) begin
      if (reset) begin
	 state <= 7'h0;
      end
      else begin
	 state <= (state[5]) ? 7'h0 : (state + 1'b1);
      end
   end

   always @ (posedge clk_in /*AUTOSENSE*/ or posedge reset) begin
      if (reset) begin
	 data_out <= 66'h0;
      end
      else if (valid == 1'b1) begin
	 data_out <= sr1;
      end
   end
   
   always @ (posedge clk_in /*AUTOSENSE*/ or posedge reset) begin
      if (reset) begin
	 data_valid <= 1'b0;
      end
      else begin
	 data_valid <= valid;
      end
   end
   
  
endmodule // sonic_gearbox_40_66

			    

//-----------------------------------------------------------------------------------------
// Copyright 2011 Cornell University. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification, are
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

