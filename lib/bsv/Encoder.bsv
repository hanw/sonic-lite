
// Copyright (c) 2014 Cornell University.

// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

package Encoder;

import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;

import Pipe::*;
import MemTypes::*;

import Ethernet::*;

interface Encoder;
   interface PipeOut#(Bit#(66)) encoderOut;
endinterface

typedef enum {CONTROL, START, DATA, TERMINATE, ERROR} State
deriving (Bits, Eq);

module mkEncoder#(PipeOut#(Bit#(72)) encoderIn)(Encoder);

   let verbose = True;

   Reg#(Bit#(32)) cycle         <- mkReg(0);
   FIFOF#(Vector#(8, XGMII_LANES))  fifo_in <- mkBypassFIFOF;
   FIFOF#(Bit#(66))  fifo_out   <- mkBypassFIFOF;

   Vector#(64, Wire#(Bit#(1))) xgmii_txd <- replicateM(mkDWire(0));
   Vector#(8, Wire#(Bit#(1)))  xgmii_txc <- replicateM(mkDWire(0));

   Vector#(66, Reg#(Bit#(1))) data_out <- replicateM(mkReg(0));
   Vector#(3, Reg#(Bit#(1)))  t_type   <- replicateM(mkReg(0));

   //---------------------------------------------------------------------------------
   // Signals used to indicate what type of data is in each of the pre-xgmii data lanes.
   //---------------------------------------------------------------------------------
   Vector#(8, Reg#(Bit#(1))) lane_data    <- replicateM(mkReg(0));
   Vector#(8, Reg#(Bit#(1))) lane_control <- replicateM(mkReg(0));
   Vector#(8, Reg#(Bit#(1))) lane_idle    <- replicateM(mkReg(0));
   Vector#(8, Reg#(Bit#(1))) lane_terminate <- replicateM(mkReg(0));
   Vector#(8, Reg#(Bit#(1))) lane_res0    <- replicateM(mkReg(0));
   Vector#(8, Reg#(Bit#(1))) lane_res1    <- replicateM(mkReg(0));
   Vector#(8, Reg#(Bit#(1))) lane_res2    <- replicateM(mkReg(0));
   Vector#(8, Reg#(Bit#(1))) lane_res3    <- replicateM(mkReg(0));
   Vector#(8, Reg#(Bit#(1))) lane_res4    <- replicateM(mkReg(0));
   Vector#(8, Reg#(Bit#(1))) lane_res5    <- replicateM(mkReg(0));

   // although only lane0 and lane4 are used.
   Vector#(8, Reg#(Bit#(1))) lane_start   <- replicateM(mkReg(0));
   Vector#(8, Reg#(Bit#(1))) lane_error   <- replicateM(mkReg(0));
   Vector#(8, Reg#(Bit#(1))) lane_seq     <- replicateM(mkReg(0));
   Vector#(8, Reg#(Bit#(1))) lane_seqr    <- replicateM(mkReg(0));

   //---------------------------------------------------------------------------------
   // Internal data and control bus signals.
   //---------------------------------------------------------------------------------
   Vector#(64, Wire#(Bit#(1))) int_txd    <- replicateM(mkDWire(0));
   Vector#(8,  Wire#(Bit#(1))) int_txc    <- replicateM(mkDWire(0));
   Vector#(64, Reg#(Bit#(1)))  reg_txd    <- replicateM(mkReg(0));
   Vector#(8,  Reg#(Bit#(1)))  reg_txc    <- replicateM(mkReg(0));
   Vector#(64, Reg#(Bit#(1)))  reg_reg_txd    <- replicateM(mkReg(0));
   Vector#(8,  Reg#(Bit#(1)))   reg_reg_txc   <- replicateM(mkReg(0));
   //xxxx
   Vector#(8,  Wire#(Bit#(8))) int_txd_lane <- replicateM(mkDWire(0));
   Vector#(66, Wire#(Bit#(1))) int_data_out <- replicateM(mkDWire(0));

   //---------------------------------------------------------------------------------
   // Signals for the type field generation.
   //---------------------------------------------------------------------------------
   Reg#(Bit#(8)) type_field <- mkReg(0);
   Wire#(Bit#(1)) type_1e <- mkDWire(0);
   Wire#(Bit#(1)) type_2d <- mkDWire(0);
   Wire#(Bit#(1)) type_33 <- mkDWire(0);
   Wire#(Bit#(1)) type_66 <- mkDWire(0);
   Wire#(Bit#(1)) type_55 <- mkDWire(0);
   Wire#(Bit#(1)) type_78 <- mkDWire(0);
   Wire#(Bit#(1)) type_4b <- mkDWire(0);
   Wire#(Bit#(1)) type_87 <- mkDWire(0);
   Wire#(Bit#(1)) type_99 <- mkDWire(0);
   Wire#(Bit#(1)) type_aa <- mkDWire(0);
   Wire#(Bit#(1)) type_b4 <- mkDWire(0);
   Wire#(Bit#(1)) type_cc <- mkDWire(0);
   Wire#(Bit#(1)) type_d2 <- mkDWire(0);
   Wire#(Bit#(1)) type_e1 <- mkDWire(0);
   Wire#(Bit#(1)) type_ff <- mkDWire(0);
   Wire#(Bit#(1)) type_illegal <- mkDWire(0);
   Wire#(Bit#(1)) type_data    <- mkDWire(0);
   Reg#(Bit#(1))  int_error    <- mkReg(0);
   Reg#(Bit#(17)) type_reg     <- mkReg(0);
   Reg#(Bit#(17)) type_reg_reg <- mkReg(0);

   //---------------------------------------------------------------------------------
   // Signals for the other output data fields.
   //---------------------------------------------------------------------------------
   Reg#(Bit#(2))  sync_field   <- mkReg(0);
   Reg#(Bit#(56)) data_field   <- mkReg(0);
   Vector#(8, Reg#(Bit#(7)))   lane_code    <- replicateM(mkReg(0));
   Reg#(Bit#(4))  o_code0      <- mkReg(0);
   Reg#(Bit#(4))  o_code4      <- mkReg(0);

   rule cyc;
      cycle <= cycle + 1;
   endrule

   rule incoming;
      Vector#(8, XGMII_LANES) xgmii;
      let v <- toGet(encoderIn).get;
      for (Integer i=0; i<8; i=i+1) begin
         xgmii[i].data = v[9*i+7 : 9*i];
         xgmii[i].control = v[8*i];
      end
      fifo_in.enq(xgmii);
   endrule

   //-------------------------------------------------------------------------------
   // Register the txd and txc signals. This is to maintain the timing
   // relationship between the data and the control signals that are generated
   // in this design.
   //-------------------------------------------------------------------------------
   rule for_txd_txc;
      writeVReg(take(reg_txd), readVReg(int_txd));
      writeVReg(take(reg_txc), readVReg(int_txc));
      writeVReg(take(reg_reg_txd), readVReg(reg_txd));
      writeVReg(take(reg_reg_txc), readVReg(reg_txc));
   endrule

   //-------------------------------------------------------------------------------
   // Generate the lane 0 data and control signals. These are dependent on just the
   // TXC(0) input from the MAC. 0 indicates data, 1 indicates control.
   //-------------------------------------------------------------------------------
   rule for_lane_control_signals;
      Vector#(8, Bit#(8)) txd;
      Vector#(8, Bit#(1)) txc;

      let v<- toGet(fifo_in).get();

      for (Integer i=0; i<8; i=i+1) begin
         txd[i] = v[i].data;
         txc[i] = v[i].control;
      end

      for(Integer i=0; i<8; i=i+1) begin

      end

      for (Integer i=0; i<8; i=i+1) begin
         lane_data[i] <= ~txc[i];
         lane_control[i] <= txc[i];
         lane_idle[i] <= ~(txd[i][7]) & ~(txd[i][6]) & ~(txd[i][5]) & ~(txd[i][4]) &
                         ~(txd[i][3]) & txd[i][2] & txd[i][1] & txd[i][0] & txc[i][0];
         lane_start[i] <= txd[i][7] & txd[i][6] & txd[i][5] & txd[i][4] &
                          txd[i][3] & ~(txd[i][2]) & txd[i][1] & txd[i][0] & txc[i][0];
         // Terminate = 0xFD
         lane_terminate[i] <= txd[i][7] & txd[i][6] & txd[i][5] & txd[i][4] &
                              txd[i][3] & txd[i][2] & ~(txd[i][1]) & txd[i][0] & txc[i][0];
         // Error = 0xFE
         lane_error[i] <= txd[i][7] & txd[i][6] & txd[i][5] & txd[i][4] &
                          txd[i][3] & txd[i][2] & txd[i][1] & ~(txd[i][0]) & txc[i][0];
         // Sequence = 0x9C
         lane_seq[i] <= txd[i][7] & ~(txd[i][6]) & ~(txd[i][5]) & txd[i][4] &
                        txd[i][3] & txd[i][2] & ~(txd[i][1]) & ~(txd[i][0]) & txc[i][0];
         // Reserved 0
         lane_res0[i] <= ~(txd[i][7]) & ~(txd[i][6]) & ~(txd[i][5]) & txd[i][4] &
                           txd[i][3] & txd[i][2] & ~(txd[i][1]) & ~(txd[i][0]) & txc[i][0];
         // Reserved 1
         lane_res1[i] <= ~(txd[i][7]) & ~(txd[i][6]) & txd[i][5] & txd[i][4] &
                           txd[i][3] & txd[i][2] & ~(txd[i][1]) & ~(txd[i][0]) & txc[i][0];
         // Reserved 2
         lane_res2[i] <= ~(txd[i][7]) & txd[i][6] & txd[i][5] & txd[i][4] &
                           txd[i][3] & txd[i][2] & ~(txd[i][1]) & ~(txd[i][0]) & txc[i][0];
         // Reserved 3
         lane_res3[i] <= txd[i][7] & ~(txd[i][6]) & txd[i][5] & txd[i][4] &
                         txd[i][3] & txd[i][2] & ~(txd[i][1]) & ~(txd[i][0]) & txc[i][0];
         // Reserved 4
         lane_res4[i] <= txd[i][7] & txd[i][6] & ~(txd[i][5]) & txd[i][4] &
                         txd[i][3] & txd[i][2] & ~(txd[i][1]) & ~(txd[i][0]) & txc[i][0];
         // Reserved 5
         lane_res5[i] <= txd[i][7] & txd[i][6] & txd[i][5] & txd[i][4] &
                       ~(txd[i][3]) & txd[i][2] & txd[i][1] & txd[i][0] & txc[i][0];
         // Reserved Ordered Set
         lane_seqr[i] <= ~(txd[i][7]) & txd[i][6] & ~(txd[i][5]) & ~(txd[i][4]) &
                           txd[i][3] & txd[i][2] & ~(txd[i][1]) & ~(txd[i][0]) & txc[i][0];
      end

      if(verbose) $display("%d: lane_data=%h, lane_control=%h", cycle, pack(readVReg(lane_data)), pack(readVReg(lane_control)));
   endrule

   //-------------------------------------------------------------------------------
   // Decode the TXC input to decide on the value of the type field that is appended
   // to the data stream. This is only present for double words that contain
   // one or more control characters.
   //-------------------------------------------------------------------------------
   rule for_type_field;
      // All the data is control characters (usually idles) :-
      type_1e <= lane_control[0] & ~(lane_terminate[0]) & ~(lane_error[0]) & lane_control[1] & lane_control[2] & lane_control[3] & lane_control[4] & lane_control[5] & lane_control[6] & lane_control[7] ;
      // The input contains control codes upto lane 3 but an ordered set from lane 4 onwards :-
      type_2d <= lane_control[0] & lane_control[1] & lane_control[2] & lane_control[3] & lane_seq[4] & lane_data[5] & lane_data[6] & lane_data[7] ;
      // The input contains a start of packet in lane 4 :-
      type_33 <= lane_control[0] & lane_control[1] & lane_control[2] & lane_control[3] & lane_start[4] & lane_data[5] & lane_data[6] & lane_data[7] ;
      // The input contains an ordered set in lanes 0 to 3 and the start of a packet
      // in lanes 4 to 7 :-
      type_66 <= lane_seq[0] & lane_data[1] & lane_data[2] & lane_data[3] & lane_start[4] & lane_data[5] & lane_data[6] & lane_data[7] ;
      // The input contains two ordered sets, one starting in lane 0 and the other in lane 4 :-
      type_55 <= lane_seq[0] & lane_data[1] & lane_data[2] & lane_data[3] & lane_seq[4] & lane_data[5] & lane_data[6] & lane_data[7] ;
      // The input contains a start of packet in lane 0 :-
      type_78 <= lane_start[0] & lane_data[1] & lane_data[2] & lane_data[3] & lane_data[4] & lane_data[5] & lane_data[6] & lane_data[7] ;
      // The input contains an ordered set starting in lane 0 and control characters
      // in lanes 4 to 7 :-
      type_4b <= lane_seq[0] & lane_data[1] & lane_data[2] & lane_data[3] & lane_control[4] & lane_control[5] & lane_control[6] & lane_control[7] ;
      // The following types are used to code inputs that contain the end of the packet.
      // The end of packet delimiter (terminate) can occur in any lane. There is a
      // type field associated with each position.
      //
      // Terminate in lane 0 :-
      type_87 <= lane_terminate[0] & lane_control[1] & lane_control[2] & lane_control[3] & lane_control[4] & lane_control[5] & lane_control[6] & lane_control[7] ;
      // Terminate in lane 1 :-
      type_99 <= lane_data[0] & lane_terminate[1] & lane_control[2] & lane_control[3] & lane_control[4] & lane_control[5] & lane_control[6] & lane_control[7] ;
      // Terminate in lane 2 :-
      type_aa <= lane_data[0] & lane_data[1] & lane_terminate[2] & lane_control[3] & lane_control[4] & lane_control[5] & lane_control[6] & lane_control[7] ;
      // Terminate in lane 3 :-
      type_b4 <= lane_data[0] & lane_data[1] & lane_data[2] & lane_terminate[3] & lane_control[4] & lane_control[5] & lane_control[6] & lane_control[7] ;
      // Terminate in lane 4 :-
      type_cc <= lane_data[0] & lane_data[1] & lane_data[2] & lane_data[3] & lane_terminate[4] & lane_control[5] & lane_control[6] & lane_control[7] ;
      // Terminate in lane 5 :-
      type_d2 <= lane_data[0] & lane_data[1] & lane_data[2] & lane_data[3] & lane_data[4] & lane_terminate[5] & lane_control[6] & lane_control[7] ;
      // Terminate in lane 6 :-
      type_e1 <= lane_data[0] & lane_data[1] & lane_data[2] & lane_data[3] & lane_data[4] & lane_data[5] & lane_terminate[6] & lane_control[7] ;
      // Terminate in lane 7 :-
      type_ff <= lane_data[0] & lane_data[1] & lane_data[2] & lane_data[3] & lane_data[4] & lane_data[5] & lane_data[6] & lane_terminate[7] ;
      // None of the above scenarios means that the data is in an illegal format.
      type_illegal <= lane_control[0] | lane_control[1] | lane_control[2] | lane_control[3] | lane_control[4] | lane_control[5] | lane_control[6] | lane_control[7] ;
      type_data <= lane_data[0] & lane_data[1] & lane_data[2] & lane_data[3] & lane_data[4] & lane_data[5] & lane_data[6] & lane_data[7] ;
   endrule

   //-------------------------------------------------------------------------------
   // Translate these signals to give the actual type field output.
   // Prior to this the type signals above are registered as the delay through the
   // above equations could be considerable.
   //-------------------------------------------------------------------------------
   rule for_actual_type_field_output;
      type_reg <= {type_data, type_illegal, type_ff, type_e1, type_d2, type_cc, type_b4, type_aa, type_99, type_87, type_4b, type_78, type_55, type_66, type_33, type_2d, type_1e} ;
   endrule

   //-------------------------------------------------------------------------------
   // Work out the ocode that is sent
   //-------------------------------------------------------------------------------
   rule generate_o_code;
      if (lane_seqr[0] == 1) begin
         o_code0 <= 4'b1111;
      end
      else begin
         o_code0 <= 4'b0000;
      end

      if (lane_seqr[4] == 1) begin
         o_code4 <= 4'b1111;
      end
      else begin
         o_code4 <= 4'b0000;
      end
   endrule

   rule generate_type_field;
      if ((type_reg[0]) == 1'b1) begin
         type_field <=  8'b00011110 ;
      end
      else if ((type_reg[1]) == 1'b1) begin
         type_field <=  8'b00101101 ;
      end
      else if ((type_reg[2]) == 1'b1) begin
         type_field <=  8'b00110011 ;
      end
      else if ((type_reg[3]) == 1'b1) begin
         type_field <=  8'b01100110 ;
      end
      else if ((type_reg[4]) == 1'b1) begin
         type_field <=  8'b01010101 ;
      end
      else if ((type_reg[5]) == 1'b1) begin
         type_field <=  8'b01111000 ;
      end
      else if ((type_reg[6]) == 1'b1) begin
         type_field <=  8'b01001011 ;
      end
      else if ((type_reg[7]) == 1'b1) begin
         type_field <=  8'b10000111 ;
      end
      else if ((type_reg[8]) == 1'b1) begin
         type_field <=  8'b10011001 ;
      end
      else if ((type_reg[9]) == 1'b1) begin
         type_field <=  8'b10101010 ;
      end
      else if ((type_reg[10]) == 1'b1) begin
         type_field <=  8'b10110100 ;
      end
      else if ((type_reg[11]) == 1'b1) begin
         type_field <=  8'b11001100 ;
      end
      else if ((type_reg[12]) == 1'b1) begin
         type_field <=  8'b11010010 ;
      end
      else if ((type_reg[13]) == 1'b1) begin
         type_field <=  8'b11100001 ;
      end
      else if ((type_reg[14]) == 1'b1) begin
         type_field <=  8'b11111111 ;
      end
      else if ((type_reg[15]) == 1'b1) begin
         type_field <=  8'b00011110 ;
      end
      else begin
         type_field <= pack(readVReg(reg_reg_txd))[7:0];
      end
   endrule
   //-------------------------------------------------------------------------------
   // Now figure out what the rest of the data output should be set to. This is
   // given in Figure 49-7 in the spec.
   //-------------------------------------------------------------------------------
   //-------------------------------------------------------------------------------
   // Firstly the sync field. This is 01 for a data double and 10 for a double
   // containing a control character.
   //-------------------------------------------------------------------------------
   rule for_sync_field;
      if (type_reg == 17'b10000000000000000) begin
         sync_field <= 2'b10 ;
      end
      else begin
         sync_field <= 2'b01 ;
      end
   endrule

   //-------------------------------------------------------------------------------
   // The remaining 7 bytes of the data output
   //-------------------------------------------------------------------------------
   //-------------------------------------------------------------------------------
   // The idle and error control characters are mapped from their 8-bit xgmii
   // representation into a 7-bit output representation. Idle (0x07) maps to 0x00
   // and error (0xFE) maps to 0x1e. The other control characters are encoded
   // by the type field.
   //-------------------------------------------------------------------------------
   rule for_lane_code;
      for (Integer i=0; i<8; i=i+1) begin
         if (lane_idle[i] == 1'b1) begin
            lane_code[i] <=  7'b0000000 ;
         end
         else if (lane_res0[i] == 1'b1) begin
            lane_code[i] <=  7'b0101101 ;
         end
         else if (lane_res1[i] == 1'b1) begin
            lane_code[i] <=  7'b0110011 ;
         end
         else if (lane_res2[i] == 1'b1) begin
            lane_code[i] <=  7'b1001011 ;
         end
         else if (lane_res3[i] == 1'b1) begin
            lane_code[i] <=  7'b1010101 ;
         end
         else if (lane_res4[i] == 1'b1) begin
            lane_code[i] <=  7'b1100110 ;
         end
         else if (lane_res5[i] == 1'b1) begin
            lane_code[i] <=  7'b1111000 ;
         end
         else begin
            lane_code[i] <=  7'b0011110 ;
         end
      end
   endrule

   //-------------------------------------------------------------------------------
   // Rest of the data output depends on the type_field :-
   //-------------------------------------------------------------------------------
   rule for_rest_of_data;
      if ((type_reg[0]) == 1'b1) begin
         // type 0x1e
         data_field <= {lane_code[7], lane_code[6], lane_code[5], lane_code[4], lane_code[3], lane_code[2], lane_code[1], lane_code[0]} ;
         int_error <=  1'b0 ;
      end
      else if ((type_reg[1]) == 1'b1) begin
         // type 0x2d
         data_field <=  {pack(readVReg(reg_reg_txd))[63:40], o_code4, lane_code[3], lane_code[2], lane_code[1], lane_code[0]} ;
         int_error <=  1'b0 ;
      end
      else if ((type_reg[2]) == 1'b1) begin
         // type 0x33
         data_field <=  {pack(readVReg(reg_reg_txd))[63:40], 4'b0000, lane_code[3], lane_code[2], lane_code[1], lane_code[0]} ;
         int_error <=  1'b0 ;
      end
      else if ((type_reg[3]) == 1'b1) begin
         // type 0x66
         data_field <=  {pack(readVReg(reg_reg_txd))[63:40], 4'b0000, o_code0, pack(readVReg(reg_reg_txd))[31:8]} ;
         int_error <=  1'b0 ;
      end
      else if ((type_reg[4]) == 1'b1) begin
         // type 0x55
         data_field <=  {pack(readVReg(reg_reg_txd))[63:40], o_code4, o_code0, pack(readVReg(reg_reg_txd))[31:8]} ;
         int_error <=  1'b0 ;
      end
      else if ((type_reg[5]) == 1'b1) begin
         // type 0x78
         data_field <=  pack(readVReg(reg_reg_txd))[63:8] ;
         int_error <=  1'b0 ;
      end
      else if ((type_reg[6]) == 1'b1) begin
         // type 0x4b
         data_field <= {lane_code[7], lane_code[6], lane_code[5], lane_code[4], o_code0, pack(readVReg(reg_reg_txd))[31:8]} ;
         int_error <=  1'b0 ;
      end
      else if ((type_reg[7]) == 1'b1) begin
         // type 0x87
         data_field <=  {lane_code[7], lane_code[6], lane_code[5], lane_code[4], lane_code[3], lane_code[2], lane_code[1], 7'b0000000} ;
         int_error <=  1'b0 ;
      end
      else if ((type_reg[8]) == 1'b1) begin
         // type 0x99
         data_field <=  {lane_code[7], lane_code[6], lane_code[5], lane_code[4], lane_code[3], lane_code[2], 6'b000000, pack(readVReg(reg_reg_txd))[7:0]} ;
         int_error <=  1'b0 ;
      end
      else if ((type_reg[9]) == 1'b1) begin
         // type 0xaa
         data_field <=  {lane_code[7], lane_code[6], lane_code[5], lane_code[4], lane_code[3], 5'b00000, pack(readVReg(reg_reg_txd))[15:0]} ;
         int_error <=  1'b0 ;
      end
      else if ((type_reg[10]) == 1'b1) begin
         // type 0xb4
         data_field <=  {lane_code[7], lane_code[6], lane_code[5], lane_code[4], 4'b0000, pack(readVReg(reg_reg_txd))[23:0]} ;
         int_error <=  1'b0 ;
      end
      else if ((type_reg[11]) == 1'b1) begin
         // type 0xcc
         data_field <=  {lane_code[7], lane_code[6], lane_code[5], 3'b000, pack(readVReg(reg_reg_txd))[31:0]} ;
         int_error <=  1'b0 ;
      end
      else if ((type_reg[12]) == 1'b1) begin
         // type 0xd2
         data_field <=  {lane_code[7], lane_code[6], 2'b00, pack(readVReg(reg_reg_txd))[39:0]} ;
         int_error <=  1'b0 ;
      end
      else if ((type_reg[13]) == 1'b1) begin
         // type 0xe1
         data_field <=  {lane_code[7], 1'b0, pack(readVReg(reg_reg_txd))[47:0]} ;
         int_error <=  1'b0 ;
      end
      else if ((type_reg[14]) == 1'b1) begin
         // type 0xff
         data_field <=  pack(readVReg(reg_reg_txd))[55:0] ;
         int_error <=  1'b0 ;
      end
      else if ((type_reg[15]) == 1'b1) begin
         // The data has a control character in it but it
         // doesn\'t conform to one of the above formats.
         data_field <=  {lane_code[7], lane_code[6], lane_code[5], lane_code[4], lane_code[3], lane_code[2], lane_code[1], lane_code[0]} ;
         int_error <=  1'b1 ;
      end
      else begin
         // If the input doesn\'t contain a control character then the data
         // is set to be the rest of the data.
         data_field <=  pack(readVReg(reg_reg_txd))[63:8] ;
         int_error <=  1'b0 ;
      end
   endrule

   //-------------------------------------------------------------------------------
   // Register the data before it leaves for the outside world.
   //-------------------------------------------------------------------------------
   rule for_data_out;
      writeVReg(take(data_out), unpack({data_field, type_field, sync_field}));
      fifo_out.enq(pack(readVReg(data_out)));
   endrule

   interface encoderOut = toPipeOut(fifo_out);
endmodule

endpackage
