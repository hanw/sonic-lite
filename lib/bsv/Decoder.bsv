
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

package Decoder;

import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;

import Pipe::*;
import MemTypes::*;

import Ethernet::*;

interface Decoder;
   interface PipeOut#(Bit#(72)) decoderOut;
endinterface

typedef enum {CONTROL, START, DATA, TERMINATE, ERROR} State
deriving (Bits, Eq);

module mkDecoder#(PipeOut#(Bit#(66)) decoderIn)(Decoder);

   let verbose = True;
   Reg#(Bit#(32)) cycle         <- mkReg(0);
   FIFOF#(Bit#(66))  fifo_in    <- mkBypassFIFOF;
   FIFOF#(Bit#(72))  fifo_out   <- mkBypassFIFOF;

   //---------------------------------------------------------------------------------
   // Signals that hold the value of the data and the coresponding control bit
   // for each byte lane.
   //---------------------------------------------------------------------------------
   Reg#(Bit#(8)) byte0 <- mkReg(0);
   Reg#(Bit#(8)) byte1 <- mkReg(0);
   Reg#(Bit#(8)) byte2 <- mkReg(0);
   Reg#(Bit#(8)) byte3 <- mkReg(0);
   Reg#(Bit#(8)) byte4 <- mkReg(0);
   Reg#(Bit#(8)) byte5 <- mkReg(0);
   Reg#(Bit#(8)) byte6 <- mkReg(0);
   Reg#(Bit#(8)) byte7 <- mkReg(0);
   Reg#(Bit#(1)) c0    <- mkReg(0);
   Reg#(Bit#(1)) c1    <- mkReg(0);
   Reg#(Bit#(1)) c2    <- mkReg(0);
   Reg#(Bit#(1)) c3    <- mkReg(0);
   Reg#(Bit#(1)) c4    <- mkReg(0);
   Reg#(Bit#(1)) c5    <- mkReg(0);
   Reg#(Bit#(1)) c6    <- mkReg(0);
   Reg#(Bit#(1)) c7    <- mkReg(0);

   //---------------------------------------------------------------------------------
   // Signals to hold the value in each component of the input data.
   //---------------------------------------------------------------------------------
   Wire#(Bit#(2)) sync_field <- mkDWire(0);
   Wire#(Bit#(8)) type_field <- mkDWire(0);
   Wire#(Bit#(66)) data_field<- mkDWire(0);
   Wire#(Bit#(1)) data_word    <- mkDWire(0);
   Wire#(Bit#(1)) control_word <- mkDWire(0);

   //---------------------------------------------------------------------------------
   // A signal for each valid type field value.
   //---------------------------------------------------------------------------------
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

   Reg#(Bit#(15)) type_reg <- mkReg(0);

   //---------------------------------------------------------------------------------
   // Internal data bus signals.
   //---------------------------------------------------------------------------------
   Wire#(Bit#(66)) int_data_in <- mkDWire(0);
   Reg#(Bit#(66))  data_field_reg <- mkReg(0);

   //---------------------------------------------------------------------------------
   // Signals for decoding the control characters.
   //---------------------------------------------------------------------------------
   Vector#(8, Reg#(Bit#(8))) control <- replicateM(mkReg(0));

   //---------------------------------------------------------------------------------
   // Signals output to the fifo to indicate when ordered sets are being received.
   //---------------------------------------------------------------------------------
   Reg#(Bit#(1)) lane0_seq_9c <- mkReg(0);
   Reg#(Bit#(1)) lane0_seq_5c <- mkReg(0);
   Reg#(Bit#(1)) lane4_seq_9c <- mkReg(0);
   Reg#(Bit#(1)) lane4_seq_5c <- mkReg(0);

   rule cyc;
      cycle <= cycle + 1;
   endrule

   rule incoming;
      let v <- toGet(decoderIn).get;
      sync_field <= v[1:0];
      type_field <= v[9:2];
      data_field <= v;
      data_field_reg <= v;
      fifo_in.enq(v);
   endrule

   //-------------------------------------------------------------------------------
   // Extract the control bytes from the data_field bus. This is only
   // routed to the output when the sync_field is \"10\", indicating that
   // a control character has been sent. An idle is 0x00 at the input and this is
   // converted into a 0v07 for the xgmii. The others will be set to error. This
   // is because the other valid control characters except error are decoded
   // by the type field. The positions of each byte are given in figure 49-7 in the spec
   //-------------------------------------------------------------------------------
   rule for_control_word;
      for (Integer i=0; i<8; i=i+1) begin
         Integer idx_hi = (i+1)*7+9;
         Integer idx_lo = (i+1)*7+3;
         if (data_field[idx_hi:idx_lo] == 7'b0000000) begin
            control[i] <= 8'b00000111 ; // Idle character.
         end
         else if (data_field[idx_hi:idx_lo] == 7'b0101101) begin
            control[i] <= 8'b00011100 ; // Reserved 0 character.
         end
         else if (data_field[idx_hi:idx_lo] == 7'b0110011) begin
            control[i] <= 8'b00111100 ; // Reserved 1 character.
         end
         else if (data_field[idx_hi:idx_lo] == 7'b1001011) begin
            control[i] <= 8'b01111100 ; // Reserved 2 character.
         end
         else if (data_field[idx_hi:idx_lo] == 7'b1010101) begin
            control[i] <= 8'b10111100 ; // Reserved 3 character.
         end
         else if (data_field[idx_hi:idx_lo] == 7'b1100110) begin
            control[i] <= 8'b11011100 ; // Reserved 4 character.
         end
         else if (data_field[idx_hi:idx_lo] == 7'b1111000) begin
            control[i] <= 8'b11110111 ; // Reserved 5 character.
         end
         else begin
            control[i] <= 8'b11111110 ; // Error character.
         end
      end
   endrule

   rule for_lane_seq;
      lane0_seq_9c <= (sync_field[0] & ~(sync_field[1])) & ((type_66 | type_55 | type_4b) & ~(data_field[35]) & ~(data_field[34]) & ~(data_field[33]) & ~(data_field[32])) ;
      lane0_seq_5c <= (sync_field[0] & ~(sync_field[1])) & ((type_66 | type_55 | type_4b) & data_field[35] & data_field[34] & data_field[33] & data_field[32]) ;
      lane4_seq_9c <= (sync_field[0] & ~(sync_field[1])) & ((type_2d | type_55) & ~(data_field[39]) & ~(data_field[38]) & ~(data_field[37]) & ~(data_field[36])) ;
      lane4_seq_5c <= (sync_field[0] & ~(sync_field[1])) & ((type_2d | type_55) & data_field[39] & data_field[38] & data_field[37] & data_field[36]) ;
   endrule

   //-------------------------------------------------------------------------------
   // Decode the sync field and the type field to determine what sort of data
   // word was transmitted. The different types are given in figure 49-7 in the spec.
   //-------------------------------------------------------------------------------
   rule for_control_field;
      data_word <= ~(sync_field[0]) & sync_field[1] ;
      control_word <= sync_field[0] & ~(sync_field[1]) ;
      type_1e <= ~(type_field[7]) & ~(type_field[6]) & ~(type_field[5]) & type_field[4] & type_field[3] & type_field[2] & type_field[1] & ~(type_field[0]) ;
      type_2d <= ~(type_field[7]) & ~(type_field[6]) & type_field[5] & ~(type_field[4]) & type_field[3] & type_field[2] & ~(type_field[1]) & type_field[0] ;
      type_33 <= ~(type_field[7]) & ~(type_field[6]) & type_field[5] & type_field[4] & ~(type_field[3]) & ~(type_field[2]) & type_field[1] & type_field[0] ;
      type_66 <= ~(type_field[7]) & type_field[6] & type_field[5] & ~(type_field[4]) & ~(type_field[3]) & type_field[2] & type_field[1] & ~(type_field[0]) ;
      type_55 <= ~(type_field[7]) & type_field[6] & ~(type_field[5]) & type_field[4] & ~(type_field[3]) & type_field[2] & ~(type_field[1]) & type_field[0] ;
      type_78 <= ~(type_field[7]) & type_field[6] & type_field[5] & type_field[4] & type_field[3] & ~(type_field[2]) & ~(type_field[1]) & ~(type_field[0]) ;
      type_4b <= ~(type_field[7]) & type_field[6] & ~(type_field[5]) & ~(type_field[4]) & type_field[3] & ~(type_field[2]) & type_field[1] & type_field[0] ;
      type_87 <= type_field[7] & ~(type_field[6]) & ~(type_field[5]) & ~(type_field[4]) & ~(type_field[3]) & type_field[2] & type_field[1] & type_field[0] ;
      type_99 <= type_field[7] & ~(type_field[6]) & ~(type_field[5]) & type_field[4] & type_field[3] & ~(type_field[2]) & ~(type_field[1]) & type_field[0] ;
      type_aa <= type_field[7] & ~(type_field[6]) & type_field[5] & ~(type_field[4]) & type_field[3] & ~(type_field[2]) & type_field[1] & ~(type_field[0]) ;
      type_b4 <= type_field[7] & ~(type_field[6]) & type_field[5] & type_field[4] & ~(type_field[3]) & type_field[2] & ~(type_field[1]) & ~(type_field[0]) ;
      type_cc <= type_field[7] & type_field[6] & ~(type_field[5]) & ~(type_field[4]) & type_field[3] & type_field[2] & ~(type_field[1]) & ~(type_field[0]) ;
      type_d2 <= type_field[7] & type_field[6] & ~(type_field[5]) & type_field[4] & ~(type_field[3]) & ~(type_field[2]) & type_field[1] & ~(type_field[0]) ;
      type_e1 <= type_field[7] & type_field[6] & type_field[5] & ~(type_field[4]) & ~(type_field[3]) & ~(type_field[2]) & ~(type_field[1]) & type_field[0] ;
      type_ff <= type_field[7] & type_field[6] & type_field[5] & type_field[4] & type_field[3] & type_field[2] & type_field[1] & type_field[0] ;
   endrule

   //-------------------------------------------------------------------------------
   // Translate these signals to give the type of data in each byte.
   // Prior to this the type signals above are registered as the delay through the
   // above equations could be considerable.
   //-------------------------------------------------------------------------------

   rule for_type_reg;
      type_reg <= ({(control_word & type_ff), (control_word & type_e1), (control_word & type_d2), (control_word & type_cc), (control_word & type_b4), (control_word & type_aa), (control_word & type_99), (control_word & type_87), (control_word & type_4b), (control_word & type_78), (control_word & type_55), (control_word & type_66), (control_word & type_33), (control_word & type_2d), (control_word & type_1e)}) ;
   endrule

   //-------------------------------------------------------------------------------
   // Put the input data into the correct byte lane at the output.
   //-------------------------------------------------------------------------------
   rule for_lane0;
      if (type_reg[2:0] != 3'b000)
      begin
         byte0 <= control[0] ; // Control character.
         c0 <= 1'b1 ;
      end
      else if ((type_reg[3]) == 1'b1 && lane0_seq_9c == 1'b1)
      begin
         byte0 <= 8'b10011100 ; // Sequence field (9C).
         c0 <= 1'b1 ;
      end
      else if ((type_reg[3]) == 1'b1 && lane0_seq_5c == 1'b1)
      begin
         byte0 <= 8'b01011100 ; // Sequence field (5C).
         c0 <= 1'b1 ;
      end
      else if ((type_reg[4]) == 1'b1 && lane0_seq_9c == 1'b1)
      begin
         byte0 <= 8'b10011100 ; // Sequence field (9C).
         c0 <= 1'b1 ;
      end
      else if ((type_reg[4]) == 1'b1 && lane0_seq_5c == 1'b1)
      begin
         byte0 <= 8'b01011100 ; // Sequence field (5C).
         c0 <= 1'b1 ;
      end
      else if ((type_reg[5]) == 1'b1)
      begin
         byte0 <= 8'b11111011 ; // Start field.
         c0 <= 1'b1 ;
      end
      else if ((type_reg[6]) == 1'b1 && lane0_seq_9c == 1'b1)
      begin
         byte0 <= 8'b10011100 ; // Sequence field (9C).
         c0 <= 1'b1 ;
      end
      else if ((type_reg[6]) == 1'b1 && lane0_seq_5c == 1'b1)
      begin
         byte0 <= 8'b01011100 ; // Sequence field (5C).
         c0 <= 1'b1 ;
      end
      else if ((type_reg[7]) == 1'b1)
      begin
         byte0 <= 8'b11111101 ; // Termimation.
         c0 <= 1'b1 ;
      end
      else if (type_reg[14:8] != 7'b0000000)
      begin
         byte0 <= data_field_reg[17:10] ; // Data byte 0.
         c0 <= 1'b0 ;
      end
      else
      begin
         // If the input doesn\'t contain a control character then the type field
         // is set to be the first data byte.
         byte0 <= data_field_reg[9:2] ;
         c0 <= 1'b0 ;
      end
   endrule

   rule for_lane1;
      if (type_reg[2:0] != 3'b000)
      begin
         byte1 <= control[1] ; // Control character.
         c1 <= 1'b1 ;
      end
      else if (type_reg[6:3] != 4'b0000)
      begin
         byte1 <= data_field_reg[17:10] ; // Data byte 1
         c1 <= 1'b0 ;
      end
      else if ((type_reg[7]) == 1'b1)
      begin
         byte1 <= control[1] ; // Control character.
         c1 <= 1'b1 ;
      end
      else if ((type_reg[8]) == 1'b1)
      begin
         byte1 <= 8'b11111101 ; // Termination.
         c1 <= 1'b1 ;
      end
      else if (type_reg[14:9] != 6'b000000)
      begin
         byte1 <= data_field_reg[25:18] ; // Data byte 1
         c1 <= 1'b0 ;
      end
      else
      begin
         // If the input doesn\'t contain a control character then the type field
         // is set to be the second data byte.
         byte1 <= data_field_reg[17:10] ;
         c1 <= 1'b0 ;
      end
   endrule

   rule for_lane2;
      if (type_reg[2:0] != 3'b000 || type_reg[8:7] != 2'b00)
      begin
         byte2 <= control[2] ; // Control character.
         c2 <= 1'b1 ;
      end
      else if (type_reg[6:3] != 4'b0000)
      begin
         byte2 <= data_field_reg[25:18] ; // Data byte 2
         c2 <= 1'b0 ;
      end
      else if ((type_reg[9]) == 1'b1)
      begin
         byte2 <= 8'b11111101 ; // Termination.
         c2 <= 1'b1 ;
      end
      else if (type_reg[14:10] != 5'b00000)
      begin
         byte2 <= data_field_reg[33:26] ; // Data byte 2
         c2 <= 1'b0 ;
      end
      else
      begin
         // If the input doesn\'t contain a control character then the type field
         // is set to be the third data byte.
         byte2 <= data_field_reg[25:18] ;
         c2 <= 1'b0 ;
      end
   endrule

   rule for_lane3;
      if (type_reg[2:0] != 3'b000 || type_reg[9:7] != 3'b000)
      begin
         byte3 <= control[3] ; // Control character.
         c3 <= 1'b1 ;
      end
      else if (type_reg[6:3] != 4'b0000)
      begin
         byte3 <= data_field_reg[33:26] ; // Data byte 3
         c3 <= 1'b0 ;
      end
      else if ((type_reg[10]) == 1'b1)
      begin
         byte3 <= 8'b11111101 ; // Termination.
         c3 <= 1'b1 ;
      end
      else if (type_reg[14:11] != 4'b0000)
      begin
         byte3 <= data_field_reg[41:34] ; // Data byte 3
         c3 <= 1'b0 ;
      end
      else
      begin
         // If the input doesn\'t contain a control character then the type field
         // is set to be the fourth data byte.
         byte3 <= data_field_reg[33:26] ;
         c3 <= 1'b0 ;
      end
   endrule

   rule for_lane4;
      if ((type_reg[0]) == 1'b1 || type_reg[10:6] != 5'b00000)
      begin
         byte4 <= control[4] ; // Control character.
         c4 <= 1'b1 ;
      end
      else if ((type_reg[1]) == 1'b1 && lane4_seq_9c == 1'b1)
      begin
         byte4 <= 8'b10011100 ; // Sequence field.
         c4 <= 1'b1 ;
      end
      else if ((type_reg[1]) == 1'b1 && lane4_seq_5c == 1'b1)
      begin
         byte4 <= 8'b01011100 ; // Sequence field.
         c4 <= 1'b1 ;
      end
      else if ((type_reg[2]) == 1'b1)
      begin
         byte4 <= 8'b11111011 ; // Start field.
         c4 <= 1'b1 ;
      end
      else if ((type_reg[3]) == 1'b1)
      begin
         byte4 <= 8'b11111011 ; // Start field.
         c4 <= 1'b1 ;
      end
      else if ((type_reg[4]) == 1'b1 && lane4_seq_9c == 1'b1)
      begin
         byte4 <= 8'b10011100 ; // Sequence field.
         c4 <= 1'b1 ;
      end
      else if ((type_reg[4]) == 1'b1 && lane4_seq_5c == 1'b1)
      begin
         byte4 <= 8'b01011100 ; // Sequence field.
         c4 <= 1'b1 ;
      end
      else if ((type_reg[5]) == 1'b1)
      begin
         byte4 <= data_field_reg[41:34] ; // Termimation.
         c4 <= 1'b0 ;
      end
      else if ((type_reg[11]) == 1'b1)
      begin
         byte4 <= 8'b11111101 ; // Termination.
         c4 <= 1'b1 ;
      end
      else if (type_reg[14:12] != 3'b000)
      begin
         byte4 <= data_field_reg[49:42] ; // Data byte 4.
         c4 <= 1'b0 ;
      end
      else
      begin
         // If the input doesn\'t contain a control character then the type field
         // is set to be the fifth data byte.
         byte4 <= data_field_reg[41:34] ;
         c4 <= 1'b0 ;
      end
   endrule

   rule for_lane5;
      if ((type_reg[0]) == 1'b1 || type_reg[11:6] != 6'b000000)
      begin
         byte5 <= control[5] ; // Control character.
         c5 <= 1'b1 ;
      end
      else if (type_reg[5:1] != 5'b00000)
      begin
         byte5 <= data_field_reg[49:42] ; // Data byte 5
         c5 <= 1'b0 ;
      end
      else if ((type_reg[12]) == 1'b1)
      begin
         byte5 <= 8'b11111101 ; // Termination.
         c5 <= 1'b1 ;
      end
      else if (type_reg[14:13] != 2'b00)
      begin
         byte5 <= data_field_reg[57:50] ; // Data byte 5
         c5 <= 1'b0 ;
      end
      else
      begin
         // If the input doesn\'t contain a control character then the type field
         // is set to be the sixth data byte.
         byte5 <= data_field_reg[49:42] ;
         c5 <= 1'b0 ;
      end
   endrule

   rule for_lane6;
      if ((type_reg[0]) == 1'b1 || type_reg[12:6] != 7'b0000000)
      begin
         byte6 <= control[6] ; // Control character.
         c6 <= 1'b1 ;
      end
      else if (type_reg[5:1] != 5'b00000)
      begin
         byte6 <= data_field_reg[57:50] ; // Data byte 6
         c6 <= 1'b0 ;
      end
      else if ((type_reg[13]) == 1'b1)
      begin
         byte6 <= 8'b11111101 ; // Termination.
         c6 <= 1'b1 ;
      end
      else if ((type_reg[14]) == 1'b1)
      begin
         byte6 <= data_field_reg[65:58] ; // Data byte 6
         c6 <= 1'b0 ;
      end
      else
      begin
         // If the input doesn\'t contain a control character then the type field
         // is set to be the seventh data byte.
         byte6 <= data_field_reg[57:50] ;
         c6 <= 1'b0 ;
      end
   endrule

   rule for_lane7;
      if ((type_reg[0]) == 1'b1 || type_reg[13:6] != 8'b00000000)
      begin
         byte7 <= control[7] ; // Control character.
         c7 <= 1'b1 ;
      end
      else if (type_reg[5:1] != 5'b00000)
      begin
         byte7 <= data_field_reg[65:58] ; // Data byte 7
         c7 <= 1'b0 ;
      end
      else if ((type_reg[14]) == 1'b1)
      begin
         byte7 <= 8'b11111101 ; // Termination.
         c7 <= 1'b1 ;
      end
      else
      begin
         // If the input doesn\'t contain a control character then the type field
         // is set to be the last data byte.
         byte7 <= data_field_reg[65:58] ;
         c7 <= 1'b0 ;
      end
   endrule

   rule for_output;
      fifo_out.enq({byte7,c7,byte6,c6,byte5,c5,byte4,c4,
                    byte3,c3,byte2,c2,byte1,c1,byte0,c0});
   endrule

   interface decoderOut=toPipeOut(fifo_out);
endmodule

endpackage
