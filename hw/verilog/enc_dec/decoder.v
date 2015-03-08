//////////////////////////////////////////////////////////////////////////////////////////////
// File : decoder.v
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
// Decodes the 66 bit data given on the DATA_IN port according to the scheme 
// illustrated in section 49.2.4.4 of the IEEE P802.3ae specification. The 
// output data is sent to the XGMII_RXD port and the corresponding control 
// bits are output on XGMII_RXC.
//-----------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module decoder (clk, data_in, xgmii_rxd, xgmii_rxc, r_type, sync_lock, init, idle_bus);

   input clk; 
   input[65:0] data_in; 
   output[63:0] xgmii_rxd; 
   wire[63:0] xgmii_rxd;
   output[7:0] xgmii_rxc; 
   wire[7:0] xgmii_rxc;
   output [2:0] r_type; 
   wire [2:0] r_type;
   input sync_lock; 
   input init; 
   output[7:0] idle_bus; 
   wire[7:0] idle_bus;

   //---------------------------------------------------------------------------------
   // Signals that hold the value of the data and the coresponding control bit 
   // for each byte lane.
   //---------------------------------------------------------------------------------
   reg[7:0] byte0; 
   reg[7:0] byte1; 
   reg[7:0] byte2; 
   reg[7:0] byte3; 
   reg[7:0] byte4; 
   reg[7:0] byte5; 
   reg[7:0] byte6; 
   reg[7:0] byte7; 
   reg c0; 
   reg c1; 
   reg c2; 
   reg c3; 
   reg c4; 
   reg c5; 
   reg c6; 
   reg c7; 
   //---------------------------------------------------------------------------------
   // Signals to hold the value in each component of the input data.
   //---------------------------------------------------------------------------------
   wire[1:0] sync_field; 
   wire[7:0] type_field; 
   wire[65:0] data_field; 
   wire data_word; 
   wire control_word; 
   //---------------------------------------------------------------------------------
   // A signal for each valid type field value.
   //---------------------------------------------------------------------------------
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
   //signal type_reg      : std_logic_vector(14 downto 0);
   reg[14:0] type_reg; 
   //---------------------------------------------------------------------------------
   // Internal data bus signals.
   //---------------------------------------------------------------------------------
   wire[65:0] int_data_in; 
   reg[65:0] data_field_reg; 
   //---------------------------------------------------------------------------------
   // Signals for decoding the control characters.
   //---------------------------------------------------------------------------------
   reg[7:0] control0; 
   reg[7:0] control1; 
   reg[7:0] control2; 
   reg[7:0] control3; 
   reg[7:0] control4; 
   reg[7:0] control5; 
   reg[7:0] control6; 
   reg[7:0] control7; 
   //---------------------------------------------------------------------------------
   // Signals output to the fifo to indicate when ordered sets are being received.
   //---------------------------------------------------------------------------------
   reg lane0_seq_9c; 
   reg lane0_seq_5c; 
   reg lane4_seq_9c; 
   reg lane4_seq_5c; 
   //---------------------------------------------------------------------------------
   // Internal initialisation signal. This should go high on INIT and when the sync 
   // block isn\'t locked yet.
   //---------------------------------------------------------------------------------
   wire int_init; 
   reg [2:0] int_r_type; 
   wire[2:0] int_rt_bv; 
   wire[2:0] int_rt_del; 
   wire gnd; 
   wire r_type_pre_reg; 
   //---------------------------------------------------------------------------------
   //  delay for simulation. The synthesis tool ignores this.
   //---------------------------------------------------------------------------------
   parameter dly = 1; 
   parameter [2:0] control = 3'b000;
   parameter [2:0] start = 3'b001;
   parameter [2:0] data = 3'b010;
   parameter [2:0] terminate = 3'b011;
   parameter [2:0] error = 3'b100;

   assign gnd = 1'b0 ;
   assign int_data_in = data_in ;
   assign int_init = init | ~(sync_lock) ;
   //-------------------------------------------------------------------------------
   // Register the input and split it up into its three components.
   //-------------------------------------------------------------------------------
   assign sync_field = int_data_in[1:0] ;
   assign type_field = int_data_in[9:2] ;
   assign data_field = int_data_in ;

   always @(posedge int_init or posedge clk)
   begin // datafieldgen
      if (int_init == 1'b1)
      begin
         //data_field     <= (others => \'0\') after dly;
         data_field_reg <= #dly {66{1'b0}} ; 
      end
      else
      begin
         //data_field     <= int_data_in after dly;
         data_field_reg <= #dly data_field ; 
      end 
   end 

   //-------------------------------------------------------------------------------
   // Extract the control bytes from the data_field bus. This is only 
   // routed to the output when the sync_field is \"10\", indicating that 
   // a control character has been sent. An idle is 0x00 at the input and this is 
   // converted into a 0v07 for the xgmii. The others will be set to error. This 
   // is because the other valid control characters except error are decoded 
   // by the type field. The positions of each byte are given in figure 49-7 in the spec.
   //-------------------------------------------------------------------------------
   // Control word 0 :
   always @(posedge int_init or posedge clk)
   begin // cw0
      if (int_init == 1'b1)
      begin
         control0 <= #dly {8{1'b0}} ; 
      end
      else
      begin
         if (data_field[16:10] == 7'b0000000)
         begin
            control0 <= #dly 8'b00000111 ; // Idle character.
         end
         else if (data_field[16:10] == 7'b0101101)
         begin
            control0 <= #dly 8'b00011100 ; // Reserved 0 character.
         end
         else if (data_field[16:10] == 7'b0110011)
         begin
            control0 <= #dly 8'b00111100 ; // Reserved 1 character.
         end
         else if (data_field[16:10] == 7'b1001011)
         begin
            control0 <= #dly 8'b01111100 ; // Reserved 2 character.
         end
         else if (data_field[16:10] == 7'b1010101)
         begin
            control0 <= #dly 8'b10111100 ; // Reserved 3 character.
         end
         else if (data_field[16:10] == 7'b1100110)
         begin
            control0 <= #dly 8'b11011100 ; // Reserved 4 character.
         end
         else if (data_field[16:10] == 7'b1111000)
         begin
            control0 <= #dly 8'b11110111 ; // Reserved 5 character.
         end
         else
         begin
            control0 <= #dly 8'b11111110 ; // Error character.
         end 
      end 
   end 

   always @(posedge int_init or posedge clk)
   begin // cw0a
      if (int_init == 1'b1)
      begin
         lane0_seq_9c <= #dly 1'b0 ; 
         lane0_seq_5c <= #dly 1'b0 ; 
      end
      else
      begin
         lane0_seq_9c <= #dly (sync_field[0] & ~(sync_field[1])) & ((type_66 | type_55 | type_4b) & ~(data_field[35]) & ~(data_field[34]) & ~(data_field[33]) & ~(data_field[32])) ; 
         lane0_seq_5c <= #dly (sync_field[0] & ~(sync_field[1])) & ((type_66 | type_55 | type_4b) & data_field[35] & data_field[34] & data_field[33] & data_field[32]) ; 
      end 
   end 

   // Control word 1 :
   always @(posedge int_init or posedge clk)
   begin // cw1
      if (int_init == 1'b1)
      begin
         control1 <= #dly {8{1'b0}} ; 
      end
      else
      begin
         if (data_field[23:17] == 7'b0000000)
         begin
            control1 <= #dly 8'b00000111 ; // Idle character.
         end
         else if (data_field[23:17] == 7'b0101101)
         begin
            control1 <= #dly 8'b00011100 ; // Reserved 0 character.
         end
         else if (data_field[23:17] == 7'b0110011)
         begin
            control1 <= #dly 8'b00111100 ; // Reserved 1 character.
         end
         else if (data_field[23:17] == 7'b1001011)
         begin
            control1 <= #dly 8'b01111100 ; // Reserved 2 character.
         end
         else if (data_field[23:17] == 7'b1010101)
         begin
            control1 <= #dly 8'b10111100 ; // Reserved 3 character.
         end
         else if (data_field[23:17] == 7'b1100110)
         begin
            control1 <= #dly 8'b11011100 ; // Reserved 4 character.
         end
         else if (data_field[23:17] == 7'b1111000)
         begin
            control1 <= #dly 8'b11110111 ; // Reserved 5 character.
         end
         else
         begin
            control1 <= #dly 8'b11111110 ; // Error character.
         end 
      end 
   end 

   // Control word 2 :
   always @(posedge int_init or posedge clk)
   begin // cw2
      if (int_init == 1'b1)
      begin
         control2 <= #dly {8{1'b0}} ; 
      end
      else
      begin
         if (data_field[30:24] == 7'b0000000)
         begin
            control2 <= #dly 8'b00000111 ; // Idle character.
         end
         else if (data_field[30:24] == 7'b0101101)
         begin
            control2 <= #dly 8'b00011100 ; // Reserved 0 character.
         end
         else if (data_field[30:24] == 7'b0110011)
         begin
            control2 <= #dly 8'b00111100 ; // Reserved 1 character.
         end
         else if (data_field[30:24] == 7'b1001011)
         begin
            control2 <= #dly 8'b01111100 ; // Reserved 2 character.
         end
         else if (data_field[30:24] == 7'b1010101)
         begin
            control2 <= #dly 8'b10111100 ; // Reserved 3 character.
         end
         else if (data_field[30:24] == 7'b1100110)
         begin
            control2 <= #dly 8'b11011100 ; // Reserved 4 character.
         end
         else if (data_field[30:24] == 7'b1111000)
         begin
            control2 <= #dly 8'b11110111 ; // Reserved 5 character.
         end
         else
         begin
            control2 <= #dly 8'b11111110 ; // Error character.
         end 
      end 
   end 

   // Control word 3 :
   always @(posedge int_init or posedge clk)
   begin // cw3
      if (int_init == 1'b1)
      begin
         control3 <= #dly {8{1'b0}} ; 
      end
      else
      begin
         if (data_field[37:31] == 7'b0000000)
         begin
            control3 <= #dly 8'b00000111 ; // Idle character.
         end
         else if (data_field[37:31] == 7'b0101101)
         begin
            control3 <= #dly 8'b00011100 ; // Reserved 0 character.
         end
         else if (data_field[37:31] == 7'b0110011)
         begin
            control3 <= #dly 8'b00111100 ; // Reserved 1 character.
         end
         else if (data_field[37:31] == 7'b1001011)
         begin
            control3 <= #dly 8'b01111100 ; // Reserved 2 character.
         end
         else if (data_field[37:31] == 7'b1010101)
         begin
            control3 <= #dly 8'b10111100 ; // Reserved 3 character.
         end
         else if (data_field[37:31] == 7'b1100110)
         begin
            control3 <= #dly 8'b11011100 ; // Reserved 4 character.
         end
         else if (data_field[37:31] == 7'b1111000)
         begin
            control3 <= #dly 8'b11110111 ; // Reserved 5 character.
         end
         else
         begin
            control3 <= #dly 8'b11111110 ; // Error character.
         end 
      end 
   end 

   // Control word 4 :
   always @(posedge int_init or posedge clk)
   begin // cw4
      if (int_init == 1'b1)
      begin
         control4 <= #dly {8{1'b0}} ; 
      end
      else
      begin
         if (data_field[44:38] == 7'b0000000)
         begin
            control4 <= #dly 8'b00000111 ; // Idle character.
         end
         else if (data_field[44:38] == 7'b0101101)
         begin
            control4 <= #dly 8'b00011100 ; // Reserved 0 character.
         end
         else if (data_field[44:38] == 7'b0110011)
         begin
            control4 <= #dly 8'b00111100 ; // Reserved 1 character.
         end
         else if (data_field[44:38] == 7'b1001011)
         begin
            control4 <= #dly 8'b01111100 ; // Reserved 2 character.
         end
         else if (data_field[44:38] == 7'b1010101)
         begin
            control4 <= #dly 8'b10111100 ; // Reserved 3 character.
         end
         else if (data_field[44:38] == 7'b1100110)
         begin
            control4 <= #dly 8'b11011100 ; // Reserved 4 character.
         end
         else if (data_field[44:38] == 7'b1111000)
         begin
            control4 <= #dly 8'b11110111 ; // Reserved 5 character.
         end
         else
         begin
            control4 <= #dly 8'b11111110 ; // Error character.
         end 
      end 
   end 

   always @(posedge int_init or posedge clk)
   begin // cw4a
      if (int_init == 1'b1)
      begin
         lane4_seq_9c <= #dly 1'b0 ; 
         lane4_seq_5c <= #dly 1'b0 ; 
      end
      else
      begin
         lane4_seq_9c <= #dly (sync_field[0] & ~(sync_field[1])) & ((type_2d | type_55) & ~(data_field[39]) & ~(data_field[38]) & ~(data_field[37]) & ~(data_field[36])) ; 
         lane4_seq_5c <= #dly (sync_field[0] & ~(sync_field[1])) & ((type_2d | type_55) & data_field[39] & data_field[38] & data_field[37] & data_field[36]) ; 
      end 
   end 

   // Control word 5 :
   always @(posedge int_init or posedge clk)
   begin // cw5
      if (int_init == 1'b1)
      begin
         control5 <= #dly {8{1'b0}} ; 
      end
      else
      begin
         if (data_field[51:45] == 7'b0000000)
         begin
            control5 <= #dly 8'b00000111 ; // Idle character.
         end
         else if (data_field[51:45] == 7'b0101101)
         begin
            control5 <= #dly 8'b00011100 ; // Reserved 0 character.
         end
         else if (data_field[51:45] == 7'b0110011)
         begin
            control5 <= #dly 8'b00111100 ; // Reserved 1 character.
         end
         else if (data_field[51:45] == 7'b1001011)
         begin
            control5 <= #dly 8'b01111100 ; // Reserved 2 character.
         end
         else if (data_field[51:45] == 7'b1010101)
         begin
            control5 <= #dly 8'b10111100 ; // Reserved 3 character.
         end
         else if (data_field[51:45] == 7'b1100110)
         begin
            control5 <= #dly 8'b11011100 ; // Reserved 4 character.
         end
         else if (data_field[51:45] == 7'b1111000)
         begin
            control5 <= #dly 8'b11110111 ; // Reserved 5 character.
         end
         else
         begin
            control5 <= #dly 8'b11111110 ; // Error character.
         end 
      end 
   end 

   // Control word 6 :
   always @(posedge int_init or posedge clk)
   begin // cw6
      if (int_init == 1'b1)
      begin
         control6 <= #dly {8{1'b0}} ; 
      end
      else
      begin
         if (data_field[58:52] == 7'b0000000)
         begin
            control6 <= #dly 8'b00000111 ; // Idle character.
         end
         else if (data_field[58:52] == 7'b0101101)
         begin
            control6 <= #dly 8'b00011100 ; // Reserved 0 character.
         end
         else if (data_field[58:52] == 7'b0110011)
         begin
            control6 <= #dly 8'b00111100 ; // Reserved 1 character.
         end
         else if (data_field[58:52] == 7'b1001011)
         begin
            control6 <= #dly 8'b01111100 ; // Reserved 2 character.
         end
         else if (data_field[58:52] == 7'b1010101)
         begin
            control6 <= #dly 8'b10111100 ; // Reserved 3 character.
         end
         else if (data_field[58:52] == 7'b1100110)
         begin
            control6 <= #dly 8'b11011100 ; // Reserved 4 character.
         end
         else if (data_field[58:52] == 7'b1111000)
         begin
            control6 <= #dly 8'b11110111 ; // Reserved 5 character.
         end
         else
         begin
            control6 <= #dly 8'b11111110 ; // Error character.
         end 
      end 
   end 

   // Control word 7 :
   always @(posedge int_init or posedge clk)
   begin // cw7
      if (int_init == 1'b1)
      begin
         control7 <= #dly {8{1'b0}} ; 
      end
      else
      begin
         if (data_field[65:59] == 7'b0000000)
         begin
            control7 <= #dly 8'b00000111 ; // Idle character.
         end
         else if (data_field[65:59] == 7'b0101101)
         begin
            control7 <= #dly 8'b00011100 ; // Reserved 0 character.
         end
         else if (data_field[65:59] == 7'b0110011)
         begin
            control7 <= #dly 8'b00111100 ; // Reserved 1 character.
         end
         else if (data_field[65:59] == 7'b1001011)
         begin
            control7 <= #dly 8'b01111100 ; // Reserved 2 character.
         end
         else if (data_field[65:59] == 7'b1010101)
         begin
            control7 <= #dly 8'b10111100 ; // Reserved 3 character.
         end
         else if (data_field[65:59] == 7'b1100110)
         begin
            control7 <= #dly 8'b11011100 ; // Reserved 4 character.
         end
         else if (data_field[65:59] == 7'b1111000)
         begin
            control7 <= #dly 8'b11110111 ; // Reserved 5 character.
         end
         else
         begin
            control7 <= #dly 8'b11111110 ; // Error character.
         end 
      end 
   end 
   //-------------------------------------------------------------------------------
   // Decode the sync field and the type field to determine what sort of data
   // word was transmitted. The different types are given in figure 49-7 in the spec.
   //-------------------------------------------------------------------------------
   assign data_word = ~(sync_field[0]) & sync_field[1] ;
   assign control_word = sync_field[0] & ~(sync_field[1]) ;
   assign type_1e = ~(type_field[7]) & ~(type_field[6]) & ~(type_field[5]) & type_field[4] & type_field[3] & type_field[2] & type_field[1] & ~(type_field[0]) ;
   assign type_2d = ~(type_field[7]) & ~(type_field[6]) & type_field[5] & ~(type_field[4]) & type_field[3] & type_field[2] & ~(type_field[1]) & type_field[0] ;
   assign type_33 = ~(type_field[7]) & ~(type_field[6]) & type_field[5] & type_field[4] & ~(type_field[3]) & ~(type_field[2]) & type_field[1] & type_field[0] ;
   assign type_66 = ~(type_field[7]) & type_field[6] & type_field[5] & ~(type_field[4]) & ~(type_field[3]) & type_field[2] & type_field[1] & ~(type_field[0]) ;
   assign type_55 = ~(type_field[7]) & type_field[6] & ~(type_field[5]) & type_field[4] & ~(type_field[3]) & type_field[2] & ~(type_field[1]) & type_field[0] ;
   assign type_78 = ~(type_field[7]) & type_field[6] & type_field[5] & type_field[4] & type_field[3] & ~(type_field[2]) & ~(type_field[1]) & ~(type_field[0]) ;
   assign type_4b = ~(type_field[7]) & type_field[6] & ~(type_field[5]) & ~(type_field[4]) & type_field[3] & ~(type_field[2]) & type_field[1] & type_field[0] ;
   assign type_87 = type_field[7] & ~(type_field[6]) & ~(type_field[5]) & ~(type_field[4]) & ~(type_field[3]) & type_field[2] & type_field[1] & type_field[0] ;
   assign type_99 = type_field[7] & ~(type_field[6]) & ~(type_field[5]) & type_field[4] & type_field[3] & ~(type_field[2]) & ~(type_field[1]) & type_field[0] ;
   assign type_aa = type_field[7] & ~(type_field[6]) & type_field[5] & ~(type_field[4]) & type_field[3] & ~(type_field[2]) & type_field[1] & ~(type_field[0]) ;
   assign type_b4 = type_field[7] & ~(type_field[6]) & type_field[5] & type_field[4] & ~(type_field[3]) & type_field[2] & ~(type_field[1]) & ~(type_field[0]) ;
   assign type_cc = type_field[7] & type_field[6] & ~(type_field[5]) & ~(type_field[4]) & type_field[3] & type_field[2] & ~(type_field[1]) & ~(type_field[0]) ;
   assign type_d2 = type_field[7] & type_field[6] & ~(type_field[5]) & type_field[4] & ~(type_field[3]) & ~(type_field[2]) & type_field[1] & ~(type_field[0]) ;
   assign type_e1 = type_field[7] & type_field[6] & type_field[5] & ~(type_field[4]) & ~(type_field[3]) & ~(type_field[2]) & ~(type_field[1]) & type_field[0] ;
   assign type_ff = type_field[7] & type_field[6] & type_field[5] & type_field[4] & type_field[3] & type_field[2] & type_field[1] & type_field[0] ;

   //-------------------------------------------------------------------------------
   // Translate these signals to give the type of data in each byte.
   // Prior to this the type signals above are registered as the delay through the 
   // above equations could be considerable.
   //-------------------------------------------------------------------------------
   always @(posedge int_init or posedge clk)
   begin // reg_type
      if (int_init == 1'b1)
      begin
         type_reg <= #dly {15{1'b0}} ; 
      end
      else
      begin
         type_reg <= #dly ({(control_word & type_ff), (control_word & type_e1), (control_word & type_d2), (control_word & type_cc), (control_word & type_b4), (control_word & type_aa), (control_word & type_99), (control_word & type_87), (control_word & type_4b), (control_word & type_78), (control_word & type_55), (control_word & type_66), (control_word & type_33), (control_word & type_2d), (control_word & type_1e)}) ; 
      end 
   end 

   //------------------------------------------------------------------------------
   // Generate the R_TYPE signal to help the receiver state machine.
   //------------------------------------------------------------------------------
   always @(posedge init or posedge clk)
   begin // rtypegen
      if (init == 1'b1)
      begin
         int_r_type <= #dly control ; 
      end
      //INT_RT_BV  <= \"000\" after DLY;
      else
      begin
         if (control_word == 1'b1 & (type_ff == 1'b1 | type_e1 == 1'b1 | type_d2 == 1'b1 | type_cc == 1'b1 | type_b4 == 1'b1 | type_aa == 1'b1 | type_99 == 1'b1 | type_87 == 1'b1))
         begin
            int_r_type <= #dly terminate ; 
         end
         //INT_RT_BV  <= \"001\" after DLY;
         else if (control_word == 1'b1 & (type_1e == 1'b1 | type_2d == 1'b1 | type_55 == 1'b1 | type_4b == 1'b1))
         begin
            int_r_type <= #dly control ; 
         end
         //INT_RT_BV  <= \"000\" after DLY;
         else if (control_word == 1'b1 & (type_33 == 1'b1 | type_66 == 1'b1 | type_78 == 1'b1))
         begin
            int_r_type <= #dly start ; 
         end
         //INT_RT_BV  <= \"010\" after DLY;
         else if (control_word == 1'b0)
         begin
            int_r_type <= #dly data ; 
         end
         //INT_RT_BV  <= \"011\" after DLY;
         else
         begin
            int_r_type <= #dly error ; 
         end
         //INT_RT_BV  <= \"100\" after DLY; 
      end 
   end 
   assign r_type = int_r_type ;

   //-------------------------------------------------------------------------------
   // Put the input data into the correct byte lane at the output.
   //-------------------------------------------------------------------------------
   // Lane 0 :
   always @(posedge int_init or posedge clk)
   begin // byte_type_0_gen
      if (int_init == 1'b1)
      begin
         byte0 <= #dly {8{1'b0}} ; 
         c0 <= #dly 1'b0 ; 
      end
      else
      begin
         if (type_reg[2:0] != 3'b000)
         begin
            byte0 <= #dly control0 ; // Control character.
            c0 <= #dly 1'b1 ; 
         end
         else if ((type_reg[3]) == 1'b1 & lane0_seq_9c == 1'b1)
         begin
            byte0 <= #dly 8'b10011100 ; // Sequence field (9C).
            c0 <= #dly 1'b1 ; 
         end
         else if ((type_reg[3]) == 1'b1 & lane0_seq_5c == 1'b1)
         begin
            byte0 <= #dly 8'b01011100 ; // Sequence field (5C).
            c0 <= #dly 1'b1 ; 
         end
         else if ((type_reg[4]) == 1'b1 & lane0_seq_9c == 1'b1)
         begin
            byte0 <= #dly 8'b10011100 ; // Sequence field (9C).
            c0 <= #dly 1'b1 ; 
         end
         else if ((type_reg[4]) == 1'b1 & lane0_seq_5c == 1'b1)
         begin
            byte0 <= #dly 8'b01011100 ; // Sequence field (5C).
            c0 <= #dly 1'b1 ; 
         end
         else if ((type_reg[5]) == 1'b1)
         begin
            byte0 <= #dly 8'b11111011 ; // Start field.
            c0 <= #dly 1'b1 ; 
         end
         else if ((type_reg[6]) == 1'b1 & lane0_seq_9c == 1'b1)
         begin
            byte0 <= #dly 8'b10011100 ; // Sequence field (9C).
            c0 <= #dly 1'b1 ; 
         end
         else if ((type_reg[6]) == 1'b1 & lane0_seq_5c == 1'b1)
         begin
            byte0 <= #dly 8'b01011100 ; // Sequence field (5C).
            c0 <= #dly 1'b1 ; 
         end
         else if ((type_reg[7]) == 1'b1)
         begin
            byte0 <= #dly 8'b11111101 ; // Termimation.
            c0 <= #dly 1'b1 ; 
         end
         else if (type_reg[14:8] != 7'b0000000)
         begin
            byte0 <= #dly data_field_reg[17:10] ; // Data byte 0.
            c0 <= #dly 1'b0 ; 
         end
         else
         begin
            // If the input doesn\'t contain a control character then the type field
            // is set to be the first data byte.
            byte0 <= #dly data_field_reg[9:2] ; 
            c0 <= #dly 1'b0 ; 
         end 
      end 
   end 

   // Lane 1 :
   always @(posedge int_init or posedge clk)
   begin // byte_type_1_gen
      if (int_init == 1'b1)
      begin
         byte1 <= #dly {8{1'b0}} ; 
         c1 <= #dly 1'b0 ; 
      end
      else
      begin
         if (type_reg[2:0] != 3'b000)
         begin
            byte1 <= #dly control1 ; // Control character.
            c1 <= #dly 1'b1 ; 
         end
         else if (type_reg[6:3] != 3'b000)
         begin
            byte1 <= #dly data_field_reg[17:10] ; // Data byte 1
            c1 <= #dly 1'b0 ; 
         end
         else if ((type_reg[7]) == 1'b1)
         begin
            byte1 <= #dly control1 ; // Control character.
            c1 <= #dly 1'b1 ; 
         end
         else if ((type_reg[8]) == 1'b1)
         begin
            byte1 <= #dly 8'b11111101 ; // Termination.
            c1 <= #dly 1'b1 ; 
         end
         else if (type_reg[14:9] != 6'b000000)
         begin
            byte1 <= #dly data_field_reg[25:18] ; // Data byte 1
            c1 <= #dly 1'b0 ; 
         end
         else
         begin
            // If the input doesn\'t contain a control character then the type field
            // is set to be the second data byte.
            byte1 <= #dly data_field_reg[17:10] ; 
            c1 <= #dly 1'b0 ; 
         end 
      end 
   end 

   // Lane 2 :
   always @(posedge int_init or posedge clk)
   begin // byte_type_2_gen
      if (int_init == 1'b1)
      begin
         byte2 <= #dly {8{1'b0}} ; 
         c2 <= #dly 1'b0 ; 
      end
      else
      begin
         if (type_reg[2:0] != 3'b000 | type_reg[8:7] != 2'b00)
         begin
            byte2 <= #dly control2 ; // Control character.
            c2 <= #dly 1'b1 ; 
         end
         else if (type_reg[6:3] != 3'b000)
         begin
            byte2 <= #dly data_field_reg[25:18] ; // Data byte 2
            c2 <= #dly 1'b0 ; 
         end
         else if ((type_reg[9]) == 1'b1)
         begin
            byte2 <= #dly 8'b11111101 ; // Termination.
            c2 <= #dly 1'b1 ; 
         end
         else if (type_reg[14:10] != 5'b00000)
         begin
            byte2 <= #dly data_field_reg[33:26] ; // Data byte 2
            c2 <= #dly 1'b0 ; 
         end
         else
         begin
            // If the input doesn\'t contain a control character then the type field
            // is set to be the third data byte.
            byte2 <= #dly data_field_reg[25:18] ; 
            c2 <= #dly 1'b0 ; 
         end 
      end 
   end 

   // Lane 3 :
   always @(posedge int_init or posedge clk)
   begin // byte_type_3_gen
      if (int_init == 1'b1)
      begin
         byte3 <= #dly {8{1'b0}} ; 
         c3 <= #dly 1'b0 ; 
      end
      else
      begin
         if (type_reg[2:0] != 3'b000 | type_reg[9:7] != 3'b000)
         begin
            byte3 <= #dly control3 ; // Control character.
            c3 <= #dly 1'b1 ; 
         end
         else if (type_reg[6:3] != 3'b000)
         begin
            byte3 <= #dly data_field_reg[33:26] ; // Data byte 3
            c3 <= #dly 1'b0 ; 
         end
         else if ((type_reg[10]) == 1'b1)
         begin
            byte3 <= #dly 8'b11111101 ; // Termination.
            c3 <= #dly 1'b1 ; 
         end
         else if (type_reg[14:11] != 4'b0000)
         begin
            byte3 <= #dly data_field_reg[41:34] ; // Data byte 3
            c3 <= #dly 1'b0 ; 
         end
         else
         begin
            // If the input doesn\'t contain a control character then the type field
            // is set to be the fourth data byte.
            byte3 <= #dly data_field_reg[33:26] ; 
            c3 <= #dly 1'b0 ; 
         end 
      end 
   end 

   // Lane 4 :
   always @(posedge int_init or posedge clk)
   begin // byte_type_4_gen
      if (int_init == 1'b1)
      begin
         byte4 <= #dly {8{1'b0}} ; 
         c4 <= #dly 1'b0 ; 
      end
      else
      begin
         if ((type_reg[0]) == 1'b1 | type_reg[10:6] != 5'b00000)
         begin
            byte4 <= #dly control4 ; // Control character.
            c4 <= #dly 1'b1 ; 
         end
         else if ((type_reg[1]) == 1'b1 & lane4_seq_9c == 1'b1)
         begin
            byte4 <= #dly 8'b10011100 ; // Sequence field.
            c4 <= #dly 1'b1 ; 
         end
         else if ((type_reg[1]) == 1'b1 & lane4_seq_5c == 1'b1)
         begin
            byte4 <= #dly 8'b01011100 ; // Sequence field.
            c4 <= #dly 1'b1 ; 
         end
         else if ((type_reg[2]) == 1'b1)
         begin
            byte4 <= #dly 8'b11111011 ; // Start field.
            c4 <= #dly 1'b1 ; 
         end
         else if ((type_reg[3]) == 1'b1)
         begin
            byte4 <= #dly 8'b11111011 ; // Start field.
            c4 <= #dly 1'b1 ; 
         end
         else if ((type_reg[4]) == 1'b1 & lane4_seq_9c == 1'b1)
         begin
            byte4 <= #dly 8'b10011100 ; // Sequence field.
            c4 <= #dly 1'b1 ; 
         end
         else if ((type_reg[4]) == 1'b1 & lane4_seq_5c == 1'b1)
         begin
            byte4 <= #dly 8'b01011100 ; // Sequence field.
            c4 <= #dly 1'b1 ; 
         end
         else if ((type_reg[5]) == 1'b1)
         begin
            byte4 <= #dly data_field_reg[41:34] ; // Termimation.
            c4 <= #dly 1'b0 ; 
         end
         else if ((type_reg[11]) == 1'b1)
         begin
            byte4 <= #dly 8'b11111101 ; // Termination.
            c4 <= #dly 1'b1 ; 
         end
         else if (type_reg[14:12] != 3'b000)
         begin
            byte4 <= #dly data_field_reg[49:42] ; // Data byte 4.
            c4 <= #dly 1'b0 ; 
         end
         else
         begin
            // If the input doesn\'t contain a control character then the type field
            // is set to be the fifth data byte.
            byte4 <= #dly data_field_reg[41:34] ; 
            c4 <= #dly 1'b0 ; 
         end 
      end 
   end 

   // Lane 5 :
   always @(posedge int_init or posedge clk)
   begin // byte_type_5_gen
      if (int_init == 1'b1)
      begin
         byte5 <= #dly {8{1'b0}} ; 
         c5 <= #dly 1'b0 ; 
      end
      else
      begin
         if ((type_reg[0]) == 1'b1 | type_reg[11:6] != 6'b000000)
         begin
            byte5 <= #dly control5 ; // Control character.
            c5 <= #dly 1'b1 ; 
         end
         else if (type_reg[5:1] != 5'b00000)
         begin
            byte5 <= #dly data_field_reg[49:42] ; // Data byte 5
            c5 <= #dly 1'b0 ; 
         end
         else if ((type_reg[12]) == 1'b1)
         begin
            byte5 <= #dly 8'b11111101 ; // Termination.
            c5 <= #dly 1'b1 ; 
         end
         else if (type_reg[14:13] != 2'b00)
         begin
            byte5 <= #dly data_field_reg[57:50] ; // Data byte 5
            c5 <= #dly 1'b0 ; 
         end
         else
         begin
            // If the input doesn\'t contain a control character then the type field
            // is set to be the sixth data byte.
            byte5 <= #dly data_field_reg[49:42] ; 
            c5 <= #dly 1'b0 ; 
         end 
      end 
   end 

   // Lane 6 :
   always @(posedge int_init or posedge clk)
   begin // byte_type_6_gen
      if (int_init == 1'b1)
      begin
         byte6 <= #dly {8{1'b0}} ; 
         c6 <= #dly 1'b0 ; 
      end
      else
      begin
         if ((type_reg[0]) == 1'b1 | type_reg[12:6] != 7'b0000000)
         begin
            byte6 <= #dly control6 ; // Control character.
            c6 <= #dly 1'b1 ; 
         end
         else if (type_reg[5:1] != 5'b00000)
         begin
            byte6 <= #dly data_field_reg[57:50] ; // Data byte 6
            c6 <= #dly 1'b0 ; 
         end
         else if ((type_reg[13]) == 1'b1)
         begin
            byte6 <= #dly 8'b11111101 ; // Termination.
            c6 <= #dly 1'b1 ; 
         end
         else if ((type_reg[14]) == 1'b1)
         begin
            byte6 <= #dly data_field_reg[65:58] ; // Data byte 6
            c6 <= #dly 1'b0 ; 
         end
         else
         begin
            // If the input doesn\'t contain a control character then the type field
            // is set to be the seventh data byte.
            byte6 <= #dly data_field_reg[57:50] ; 
            c6 <= #dly 1'b0 ; 
         end 
      end 
   end 

   // Lane 7 :
   always @(posedge int_init or posedge clk)
   begin // byte_type_7_gen
      if (int_init == 1'b1)
      begin
         byte7 <= #dly {8{1'b0}} ; 
         c7 <= #dly 1'b0 ; 
      end
      else
      begin
         if ((type_reg[0]) == 1'b1 | type_reg[13:6] != 8'b00000000)
         begin
            byte7 <= #dly control7 ; // Control character.
            c7 <= #dly 1'b1 ; 
         end
         else if (type_reg[5:1] != 5'b00000)
         begin
            byte7 <= #dly data_field_reg[65:58] ; // Data byte 7
            c7 <= #dly 1'b0 ; 
         end
         else if ((type_reg[14]) == 1'b1)
         begin
            byte7 <= #dly 8'b11111101 ; // Termination.
            c7 <= #dly 1'b1 ; 
         end
         else
         begin
            // If the input doesn\'t contain a control character then the type field
            // is set to be the last data byte.
            byte7 <= #dly data_field_reg[65:58] ; 
            c7 <= #dly 1'b0 ; 
         end 
      end 
   end 
   assign xgmii_rxd = {byte7, byte6, byte5, byte4, byte3, byte2, byte1, byte0} ;
   assign xgmii_rxc = {c7, c6, c5, c4, c3, c2, c1, c0} ;
  
endmodule
