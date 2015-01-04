//////////////////////////////////////////////////////////////////////////////////////////////
// File : encoder.v
//-----------------------------------------------------------------------------
//**************************************************************************
// 
//     XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION "AS IS"
//     SOLELY FOR USE IN DEVELOPING PROGRAMS AND SOLUTIONS FOR
//     XILINX DEVICES.  BY PROVIDING THIS DESIGN, CODE, OR INFORMATION
//     AS ONE POSSIBLE IMPLEMENTATION OF THIS FEATURE, APPLICATION
//     OR STANDARD, XILINX IS MAKING NO REPRESENTATION THAT THIS
//     IMPLEMENTATION IS FREE FROM ANY CLAIMS OF INFRINGEMENT,
//     AND YOU ARE RESPONSIBLE FOR OBTAINING ANY RIGHTS YOU MAY REQUIRE
//     FOR YOUR IMPLEMENTATION.  XILINX EXPRESSLY DISCLAIMS ANY
//     WARRANTY WHATSOEVER WITH RESPECT TO THE ADEQUACY OF THE
//     IMPLEMENTATION, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OR
//     REPRESENTATIONS THAT THIS IMPLEMENTATION IS FREE FROM CLAIMS OF
//     INFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//     FOR A PARTICULAR PURPOSE.
//
//     (c) Copyright 2003 Xilinx, Inc.
//     All rights reserved.
//
//**************************************************************************
//
//         
// Revision 1.0
//
//     Modification History:                                                   
//     Date     Init          Description                                
//   --------  ------ ---------------------------------------------------------
//   9/15/2003   MD     Initial release.
//-------------------------------------------------------------------------------
// Description:
//
//-----------------------------------------------------------------------------
// Description : The encoder takes the 64-bit XGMII formatted data from the 
// fifo and convertes it to the 66-bit scheme given in section 49.2.4 of the 
// IEEE P802.3ae specification.
//-----------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module encoder (clk, xgmii_txd, xgmii_txc, data_out, t_type, init, enable);

   input clk; 
   input[63:0] xgmii_txd; 
   input[7:0] xgmii_txc; 
   output[65:0] data_out; 
   reg[65:0] data_out;
   output [2:0] t_type; 
   reg [2:0] t_type;
   input init; 
   input enable; 

   //---------------------------------------------------------------------------------
   // Signals used to indicate what type of data is in each of the pre-xgmii data lanes.
   //---------------------------------------------------------------------------------
   // Lane 0
   reg lane_0_data; 
   reg lane_0_control; 
   reg lane_0_idle; 
   reg lane_0_start; 
   reg lane_0_terminate; 
   reg lane_0_error; 
   reg lane_0_seq; 
   reg lane_0_res0; 
   reg lane_0_res1; 
   reg lane_0_res2; 
   reg lane_0_res3; 
   reg lane_0_res4; 
   reg lane_0_res5; 
   reg lane_0_seqr; 
   // Lane 1
   reg lane_1_data; 
   reg lane_1_control; 
   reg lane_1_idle; 
   reg lane_1_terminate; 
   reg lane_1_res0; 
   reg lane_1_res1; 
   reg lane_1_res2; 
   reg lane_1_res3; 
   reg lane_1_res4; 
   reg lane_1_res5; 
   // Lane 2
   reg lane_2_data; 
   reg lane_2_control; 
   reg lane_2_idle; 
   reg lane_2_terminate; 
   reg lane_2_res0; 
   reg lane_2_res1; 
   reg lane_2_res2; 
   reg lane_2_res3; 
   reg lane_2_res4; 
   reg lane_2_res5; 
   // Lane 3
   reg lane_3_data; 
   reg lane_3_control; 
   reg lane_3_idle; 
   reg lane_3_terminate; 
   reg lane_3_res0; 
   reg lane_3_res1; 
   reg lane_3_res2; 
   reg lane_3_res3; 
   reg lane_3_res4; 
   reg lane_3_res5; 
   // Lane 4
   reg lane_4_data; 
   reg lane_4_control; 
   reg lane_4_idle; 
   reg lane_4_start; 
   reg lane_4_terminate; 
   reg lane_4_seq; 
   reg lane_4_res0; 
   reg lane_4_res1; 
   reg lane_4_res2; 
   reg lane_4_res3; 
   reg lane_4_res4; 
   reg lane_4_res5; 
   reg lane_4_seqr; 
   // Lane 5
   reg lane_5_data; 
   reg lane_5_control; 
   reg lane_5_idle; 
   reg lane_5_terminate; 
   reg lane_5_res0; 
   reg lane_5_res1; 
   reg lane_5_res2; 
   reg lane_5_res3; 
   reg lane_5_res4; 
   reg lane_5_res5; 
   // Lane 6
   reg lane_6_data; 
   reg lane_6_control; 
   reg lane_6_idle; 
   reg lane_6_terminate; 
   reg lane_6_res0; 
   reg lane_6_res1; 
   reg lane_6_res2; 
   reg lane_6_res3; 
   reg lane_6_res4; 
   reg lane_6_res5; 
   // Lane 7
   reg lane_7_data; 
   reg lane_7_control; 
   reg lane_7_idle; 
   reg lane_7_terminate; 
   reg lane_7_res0; 
   reg lane_7_res1; 
   reg lane_7_res2; 
   reg lane_7_res3; 
   reg lane_7_res4; 
   reg lane_7_res5; 
   //---------------------------------------------------------------------------------
   // Internal data and control bus signals.
   //---------------------------------------------------------------------------------
   wire[63:0] int_txd; 
   wire[7:0] int_txc; 
   reg[63:0] reg_txd; 
   reg[7:0] reg_txc; 
   reg[63:0] reg_reg_txd; 
   reg[7:0] reg_reg_txc; 
   wire[7:0] int_txd_0; 
   wire[7:0] int_txd_1; 
   wire[7:0] int_txd_2; 
   wire[7:0] int_txd_3; 
   wire[7:0] int_txd_4; 
   wire[7:0] int_txd_5; 
   wire[7:0] int_txd_6; 
   wire[7:0] int_txd_7; 
   wire[65:0] int_data_out; 
   //---------------------------------------------------------------------------------
   // Signals for the type field generation.
   //---------------------------------------------------------------------------------
   reg[7:0] type_field; 
   wire type_1e; 
   wire type_2d; 
   wire type_33; 
   wire type_66; 
   wire type_55; 
   wire type_78; 
   wire type_4b; 
   wire type_87; 
   wire type_99; 
   wire type_aa; 
   wire type_b4; 
   wire type_cc; 
   wire type_d2; 
   wire type_e1; 
   wire type_ff; 
   wire type_illegal; 
   wire type_data; 
   reg int_error; 
   reg[16:0] type_reg; 
   reg[16:0] type_reg_reg; 
   //---------------------------------------------------------------------------------
   // Signals for the other output data fields.
   //---------------------------------------------------------------------------------
   reg[1:0] sync_field; 
   reg[55:0] data_field; 
   reg[6:0] lane_0_code; 
   reg[6:0] lane_1_code; 
   reg[6:0] lane_2_code; 
   reg[6:0] lane_3_code; 
   reg[6:0] lane_4_code; 
   reg[6:0] lane_5_code; 
   reg[6:0] lane_6_code; 
   reg[6:0] lane_7_code; 
   reg[3:0] o_code0; 
   reg[3:0] o_code4; 
   //---------------------------------------------------------------------------------
   // Signals to tell the transmit state machine what type of data is present at 
   // the input.
   //---------------------------------------------------------------------------------
   wire t_type_c; 
   wire t_type_s; 
   wire t_type_t; 
   wire t_type_d; 
   wire t_type_e; 
   //---------------------------------------------------------------------------------
   // A wee delay for simulation. The synthesis tool ignores this.
   //---------------------------------------------------------------------------------
   parameter dly = 1; 
   parameter [2:0] control = 3'b000;
   parameter [2:0] start = 3'b001;
   parameter [2:0] data = 3'b010;
   parameter [2:0] terminate = 3'b011;
   parameter [2:0] error = 3'b100;

   //o_code  <= \"0000\";
   assign int_txd = xgmii_txd ;
   assign int_txc = xgmii_txc ;
   //-------------------------------------------------------------------------------
   // Split the data into the 8 lanes.
   //-------------------------------------------------------------------------------
   assign int_txd_0 = int_txd[7:0] ;
   assign int_txd_1 = int_txd[15:8] ;
   assign int_txd_2 = int_txd[23:16] ;
   assign int_txd_3 = int_txd[31:24] ;
   assign int_txd_4 = int_txd[39:32] ;
   assign int_txd_5 = int_txd[47:40] ;
   assign int_txd_6 = int_txd[55:48] ;
   assign int_txd_7 = int_txd[63:56] ;

   //-------------------------------------------------------------------------------
   // Register the txd and txc signals. This is to maintain the timing 
   // relationship between the data and the control signals that are generated 
   // in this design.
   //-------------------------------------------------------------------------------
   always @(posedge init or posedge clk)
   begin // regips
      if (init == 1'b1)
      begin
         reg_txd <= #dly {64{1'b0}} ; 
         reg_txc <= #dly {8{1'b0}} ; 
         reg_reg_txd <= #dly {64{1'b0}} ; 
         reg_reg_txc <= #dly {8{1'b0}} ; 
      end
      else
      begin
         if (enable == 1'b1)
         begin
            reg_txd <= #dly int_txd ; 
            reg_txc <= #dly int_txc ; 
            reg_reg_txd <= #dly reg_txd ; 
            reg_reg_txc <= #dly reg_txc ; 
         end 
      end 
   end 

   //-------------------------------------------------------------------------------
   // Generate the lane 0 data and control signals. These are dependent on just the 
   // TXC(0) input from the MAC. 0 indicates data, 1 indicates control.
   //-------------------------------------------------------------------------------
   always @(posedge init or posedge clk)
   begin // dl0_dc_gen
      if (init == 1'b1)
      begin
         lane_0_data <= #dly 1'b0 ; 
         lane_0_control <= #dly 1'b0 ; 
      end
      else
      begin
         if (enable == 1'b1)
         begin
            lane_0_data <= #dly ~(int_txc[0]) ; 
            lane_0_control <= #dly int_txc[0] ; 
         end 
      end 
   end 

   //-------------------------------------------------------------------------------
   // Generate the lane 0 specific control signals. Here we decode the XGMII_TXD 
   // data to determine what type of control character has been transmitted.
   //-------------------------------------------------------------------------------
   always @(posedge init or posedge clk)
   begin // dl0_sc_gen
      if (init == 1'b1)
      begin
         lane_0_idle <= #dly 1'b0 ; 
         lane_0_start <= #dly 1'b0 ; 
         lane_0_terminate <= #dly 1'b0 ; 
         lane_0_error <= #dly 1'b0 ; 
         lane_0_seq <= #dly 1'b0 ; 
         lane_0_res0 <= #dly 1'b0 ; 
         lane_0_res1 <= #dly 1'b0 ; 
         lane_0_res2 <= #dly 1'b0 ; 
         lane_0_res3 <= #dly 1'b0 ; 
         lane_0_res4 <= #dly 1'b0 ; 
         lane_0_res5 <= #dly 1'b0 ; 
         lane_0_seqr <= #dly 1'b0 ; 
      end
      else
      begin
         if (enable == 1'b1)
         begin
            // Idle = 0x07
            lane_0_idle <= #dly ~(int_txd_0[7]) & ~(int_txd_0[6]) & ~(int_txd_0[5]) & ~(int_txd_0[4]) & ~(int_txd_0[3]) & int_txd_0[2] & int_txd_0[1] & int_txd_0[0] & int_txc[0] ; 
            // Start = 0xFB
            lane_0_start <= #dly int_txd_0[7] & int_txd_0[6] & int_txd_0[5] & int_txd_0[4] & int_txd_0[3] & ~(int_txd_0[2]) & int_txd_0[1] & int_txd_0[0] & int_txc[0] ; 
            // Terminate = 0xFD
            lane_0_terminate <= #dly int_txd_0[7] & int_txd_0[6] & int_txd_0[5] & int_txd_0[4] & int_txd_0[3] & int_txd_0[2] & ~(int_txd_0[1]) & int_txd_0[0] & int_txc[0] ; 
            // Error = 0xFE
            lane_0_error <= #dly int_txd_0[7] & int_txd_0[6] & int_txd_0[5] & int_txd_0[4] & int_txd_0[3] & int_txd_0[2] & int_txd_0[1] & ~(int_txd_0[0]) & int_txc[0] ; 
            // Sequence = 0x9C
            lane_0_seq <= #dly int_txd_0[7] & ~(int_txd_0[6]) & ~(int_txd_0[5]) & int_txd_0[4] & int_txd_0[3] & int_txd_0[2] & ~(int_txd_0[1]) & ~(int_txd_0[0]) & int_txc[0] ; 
            // Reserved 0
            lane_0_res0 <= #dly ~(int_txd_0[7]) & ~(int_txd_0[6]) & ~(int_txd_0[5]) & int_txd_0[4] & int_txd_0[3] & int_txd_0[2] & ~(int_txd_0[1]) & ~(int_txd_0[0]) & int_txc[0] ; 
            // Reserved 1
            lane_0_res1 <= #dly ~(int_txd_0[7]) & ~(int_txd_0[6]) & int_txd_0[5] & int_txd_0[4] & int_txd_0[3] & int_txd_0[2] & ~(int_txd_0[1]) & ~(int_txd_0[0]) & int_txc[0] ; 
            // Reserved 2
            lane_0_res2 <= #dly ~(int_txd_0[7]) & int_txd_0[6] & int_txd_0[5] & int_txd_0[4] & int_txd_0[3] & int_txd_0[2] & ~(int_txd_0[1]) & ~(int_txd_0[0]) & int_txc[0] ; 
            // Reserved 3
            lane_0_res3 <= #dly int_txd_0[7] & ~(int_txd_0[6]) & int_txd_0[5] & int_txd_0[4] & int_txd_0[3] & int_txd_0[2] & ~(int_txd_0[1]) & ~(int_txd_0[0]) & int_txc[0] ; 
            // Reserved 4
            lane_0_res4 <= #dly int_txd_0[7] & int_txd_0[6] & ~(int_txd_0[5]) & int_txd_0[4] & int_txd_0[3] & int_txd_0[2] & ~(int_txd_0[1]) & ~(int_txd_0[0]) & int_txc[0] ; 
            // Reserved 5
            lane_0_res5 <= #dly int_txd_0[7] & int_txd_0[6] & int_txd_0[5] & int_txd_0[4] & ~(int_txd_0[3]) & int_txd_0[2] & int_txd_0[1] & int_txd_0[0] & int_txc[0] ; 
            // Reserved Ordered Set
            lane_0_seqr <= #dly ~(int_txd_0[7]) & int_txd_0[6] & ~(int_txd_0[5]) & ~(int_txd_0[4]) & int_txd_0[3] & int_txd_0[2] & ~(int_txd_0[1]) & ~(int_txd_0[0]) & int_txc[0] ; 
         end 
      end 
   end 

   //-------------------------------------------------------------------------------
   // Do the same as above for all the other data lanes.
   //-------------------------------------------------------------------------------
   //-------------------------------------------------------------------------------
   // Lane 1
   //-------------------------------------------------------------------------------
   always @(posedge init or posedge clk)
   begin // dl1_dc_gen
      if (init == 1'b1)
      begin
         lane_1_data <= #dly 1'b0 ; 
         lane_1_control <= #dly 1'b0 ; 
      end
      else
      begin
         if (enable == 1'b1)
         begin
            lane_1_data <= #dly ~(int_txc[1]) ; 
            lane_1_control <= #dly int_txc[1] ; 
         end 
      end 
   end 

   //-------------------------------------------------------------------------------
   // Generate the lane 1 specific control signals. These are the same as above (lane 0)
   // but without the start or sequence detection as these can only occur in lanes 
   // 0 or 4. In addition I have designed the MAC transmitter so that an error 
   // character can only occur in lane 0 and so there is no error detection on this lane.
   //-------------------------------------------------------------------------------
   always @(posedge init or posedge clk)
   begin// dl1_sc_gen
      if (init == 1'b1)
      begin
         lane_1_idle <= #dly 1'b0 ; 
         lane_1_terminate <= #dly 1'b0 ; 
         lane_1_res0 <= #dly 1'b0 ; 
         lane_1_res1 <= #dly 1'b0 ; 
         lane_1_res2 <= #dly 1'b0 ; 
         lane_1_res3 <= #dly 1'b0 ; 
         lane_1_res4 <= #dly 1'b0 ; 
         lane_1_res5 <= #dly 1'b0 ; 
      end
      else
      begin
         if (enable == 1'b1)
         begin
            // Idle = 0x07
            lane_1_idle <= #dly ~(int_txd_1[7]) & ~(int_txd_1[6]) & ~(int_txd_1[5]) & ~(int_txd_1[4]) & ~(int_txd_1[3]) & int_txd_1[2] & int_txd_1[1] & int_txd_1[0] & int_txc[1] ; 
            // Terminate = 0xFD
            lane_1_terminate <= #dly int_txd_1[7] & int_txd_1[6] & int_txd_1[5] & int_txd_1[4] & int_txd_1[3] & int_txd_1[2] & ~(int_txd_1[1]) & int_txd_1[0] & int_txc[1] ; 
            // Reserved 0
            lane_1_res0 <= #dly ~(int_txd_1[7]) & ~(int_txd_1[6]) & ~(int_txd_1[5]) & int_txd_1[4] & int_txd_1[3] & int_txd_1[2] & ~(int_txd_1[1]) & ~(int_txd_1[0]) & int_txc[1] ; 
            // Reserved 1
            lane_1_res1 <= #dly ~(int_txd_0[7]) & ~(int_txd_1[6]) & int_txd_1[5] & int_txd_1[4] & int_txd_1[3] & int_txd_1[2] & ~(int_txd_1[1]) & ~(int_txd_1[0]) & int_txc[1] ; 
            // Reserved 2
            lane_1_res2 <= #dly ~(int_txd_1[7]) & int_txd_1[6] & int_txd_1[5] & int_txd_1[4] & int_txd_1[3] & int_txd_1[2] & ~(int_txd_1[1]) & ~(int_txd_1[0]) & int_txc[1] ; 
            // Reserved 3
            lane_1_res3 <= #dly int_txd_1[7] & ~(int_txd_1[6]) & int_txd_1[5] & int_txd_1[4] & int_txd_1[3] & int_txd_1[2] & ~(int_txd_1[1]) & ~(int_txd_1[0]) & int_txc[1] ; 
            // Reserved 4
            lane_1_res4 <= #dly int_txd_1[7] & int_txd_1[6] & ~(int_txd_1[5]) & int_txd_1[4] & int_txd_1[3] & int_txd_1[2] & ~(int_txd_1[1]) & ~(int_txd_1[0]) & int_txc[1] ; 
            // Reserved 5
            lane_1_res5 <= #dly int_txd_1[7] & int_txd_1[6] & int_txd_1[5] & int_txd_1[4] & ~(int_txd_1[3]) & int_txd_1[2] & int_txd_1[1] & int_txd_1[0] & int_txc[1] ; 
         end 
      end 
   end 

   //-------------------------------------------------------------------------------
   // Lane 2
   //-------------------------------------------------------------------------------
   always @(posedge init or posedge clk)
   begin // dl2_dc_gen
      if (init == 1'b1)
      begin
         lane_2_data <= #dly 1'b0 ; 
         lane_2_control <= #dly 1'b0 ; 
         lane_2_idle <= #dly 1'b0 ; 
         lane_2_terminate <= #dly 1'b0 ; 
         lane_2_res0 <= #dly 1'b0 ; 
         lane_2_res1 <= #dly 1'b0 ; 
         lane_2_res2 <= #dly 1'b0 ; 
         lane_2_res3 <= #dly 1'b0 ; 
         lane_2_res4 <= #dly 1'b0 ; 
         lane_2_res5 <= #dly 1'b0 ; 
      end
      else
      begin
         if (enable == 1'b1)
         begin
            lane_2_data <= #dly ~(int_txc[2]) ; 
            lane_2_control <= #dly int_txc[2] ; 
            // Idle = 0x07
            lane_2_idle <= #dly ~(int_txd_2[7]) & ~(int_txd_2[6]) & ~(int_txd_2[5]) & ~(int_txd_2[4]) & ~(int_txd_2[3]) & int_txd_2[2] & int_txd_2[1] & int_txd_2[0] & int_txc[2] ; 
            // Terminate = 0xFD
            lane_2_terminate <= #dly int_txd_2[7] & int_txd_2[6] & int_txd_2[5] & int_txd_2[4] & int_txd_2[3] & int_txd_2[2] & ~(int_txd_2[1]) & int_txd_2[0] & int_txc[2] ; 
            // Reserved 0
            lane_2_res0 <= #dly ~(int_txd_2[7]) & ~(int_txd_2[6]) & ~(int_txd_2[5]) & int_txd_2[4] & int_txd_2[3] & int_txd_2[2] & ~(int_txd_2[1]) & ~(int_txd_2[0]) & int_txc[2] ; 
            // Reserved 1
            lane_2_res1 <= #dly ~(int_txd_2[7]) & ~(int_txd_2[6]) & int_txd_2[5] & int_txd_2[4] & int_txd_2[3] & int_txd_2[2] & ~(int_txd_2[1]) & ~(int_txd_2[0]) & int_txc[2] ; 
            // Reserved 2
            lane_2_res2 <= #dly ~(int_txd_2[7]) & int_txd_2[6] & int_txd_2[5] & int_txd_2[4] & int_txd_2[3] & int_txd_2[2] & ~(int_txd_2[1]) & ~(int_txd_2[0]) & int_txc[2] ; 
            // Reserved 3
            lane_2_res3 <= #dly int_txd_2[7] & ~(int_txd_2[6]) & int_txd_2[5] & int_txd_2[4] & int_txd_2[3] & int_txd_2[2] & ~(int_txd_2[1]) & ~(int_txd_2[0]) & int_txc[2] ; 
            // Reserved 4
            lane_2_res4 <= #dly int_txd_2[7] & int_txd_2[6] & ~(int_txd_2[5]) & int_txd_2[4] & int_txd_2[3] & int_txd_2[2] & ~(int_txd_2[1]) & ~(int_txd_2[0]) & int_txc[2] ; 
            // Reserved 5
            lane_2_res5 <= #dly int_txd_2[7] & int_txd_2[6] & int_txd_2[5] & int_txd_2[4] & ~(int_txd_2[3]) & int_txd_2[2] & int_txd_2[1] & int_txd_2[0] & int_txc[2] ; 
         end 
      end 
   end 

   //-------------------------------------------------------------------------------
   // Lane 3
   //-------------------------------------------------------------------------------
   always @(posedge init or posedge clk)
   begin // dl3_dc_gen
      if (init == 1'b1)
      begin
         lane_3_data <= #dly 1'b0 ; 
         lane_3_control <= #dly 1'b0 ; 
         lane_3_idle <= #dly 1'b0 ; 
         lane_3_terminate <= #dly 1'b0 ; 
         lane_3_res0 <= #dly 1'b0 ; 
         lane_3_res1 <= #dly 1'b0 ; 
         lane_3_res2 <= #dly 1'b0 ; 
         lane_3_res3 <= #dly 1'b0 ; 
         lane_3_res4 <= #dly 1'b0 ; 
         lane_3_res5 <= #dly 1'b0 ; 
      end
      else
      begin
         if (enable == 1'b1)
         begin
            lane_3_data <= #dly ~(int_txc[3]) ; 
            lane_3_control <= #dly int_txc[3] ; 
            // Idle = 0x07
            lane_3_idle <= #dly ~(int_txd_3[7]) & ~(int_txd_3[6]) & ~(int_txd_3[5]) & ~(int_txd_3[4]) & ~(int_txd_3[3]) & int_txd_3[2] & int_txd_3[1] & int_txd_3[0] & int_txc[3] ; 
            // Terminate = 0xFD
            lane_3_terminate <= #dly int_txd_3[7] & int_txd_3[6] & int_txd_3[5] & int_txd_3[4] & int_txd_3[3] & int_txd_3[2] & ~(int_txd_3[1]) & int_txd_3[0] & int_txc[3] ; 
            // Reserved 0
            lane_3_res0 <= #dly ~(int_txd_3[7]) & ~(int_txd_3[6]) & ~(int_txd_3[5]) & int_txd_3[4] & int_txd_3[3] & int_txd_3[2] & ~(int_txd_3[1]) & ~(int_txd_3[0]) & int_txc[3] ; 
            // Reserved 1
            lane_3_res1 <= #dly ~(int_txd_3[7]) & ~(int_txd_3[6]) & int_txd_3[5] & int_txd_3[4] & int_txd_3[3] & int_txd_3[2] & ~(int_txd_3[1]) & ~(int_txd_3[0]) & int_txc[3] ; 
            // Reserved 2
            lane_3_res2 <= #dly ~(int_txd_3[7]) & int_txd_3[6] & int_txd_3[5] & int_txd_3[4] & int_txd_3[3] & int_txd_3[2] & ~(int_txd_3[1]) & ~(int_txd_3[0]) & int_txc[3] ; 
            // Reserved 3
            lane_3_res3 <= #dly int_txd_3[7] & ~(int_txd_3[6]) & int_txd_3[5] & int_txd_3[4] & int_txd_3[3] & int_txd_3[2] & ~(int_txd_3[1]) & ~(int_txd_3[0]) & int_txc[3] ; 
            // Reserved 4
            lane_3_res4 <= #dly int_txd_3[7] & int_txd_3[6] & ~(int_txd_3[5]) & int_txd_3[4] & int_txd_3[3] & int_txd_3[2] & ~(int_txd_3[1]) & ~(int_txd_3[0]) & int_txc[3] ; 
            // Reserved 5
            lane_3_res5 <= #dly int_txd_3[7] & int_txd_3[6] & int_txd_3[5] & int_txd_3[4] & ~(int_txd_3[3]) & int_txd_3[2] & int_txd_3[1] & int_txd_3[0] & int_txc[3] ; 
         end 
      end 
   end 

   //-------------------------------------------------------------------------------
   // Lane 4
   //-------------------------------------------------------------------------------
   always @(posedge init or posedge clk)
   begin // dl4_dc_gen
      if (init == 1'b1)
      begin
         lane_4_data <= #dly 1'b0 ; 
         lane_4_control <= #dly 1'b0 ; 
      end
      else
      begin
         if (enable == 1'b1)
         begin
            lane_4_data <= #dly ~(int_txc[4]) ; 
            lane_4_control <= #dly int_txc[4] ; 
         end 
      end 
   end 

   //-------------------------------------------------------------------------------
   // Generate the lane 4 specific control signals. Here we decode the XGMII_TXD 
   // data to determine what type of control character has been transmitted. The 
   // start and sequence characters can appear on this lane.
   //-------------------------------------------------------------------------------
   always @(posedge init or posedge clk)
   begin // dl4_sc_gen
      if (init == 1'b1)
      begin
         lane_4_idle <= #dly 1'b0 ; 
         lane_4_start <= #dly 1'b0 ; 
         lane_4_terminate <= #dly 1'b0 ; 
         lane_4_seq <= #dly 1'b0 ; 
         lane_4_res0 <= #dly 1'b0 ; 
         lane_4_res1 <= #dly 1'b0 ; 
         lane_4_res2 <= #dly 1'b0 ; 
         lane_4_res3 <= #dly 1'b0 ; 
         lane_4_res4 <= #dly 1'b0 ; 
         lane_4_res5 <= #dly 1'b0 ; 
         lane_4_seqr <= #dly 1'b0 ; 
      end
      else
      begin
         if (enable == 1'b1)
         begin
            // Idle = 0x07
            lane_4_idle <= #dly ~(int_txd_4[7]) & ~(int_txd_4[6]) & ~(int_txd_4[5]) & ~(int_txd_4[4]) & ~(int_txd_4[3]) & int_txd_4[2] & int_txd_4[1] & int_txd_4[0] & int_txc[4] ; 
            // Start = 0xFB
            lane_4_start <= #dly int_txd_4[7] & int_txd_4[6] & int_txd_4[5] & int_txd_4[4] & int_txd_4[3] & ~(int_txd_4[2]) & int_txd_4[1] & int_txd_4[0] & int_txc[4] ; 
            // Terminate = 0xFD
            lane_4_terminate <= #dly int_txd_4[7] & int_txd_4[6] & int_txd_4[5] & int_txd_4[4] & int_txd_4[3] & int_txd_4[2] & ~(int_txd_4[1]) & int_txd_4[0] & int_txc[4] ; 
            // Sequence = 0x9C
            lane_4_seq <= #dly int_txd_4[7] & ~(int_txd_4[6]) & ~(int_txd_4[5]) & int_txd_4[4] & int_txd_4[3] & int_txd_4[2] & ~(int_txd_4[1]) & ~(int_txd_4[0]) & int_txc[4] ; 
            // Reserved 0
            lane_4_res0 <= #dly ~(int_txd_4[7]) & ~(int_txd_4[6]) & ~(int_txd_4[5]) & int_txd_4[4] & int_txd_4[3] & int_txd_4[2] & ~(int_txd_4[1]) & ~(int_txd_4[0]) & int_txc[4] ; 
            // Reserved 1
            lane_4_res1 <= #dly ~(int_txd_4[7]) & ~(int_txd_4[6]) & int_txd_4[5] & int_txd_4[4] & int_txd_4[3] & int_txd_4[2] & ~(int_txd_4[1]) & ~(int_txd_4[0]) & int_txc[4] ; 
            // Reserved 2
            lane_4_res2 <= #dly ~(int_txd_4[7]) & int_txd_4[6] & int_txd_4[5] & int_txd_4[4] & int_txd_4[3] & int_txd_4[2] & ~(int_txd_4[1]) & ~(int_txd_4[0]) & int_txc[4] ; 
            // Reserved 3
            lane_4_res3 <= #dly int_txd_4[7] & ~(int_txd_4[6]) & int_txd_4[5] & int_txd_4[4] & int_txd_4[3] & int_txd_4[2] & ~(int_txd_4[1]) & ~(int_txd_4[0]) & int_txc[4] ; 
            // Reserved 4
            lane_4_res4 <= #dly int_txd_4[7] & int_txd_4[6] & ~(int_txd_4[5]) & int_txd_4[4] & int_txd_4[3] & int_txd_4[2] & ~(int_txd_4[1]) & ~(int_txd_4[0]) & int_txc[4] ; 
            // Reserved 5
            lane_4_res5 <= #dly int_txd_4[7] & int_txd_4[6] & int_txd_4[5] & int_txd_4[4] & ~(int_txd_4[3]) & int_txd_4[2] & int_txd_4[1] & int_txd_4[0] & int_txc[4] ; 
            // Reserved Ordered Set
            lane_4_seqr <= #dly ~(int_txd_4[7]) & int_txd_4[6] & ~(int_txd_4[5]) & ~(int_txd_4[4]) & int_txd_4[3] & int_txd_4[2] & ~(int_txd_4[1]) & ~(int_txd_4[0]) & int_txc[4] ; 
         end 
      end 
   end 

   //-------------------------------------------------------------------------------
   // Lane 5
   //-------------------------------------------------------------------------------
   always @(posedge init or posedge clk)
   begin // dl5_dc_gen
      if (init == 1'b1)
      begin
         lane_5_data <= #dly 1'b0 ; 
         lane_5_control <= #dly 1'b0 ; 
         lane_5_idle <= #dly 1'b0 ; 
         lane_5_terminate <= #dly 1'b0 ; 
         lane_5_res0 <= #dly 1'b0 ; 
         lane_5_res1 <= #dly 1'b0 ; 
         lane_5_res2 <= #dly 1'b0 ; 
         lane_5_res3 <= #dly 1'b0 ; 
         lane_5_res4 <= #dly 1'b0 ; 
         lane_5_res5 <= #dly 1'b0 ; 
      end
      else
      begin
         if (enable == 1'b1)
         begin
            lane_5_data <= #dly ~(int_txc[5]) ; 
            lane_5_control <= #dly int_txc[5] ; 
            // Idle = 0x07
            lane_5_idle <= #dly ~(int_txd_5[7]) & ~(int_txd_5[6]) & ~(int_txd_5[5]) & ~(int_txd_5[4]) & ~(int_txd_5[3]) & int_txd_5[2] & int_txd_5[1] & int_txd_5[0] & int_txc[5] ; 
            // Terminate = 0xFD
            lane_5_terminate <= #dly int_txd_5[7] & int_txd_5[6] & int_txd_5[5] & int_txd_5[4] & int_txd_5[3] & int_txd_5[2] & ~(int_txd_5[1]) & int_txd_5[0] & int_txc[5] ; 
            // Reserved 0
            lane_5_res0 <= #dly ~(int_txd_5[7]) & ~(int_txd_5[6]) & ~(int_txd_5[5]) & int_txd_5[4] & int_txd_5[3] & int_txd_5[2] & ~(int_txd_5[1]) & ~(int_txd_5[0]) & int_txc[5] ; 
            // Reserved 1
            lane_5_res1 <= #dly ~(int_txd_5[7]) & ~(int_txd_5[6]) & int_txd_5[5] & int_txd_5[4] & int_txd_5[3] & int_txd_5[2] & ~(int_txd_5[1]) & ~(int_txd_5[0]) & int_txc[5] ; 
            // Reserved 2
            lane_5_res2 <= #dly ~(int_txd_5[7]) & int_txd_5[6] & int_txd_5[5] & int_txd_5[4] & int_txd_5[3] & int_txd_5[2] & ~(int_txd_5[1]) & ~(int_txd_5[0]) & int_txc[5] ; 
            // Reserved 3
            lane_5_res3 <= #dly int_txd_5[7] & ~(int_txd_5[6]) & int_txd_5[5] & int_txd_5[4] & int_txd_5[3] & int_txd_5[2] & ~(int_txd_5[1]) & ~(int_txd_5[0]) & int_txc[5] ; 
            // Reserved 4
            lane_5_res4 <= #dly int_txd_5[7] & int_txd_5[6] & ~(int_txd_5[5]) & int_txd_5[4] & int_txd_5[3] & int_txd_5[2] & ~(int_txd_5[1]) & ~(int_txd_5[0]) & int_txc[5] ; 
            // Reserved 5
            lane_5_res5 <= #dly int_txd_5[7] & int_txd_5[6] & int_txd_5[5] & int_txd_5[4] & ~(int_txd_5[3]) & int_txd_5[2] & int_txd_5[1] & int_txd_5[0] & int_txc[5] ; 
         end 
      end 
   end 

   //-------------------------------------------------------------------------------
   // Lane 6
   //-------------------------------------------------------------------------------
   always @(posedge init or posedge clk)
   begin // dl6_dc_gen
      if (init == 1'b1)
      begin
         lane_6_data <= #dly 1'b0 ; 
         lane_6_control <= #dly 1'b0 ; 
         lane_6_idle <= #dly 1'b0 ; 
         lane_6_terminate <= #dly 1'b0 ; 
         lane_6_res0 <= #dly 1'b0 ; 
         lane_6_res1 <= #dly 1'b0 ; 
         lane_6_res2 <= #dly 1'b0 ; 
         lane_6_res3 <= #dly 1'b0 ; 
         lane_6_res4 <= #dly 1'b0 ; 
         lane_6_res5 <= #dly 1'b0 ; 
      end
      else
      begin
         if (enable == 1'b1)
         begin
            lane_6_data <= #dly ~(int_txc[6]) ; 
            lane_6_control <= #dly int_txc[6] ; 
            // Idle = 0x07
            lane_6_idle <= #dly ~(int_txd_6[7]) & ~(int_txd_6[6]) & ~(int_txd_6[5]) & ~(int_txd_6[4]) & ~(int_txd_6[3]) & int_txd_6[2] & int_txd_6[1] & int_txd_6[0] & int_txc[6] ; 
            // Terminate = 0xFD
            lane_6_terminate <= #dly int_txd_6[7] & int_txd_6[6] & int_txd_6[5] & int_txd_6[4] & int_txd_6[3] & int_txd_6[2] & ~(int_txd_6[1]) & int_txd_6[0] & int_txc[6] ; 
            // Reserved 0
            lane_6_res0 <= #dly ~(int_txd_6[7]) & ~(int_txd_6[6]) & ~(int_txd_6[5]) & int_txd_6[4] & int_txd_6[3] & int_txd_6[2] & ~(int_txd_6[1]) & ~(int_txd_6[0]) & int_txc[6] ; 
            // Reserved 1
            lane_6_res1 <= #dly ~(int_txd_6[7]) & ~(int_txd_6[6]) & int_txd_6[5] & int_txd_6[4] & int_txd_6[3] & int_txd_6[2] & ~(int_txd_6[1]) & ~(int_txd_6[0]) & int_txc[6] ; 
            // Reserved 2
            lane_6_res2 <= #dly ~(int_txd_6[7]) & int_txd_6[6] & int_txd_6[5] & int_txd_6[4] & int_txd_6[3] & int_txd_6[2] & ~(int_txd_6[1]) & ~(int_txd_6[0]) & int_txc[6] ; 
            // Reserved 3
            lane_6_res3 <= #dly int_txd_6[7] & ~(int_txd_6[6]) & int_txd_6[5] & int_txd_6[4] & int_txd_6[3] & int_txd_6[2] & ~(int_txd_6[1]) & ~(int_txd_6[0]) & int_txc[6] ; 
            // Reserved 4
            lane_6_res4 <= #dly int_txd_6[7] & int_txd_6[6] & ~(int_txd_6[5]) & int_txd_6[4] & int_txd_6[3] & int_txd_6[2] & ~(int_txd_6[1]) & ~(int_txd_6[0]) & int_txc[6] ; 
            // Reserved 5
            lane_6_res5 <= #dly int_txd_6[7] & int_txd_6[6] & int_txd_6[5] & int_txd_6[4] & ~(int_txd_6[3]) & int_txd_6[2] & int_txd_6[1] & int_txd_6[0] & int_txc[6] ; 
         end 
      end 
   end 

   //-------------------------------------------------------------------------------
   // Lane 7
   //-------------------------------------------------------------------------------
   always @(posedge init or posedge clk)
   begin // dl7_dc_gen
      if (init == 1'b1)
      begin
         lane_7_data <= #dly 1'b0 ; 
         lane_7_control <= #dly 1'b0 ; 
         lane_7_idle <= #dly 1'b0 ; 
         lane_7_terminate <= #dly 1'b0 ; 
         lane_7_res0 <= #dly 1'b0 ; 
         lane_7_res1 <= #dly 1'b0 ; 
         lane_7_res2 <= #dly 1'b0 ; 
         lane_7_res3 <= #dly 1'b0 ; 
         lane_7_res4 <= #dly 1'b0 ; 
         lane_7_res5 <= #dly 1'b0 ; 
      end
      else
      begin
         if (enable == 1'b1)
         begin
            lane_7_data <= #dly ~(int_txc[7]) ; 
            lane_7_control <= #dly int_txc[7] ; 
            // Idle = 0x07
            lane_7_idle <= #dly ~(int_txd_7[7]) & ~(int_txd_7[6]) & ~(int_txd_7[5]) & ~(int_txd_7[4]) & ~(int_txd_7[3]) & int_txd_7[2] & int_txd_7[1] & int_txd_7[0] & int_txc[7] ; 
            // Terminate = 0xFD
            lane_7_terminate <= #dly int_txd_7[7] & int_txd_7[6] & int_txd_7[5] & int_txd_7[4] & int_txd_7[3] & int_txd_7[2] & ~(int_txd_7[1]) & int_txd_7[0] & int_txc[7] ; 
            // Reserved 0
            lane_7_res0 <= #dly ~(int_txd_7[7]) & ~(int_txd_7[6]) & ~(int_txd_7[5]) & int_txd_7[4] & int_txd_7[3] & int_txd_7[2] & ~(int_txd_7[1]) & ~(int_txd_7[0]) & int_txc[7] ; 
            // Reserved 1
            lane_7_res1 <= #dly ~(int_txd_7[7]) & ~(int_txd_7[6]) & int_txd_7[5] & int_txd_7[4] & int_txd_7[3] & int_txd_7[2] & ~(int_txd_7[1]) & ~(int_txd_7[0]) & int_txc[7] ; 
            // Reserved 2
            lane_7_res2 <= #dly ~(int_txd_7[7]) & int_txd_7[6] & int_txd_7[5] & int_txd_7[4] & int_txd_7[3] & int_txd_7[2] & ~(int_txd_7[1]) & ~(int_txd_7[0]) & int_txc[7] ; 
            // Reserved 3
            lane_7_res3 <= #dly int_txd_7[7] & ~(int_txd_7[6]) & int_txd_7[5] & int_txd_7[4] & int_txd_7[3] & int_txd_7[2] & ~(int_txd_7[1]) & ~(int_txd_7[0]) & int_txc[7] ; 
            // Reserved 4
            lane_7_res4 <= #dly int_txd_7[7] & int_txd_7[6] & ~(int_txd_7[5]) & int_txd_7[4] & int_txd_7[3] & int_txd_7[2] & ~(int_txd_7[1]) & ~(int_txd_7[0]) & int_txc[7] ; 
            // Reserved 5
            lane_7_res5 <= #dly int_txd_7[7] & int_txd_7[6] & int_txd_7[5] & int_txd_7[4] & ~(int_txd_7[3]) & int_txd_7[2] & int_txd_7[1] & int_txd_7[0] & int_txc[7] ; 
         end 
      end 
   end 
   //-------------------------------------------------------------------------------
   // Decode the TXC input to decide on the value of the type field that is appended 
   // to the data stream. This is only present for double words that contain 
   // one or more control characters.
   //-------------------------------------------------------------------------------
   // All the data is control characters (usually idles) :-
   assign type_1e = lane_0_control & ~(lane_0_terminate) & ~(lane_0_error) & lane_1_control & lane_2_control & lane_3_control & lane_4_control & lane_5_control & lane_6_control & lane_7_control ;
   // The input contains control codes upto lane 3 but an ordered set from lane 4 onwards :-
   assign type_2d = lane_0_control & lane_1_control & lane_2_control & lane_3_control & lane_4_seq & lane_5_data & lane_6_data & lane_7_data ;
   // The input contains a start of packet in lane 4 :-
   assign type_33 = lane_0_control & lane_1_control & lane_2_control & lane_3_control & lane_4_start & lane_5_data & lane_6_data & lane_7_data ;
   // The input contains an ordered set in lanes 0 to 3 and the start of a packet 
   // in lanes 4 to 7 :-
   assign type_66 = lane_0_seq & lane_1_data & lane_2_data & lane_3_data & lane_4_start & lane_5_data & lane_6_data & lane_7_data ;
   // The input contains two ordered sets, one starting in lane 0 and the other in lane 4 :-
   assign type_55 = lane_0_seq & lane_1_data & lane_2_data & lane_3_data & lane_4_seq & lane_5_data & lane_6_data & lane_7_data ;
   // The input contains a start of packet in lane 0 :-
   assign type_78 = lane_0_start & lane_1_data & lane_2_data & lane_3_data & lane_4_data & lane_5_data & lane_6_data & lane_7_data ;
   // The input contains an ordered set starting in lane 0 and control characters 
   // in lanes 4 to 7 :-
   assign type_4b = lane_0_seq & lane_1_data & lane_2_data & lane_3_data & lane_4_control & lane_5_control & lane_6_control & lane_7_control ;
   // The following types are used to code inputs that contain the end of the packet.
   // The end of packet delimiter (terminate) can occur in any lane. There is a 
   // type field associated with each position.
   //
   // Terminate in lane 0 :-
   assign type_87 = lane_0_terminate & lane_1_control & lane_2_control & lane_3_control & lane_4_control & lane_5_control & lane_6_control & lane_7_control ;
   // Terminate in lane 1 :-
   assign type_99 = lane_0_data & lane_1_terminate & lane_2_control & lane_3_control & lane_4_control & lane_5_control & lane_6_control & lane_7_control ;
   // Terminate in lane 2 :-
   assign type_aa = lane_0_data & lane_1_data & lane_2_terminate & lane_3_control & lane_4_control & lane_5_control & lane_6_control & lane_7_control ;
   // Terminate in lane 3 :-
   assign type_b4 = lane_0_data & lane_1_data & lane_2_data & lane_3_terminate & lane_4_control & lane_5_control & lane_6_control & lane_7_control ;
   // Terminate in lane 4 :-
   assign type_cc = lane_0_data & lane_1_data & lane_2_data & lane_3_data & lane_4_terminate & lane_5_control & lane_6_control & lane_7_control ;
   // Terminate in lane 5 :-
   assign type_d2 = lane_0_data & lane_1_data & lane_2_data & lane_3_data & lane_4_data & lane_5_terminate & lane_6_control & lane_7_control ;
   // Terminate in lane 6 :-
   assign type_e1 = lane_0_data & lane_1_data & lane_2_data & lane_3_data & lane_4_data & lane_5_data & lane_6_terminate & lane_7_control ;
   // Terminate in lane 7 :-
   assign type_ff = lane_0_data & lane_1_data & lane_2_data & lane_3_data & lane_4_data & lane_5_data & lane_6_data & lane_7_terminate ;
   // None of the above scenarios means that the data is in an illegal format. 
   assign type_illegal = lane_0_control | lane_1_control | lane_2_control | lane_3_control | lane_4_control | lane_5_control | lane_6_control | lane_7_control ;
   assign type_data = lane_0_data & lane_1_data & lane_2_data & lane_3_data & lane_4_data & lane_5_data & lane_6_data & lane_7_data ;

   //-------------------------------------------------------------------------------
   // Translate these signals to give the actual type field output.
   // Prior to this the type signals above are registered as the delay through the 
   // above equations could be considerable.
   //-------------------------------------------------------------------------------
   always @(posedge init or posedge clk)
   begin // reg_type
      if (init == 1'b1)
      begin
         type_reg <= #dly {17{1'b0}} ; 
      end
      else
      begin
         if (enable == 1'b1)
         begin
            type_reg <= {type_data, type_illegal, type_ff, type_e1, type_d2, type_cc, type_b4, type_aa, type_99, type_87, type_4b, type_78, type_55, type_66, type_33, type_2d, type_1e} ; 
         end 
      end 
   end 

   //-------------------------------------------------------------------------------
   // Work out the ocode that is sent
   //-------------------------------------------------------------------------------
   always @(posedge init or posedge clk)
   begin // ocode0_gen
      if (init == 1'b1)
      begin
         o_code0 <= #dly {4{1'b0}} ; 
      end
      else
      begin
         if (lane_0_seqr == 1'b1)
         begin
            o_code0 <= #dly 4'b1111 ; 
         end
         else
         begin
            o_code0 <= #dly 4'b0000 ; 
         end 
      end 
   end 

   always @(posedge init or posedge clk)
   begin // ocode4_gen
      if (init == 1'b1)
      begin
         o_code4 <= #dly {4{1'b0}} ; 
      end
      else
      begin
         if (lane_4_seqr == 1'b1)
         begin
            o_code4 <= #dly 4'b1111 ; 
         end
         else
         begin
            o_code4 <= #dly 4'b0000 ; 
         end 
      end 
   end 

   always @(posedge init or posedge clk)
   begin // type_field_gen
      if (init == 1'b1)
      begin
         type_field <= #dly {8{1'b0}} ; 
      end
      else
      begin
         if (enable == 1'b1)
         begin
            if ((type_reg[0]) == 1'b1)
            begin
               type_field <= #dly 8'b00011110 ; 
            end
            else if ((type_reg[1]) == 1'b1)
            begin
               type_field <= #dly 8'b00101101 ; 
            end
            else if ((type_reg[2]) == 1'b1)
            begin
               type_field <= #dly 8'b00110011 ; 
            end
            else if ((type_reg[3]) == 1'b1)
            begin
               type_field <= #dly 8'b01100110 ; 
            end
            else if ((type_reg[4]) == 1'b1)
            begin
               type_field <= #dly 8'b01010101 ; 
            end
            else if ((type_reg[5]) == 1'b1)
            begin
               type_field <= #dly 8'b01111000 ; 
            end
            else if ((type_reg[6]) == 1'b1)
            begin
               type_field <= #dly 8'b01001011 ; 
            end
            else if ((type_reg[7]) == 1'b1)
            begin
               type_field <= #dly 8'b10000111 ; 
            end
            else if ((type_reg[8]) == 1'b1)
            begin
               type_field <= #dly 8'b10011001 ; 
            end
            else if ((type_reg[9]) == 1'b1)
            begin
               type_field <= #dly 8'b10101010 ; 
            end
            else if ((type_reg[10]) == 1'b1)
            begin
               type_field <= #dly 8'b10110100 ; 
            end
            else if ((type_reg[11]) == 1'b1)
            begin
               type_field <= #dly 8'b11001100 ; 
            end
            else if ((type_reg[12]) == 1'b1)
            begin
               type_field <= #dly 8'b11010010 ; 
            end
            else if ((type_reg[13]) == 1'b1)
            begin
               type_field <= #dly 8'b11100001 ; 
            end
            else if ((type_reg[14]) == 1'b1)
            begin
               type_field <= #dly 8'b11111111 ; 
            end
            else if ((type_reg[15]) == 1'b1)
            begin
               type_field <= #dly 8'b00011110 ; 
            end
            else
            begin
               // If the input doesn\'t contain a control character then the type field
               // is set to be the first data byte.
               type_field <= #dly reg_reg_txd[7:0] ; 
            end 
         end 
      end 
   end 

   //-------------------------------------------------------------------------------
   // Now figure out what the rest of the data output should be set to. This is 
   // given in Figure 49-7 in the spec.
   //-------------------------------------------------------------------------------
   //-------------------------------------------------------------------------------
   // Firstly the sync field. This is 01 for a data double and 10 for a double 
   // containing a control character.
   //-------------------------------------------------------------------------------
   always @(posedge init or posedge clk)
   begin // sync_field_gen
      if (init == 1'b1)
      begin
         sync_field <= #dly 2'b10 ; 
      end
      else
      begin
         if (enable == 1'b1)
         begin
            if (type_reg == 17'b10000000000000000)
            begin
               sync_field <= #dly 2'b10 ; 
            end
            else
            begin
               sync_field <= #dly 2'b01 ; 
            end 
         end 
      end 
   end 

   //-------------------------------------------------------------------------------
   // The remaining 7 bytes of the data output
   //-------------------------------------------------------------------------------
   //-------------------------------------------------------------------------------
   // The idle and error control characters are mapped from their 8-bit xgmii 
   // representation into a 7-bit output representation. Idle (0x07) maps to 0x00 
   // and error (0xFE) maps to 0x1e. The other control characters are encoded 
   // by the type field.
   //-------------------------------------------------------------------------------
   // Lane 0
   always @(posedge clk)
   begin // ctrl_code_gen_0
      if (enable == 1'b1)
      begin
         if (init == 1'b1 | lane_0_idle == 1'b1)
         begin
            lane_0_code <= #dly {7{1'b0}} ; 
         end
         else if (lane_0_res0 == 1'b1)
         begin
            lane_0_code <= #dly 7'b0101101 ; 
         end
         else if (lane_0_res1 == 1'b1)
         begin
            lane_0_code <= #dly 7'b0110011 ; 
         end
         else if (lane_0_res2 == 1'b1)
         begin
            lane_0_code <= #dly 7'b1001011 ; 
         end
         else if (lane_0_res3 == 1'b1)
         begin
            lane_0_code <= #dly 7'b1010101 ; 
         end
         else if (lane_0_res4 == 1'b1)
         begin
            lane_0_code <= #dly 7'b1100110 ; 
         end
         else if (lane_0_res5 == 1'b1)
         begin
            lane_0_code <= #dly 7'b1111000 ; 
         end
         else
         begin
            lane_0_code <= #dly 7'b0011110 ; 
         end
         //lane_0_code <= \"1111000\" after dly; 
      end  
   end 

   // Lane 1
   always @(posedge clk)
   begin // ctrl_code_gen_1
      if (enable == 1'b1)
      begin
         if (init == 1'b1 | lane_1_idle == 1'b1)
         begin
            lane_1_code <= #dly {7{1'b0}} ; 
         end
         else if (lane_1_res0 == 1'b1)
         begin
            lane_1_code <= #dly 7'b0101101 ; 
         end
         else if (lane_1_res1 == 1'b1)
         begin
            lane_1_code <= #dly 7'b0110011 ; 
         end
         else if (lane_1_res2 == 1'b1)
         begin
            lane_1_code <= #dly 7'b1001011 ; 
         end
         else if (lane_1_res3 == 1'b1)
         begin
            lane_1_code <= #dly 7'b1010101 ; 
         end
         else if (lane_1_res4 == 1'b1)
         begin
            lane_1_code <= #dly 7'b1100110 ; 
         end
         else if (lane_1_res5 == 1'b1)
         begin
            lane_1_code <= #dly 7'b1111000 ; 
         end
         else
         begin
            lane_1_code <= #dly 7'b0011110 ; 
         end
         //lane_1_code <= \"1111000\" after dly; 
      end  
   end 

   // Lane 2
   always @(posedge clk)
   begin // ctrl_code_gen_2
      if (enable == 1'b1)
      begin
         if (init == 1'b1 | lane_2_idle == 1'b1)
         begin
            lane_2_code <= #dly {7{1'b0}} ; 
         end
         else if (lane_2_res0 == 1'b1)
         begin
            lane_2_code <= #dly 7'b0101101 ; 
         end
         else if (lane_2_res1 == 1'b1)
         begin
            lane_2_code <= #dly 7'b0110011 ; 
         end
         else if (lane_2_res2 == 1'b1)
         begin
            lane_2_code <= #dly 7'b1001011 ; 
         end
         else if (lane_2_res3 == 1'b1)
         begin
            lane_2_code <= #dly 7'b1010101 ; 
         end
         else if (lane_2_res4 == 1'b1)
         begin
            lane_2_code <= #dly 7'b1100110 ; 
         end
         else if (lane_2_res5 == 1'b1)
         begin
            lane_2_code <= #dly 7'b1111000 ; 
         end
         else
         begin
            lane_2_code <= #dly 7'b0011110 ; 
         end
         //lane_2_code <= \"1111000\" after dly; 
      end  
   end 

   // Lane 3
   always @(posedge clk)
   begin // ctrl_code_gen_3
      if (enable == 1'b1)
      begin
         if (init == 1'b1 | lane_3_idle == 1'b1)
         begin
            lane_3_code <= #dly {7{1'b0}} ; 
         end
         else if (lane_3_res0 == 1'b1)
         begin
            lane_3_code <= #dly 7'b0101101 ; 
         end
         else if (lane_3_res1 == 1'b1)
         begin
            lane_3_code <= #dly 7'b0110011 ; 
         end
         else if (lane_3_res2 == 1'b1)
         begin
            lane_3_code <= #dly 7'b1001011 ; 
         end
         else if (lane_3_res3 == 1'b1)
         begin
            lane_3_code <= #dly 7'b1010101 ; 
         end
         else if (lane_3_res4 == 1'b1)
         begin
            lane_3_code <= #dly 7'b1100110 ; 
         end
         else if (lane_3_res5 == 1'b1)
         begin
            lane_3_code <= #dly 7'b1111000 ; 
         end
         else
         begin
            lane_3_code <= #dly 7'b0011110 ; 
         end
         //lane_3_code <= \"1111000\" after dly; 
      end  
   end 

   // Lane 4
   always @(posedge clk)
   begin // ctrl_code_gen_4
      if (enable == 1'b1)
      begin
         if (init == 1'b1 | lane_4_idle == 1'b1)
         begin
            lane_4_code <= #dly {7{1'b0}} ; 
         end
         else if (lane_4_res0 == 1'b1)
         begin
            lane_4_code <= #dly 7'b0101101 ; 
         end
         else if (lane_4_res1 == 1'b1)
         begin
            lane_4_code <= #dly 7'b0110011 ; 
         end
         else if (lane_4_res2 == 1'b1)
         begin
            lane_4_code <= #dly 7'b1001011 ; 
         end
         else if (lane_4_res3 == 1'b1)
         begin
            lane_4_code <= #dly 7'b1010101 ; 
         end
         else if (lane_4_res4 == 1'b1)
         begin
            lane_4_code <= #dly 7'b1100110 ; 
         end
         else if (lane_4_res5 == 1'b1)
         begin
            lane_4_code <= #dly 7'b1111000 ; 
         end
         else
         begin
            lane_4_code <= #dly 7'b0011110 ; 
         end
         //lane_4_code <= \"1111000\" after dly; 
      end  
   end 

   // Lane 5
   always @(posedge clk)
   begin // ctrl_code_gen_5
      if (enable == 1'b1)
      begin
         if (init == 1'b1 | lane_5_idle == 1'b1)
         begin
            lane_5_code <= #dly {7{1'b0}} ; 
         end
         else if (lane_5_res0 == 1'b1)
         begin
            lane_5_code <= #dly 7'b0101101 ; 
         end
         else if (lane_5_res1 == 1'b1)
         begin
            lane_5_code <= #dly 7'b0110011 ; 
         end
         else if (lane_5_res2 == 1'b1)
         begin
            lane_5_code <= #dly 7'b1001011 ; 
         end
         else if (lane_5_res3 == 1'b1)
         begin
            lane_5_code <= #dly 7'b1010101 ; 
         end
         else if (lane_5_res4 == 1'b1)
         begin
            lane_5_code <= #dly 7'b1100110 ; 
         end
         else if (lane_5_res5 == 1'b1)
         begin
            lane_5_code <= #dly 7'b1111000 ; 
         end
         else
         begin
            lane_5_code <= #dly 7'b0011110 ; 
         end
         //lane_5_code <= \"1111000\" after dly; 
      end  
   end 

   // Lane 6
   always @(posedge clk)
   begin // ctrl_code_gen_6
      if (enable == 1'b1)
      begin
         if (init == 1'b1 | lane_6_idle == 1'b1)
         begin
            lane_6_code <= #dly {7{1'b0}} ; 
         end
         else if (lane_6_res0 == 1'b1)
         begin
            lane_6_code <= #dly 7'b0101101 ; 
         end
         else if (lane_6_res1 == 1'b1)
         begin
            lane_6_code <= #dly 7'b0110011 ; 
         end
         else if (lane_6_res2 == 1'b1)
         begin
            lane_6_code <= #dly 7'b1001011 ; 
         end
         else if (lane_6_res3 == 1'b1)
         begin
            lane_6_code <= #dly 7'b1010101 ; 
         end
         else if (lane_6_res4 == 1'b1)
         begin
            lane_6_code <= #dly 7'b1100110 ; 
         end
         else if (lane_6_res5 == 1'b1)
         begin
            lane_6_code <= #dly 7'b1111000 ; 
         end
         else
         begin
            lane_6_code <= #dly 7'b0011110 ; 
         end
         //lane_6_code <= \"1111000\" after dly; 
      end  
   end 

   // Lane 7
   always @(posedge clk)
   begin // ctrl_code_gen_7
      if (enable == 1'b1)
      begin
         if (init == 1'b1 | lane_7_idle == 1'b1)
         begin
            lane_7_code <= #dly {7{1'b0}} ; 
         end
         else if (lane_7_res0 == 1'b1)
         begin
            lane_7_code <= #dly 7'b0101101 ; 
         end
         else if (lane_7_res1 == 1'b1)
         begin
            lane_7_code <= #dly 7'b0110011 ; 
         end
         else if (lane_7_res2 == 1'b1)
         begin
            lane_7_code <= #dly 7'b1001011 ; 
         end
         else if (lane_7_res3 == 1'b1)
         begin
            lane_7_code <= #dly 7'b1010101 ; 
         end
         else if (lane_7_res4 == 1'b1)
         begin
            lane_7_code <= #dly 7'b1100110 ; 
         end
         else if (lane_7_res5 == 1'b1)
         begin
            lane_7_code <= #dly 7'b1111000 ; 
         end
         else
         begin
            lane_7_code <= #dly 7'b0011110 ; 
         end
         //lane_7_code <= \"1111000\" after dly; 
      end  
   end 

   //-------------------------------------------------------------------------------
   // Rest of the data output depends on the type_field :-
   //-------------------------------------------------------------------------------
   always @(posedge init or posedge clk)
   begin // data_field_gen
      if (init == 1'b1)
      begin
         data_field <= #dly {56{1'b0}} ; 
         int_error <= #dly 1'b0 ; 
      end
      else
      begin
         if (enable == 1'b1)
         begin
            if ((type_reg[0]) == 1'b1)
            begin
               // type 0x1e
               data_field <= #dly {lane_7_code, lane_6_code, lane_5_code, lane_4_code, lane_3_code, lane_2_code, lane_1_code, lane_0_code} ; 
               int_error <= #dly 1'b0 ; 
            end
            else if ((type_reg[1]) == 1'b1)
            begin
               // type 0x2d
               data_field <= #dly {reg_reg_txd[63:40], o_code4, lane_3_code, lane_2_code, lane_1_code, lane_0_code} ; 
               int_error <= #dly 1'b0 ; 
            end
            else if ((type_reg[2]) == 1'b1)
            begin
               // type 0x33
               data_field <= #dly {reg_reg_txd[63:40], 4'b0000, lane_3_code, lane_2_code, lane_1_code, lane_0_code} ; 
               int_error <= #dly 1'b0 ; 
            end
            else if ((type_reg[3]) == 1'b1)
            begin
               // type 0x66
               data_field <= #dly {reg_reg_txd[63:40], 4'b0000, o_code0, reg_reg_txd[31:8]} ; 
               int_error <= #dly 1'b0 ; 
            end
            else if ((type_reg[4]) == 1'b1)
            begin
               // type 0x55
               data_field <= #dly {reg_reg_txd[63:40], o_code4, o_code0, reg_reg_txd[31:8]} ; 
               int_error <= #dly 1'b0 ; 
            end
            else if ((type_reg[5]) == 1'b1)
            begin
               // type 0x78
               data_field <= #dly reg_reg_txd[63:8] ; 
               int_error <= #dly 1'b0 ; 
            end
            else if ((type_reg[6]) == 1'b1)
            begin
               // type 0x4b
               data_field <= {lane_7_code, lane_6_code, lane_5_code, lane_4_code, o_code0, reg_reg_txd[31:8]} ; 
               int_error <= #dly 1'b0 ; 
            end
            else if ((type_reg[7]) == 1'b1)
            begin
               // type 0x87
               data_field <= #dly {lane_7_code, lane_6_code, lane_5_code, lane_4_code, lane_3_code, lane_2_code, lane_1_code, 7'b0000000} ; 
               int_error <= #dly 1'b0 ; 
            end
            else if ((type_reg[8]) == 1'b1)
            begin
               // type 0x99
               data_field <= #dly {lane_7_code, lane_6_code, lane_5_code, lane_4_code, lane_3_code, lane_2_code, 6'b000000, reg_reg_txd[7:0]} ; 
               int_error <= #dly 1'b0 ; 
            end
            else if ((type_reg[9]) == 1'b1)
            begin
               // type 0xaa
               data_field <= #dly {lane_7_code, lane_6_code, lane_5_code, lane_4_code, lane_3_code, 5'b00000, reg_reg_txd[15:0]} ; 
               int_error <= #dly 1'b0 ; 
            end
            else if ((type_reg[10]) == 1'b1)
            begin
               // type 0xb4
               data_field <= #dly {lane_7_code, lane_6_code, lane_5_code, lane_4_code, 4'b0000, reg_reg_txd[23:0]} ; 
               int_error <= #dly 1'b0 ; 
            end
            else if ((type_reg[11]) == 1'b1)
            begin
               // type 0xcc
               data_field <= #dly {lane_7_code, lane_6_code, lane_5_code, 3'b000, reg_reg_txd[31:0]} ; 
               int_error <= #dly 1'b0 ; 
            end
            else if ((type_reg[12]) == 1'b1)
            begin
               // type 0xd2
               data_field <= #dly {lane_7_code, lane_6_code, 2'b00, reg_reg_txd[39:0]} ; 
               int_error <= #dly 1'b0 ; 
            end
            else if ((type_reg[13]) == 1'b1)
            begin
               // type 0xe1
               data_field <= #dly {lane_7_code, 1'b0, reg_reg_txd[47:0]} ; 
               int_error <= #dly 1'b0 ; 
            end
            else if ((type_reg[14]) == 1'b1)
            begin
               // type 0xff
               data_field <= #dly reg_reg_txd[55:0] ; 
               int_error <= #dly 1'b0 ; 
            end
            else if ((type_reg[15]) == 1'b1)
            begin
               // The data has a control character in it but it 
               // doesn\'t conform to one of the above formats.
               data_field <= #dly {lane_7_code, lane_6_code, lane_5_code, lane_4_code, lane_3_code, lane_2_code, lane_1_code, lane_0_code} ; 
               int_error <= #dly 1'b1 ; 
            end
            else
            begin
               // If the input doesn\'t contain a control character then the data
               // is set to be the rest of the data.
               data_field <= #dly reg_reg_txd[63:8] ; 
               int_error <= #dly 1'b0 ; 
            end 
         end 
      end 
   end 
   assign int_data_out = {data_field, type_field, sync_field} ;

   //-------------------------------------------------------------------------------
   // Register the data before it leaves for the outside world.
   //-------------------------------------------------------------------------------
   always @(posedge init or posedge clk)
   begin // doutgen
      if (init == 1'b1)
      begin
         data_out <= #dly {66{1'b0}} ; 
      end
      else
      begin
         if (enable == 1'b1)
         begin
            data_out <= #dly int_data_out ; 
         end 
      end 
   end 

   //-------------------------------------------------------------------------------
   // Send the transmitter state machine a code indicating if the data is a control 
   // block, a data block, a start block, a terminate block or an error block. These 
   // are generated from the type_reg signal (except for data and error). To maintain 
   // timing we\'ll register this before decoding it.
   //-------------------------------------------------------------------------------
   always @(posedge init or posedge clk)
   begin // regtype
      if (init == 1'b1)
      begin
         type_reg_reg <= #dly {17{1'b0}} ; 
      end
      else
      begin
         if (enable == 1'b1)
         begin
            type_reg_reg <= #dly type_reg ; 
         end 
      end 
   end 

   always @(posedge init or posedge clk)
   begin // ttypegen
      if (init == 1'b1)
      begin
         t_type <= #dly control ; 
      end
      else
      begin
         if (enable == 1'b1)
         begin
            if ((type_reg[0]) == 1'b1 | (type_reg[1]) == 1'b1 | (type_reg[4]) == 1'b1 | (type_reg[6]) == 1'b1)
            begin
               t_type <= #dly control ; 
            end
            else if ((type_reg[2]) == 1'b1 | (type_reg[3]) == 1'b1 | (type_reg[5]) == 1'b1)
            begin
               t_type <= #dly start ; 
            end
            else if ((type_reg[16]) == 1'b1)
            begin
               t_type <= #dly data ; 
            end
            else if ((type_reg[7]) == 1'b1 | (type_reg[8]) == 1'b1 | (type_reg[9]) == 1'b1 | (type_reg[10]) == 1'b1 | (type_reg[11]) == 1'b1 | (type_reg[12]) == 1'b1 | (type_reg[13]) == 1'b1 | (type_reg[14]) == 1'b1)
            begin
               t_type <= #dly terminate ; 
            end
            else
            begin
               t_type <= #dly error ; 
            end 
         end 
      end 
   end 
endmodule
