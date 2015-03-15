
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

import Ethernet::*;

interface Decoder;
   interface PipeOut#(Bit#(72)) decoderOut;
endinterface

typedef enum {CONTROL, START, DATA, TERMINATE, ERROR} State
deriving (Bits, Eq);

module mkDecoder#(PipeOut#(Bit#(66)) decoderIn)(Decoder);

   let verbose = False;

   Reg#(Bit#(32)) cycle                 <- mkReg(0);
   FIFOF#(Bit#(66))  fifo_in            <- mkBypassFIFOF;
   FIFOF#(Bit#(72))  fifo_out           <- mkBypassFIFOF;
   Vector#(8, FIFOF#(Bit#(8)))  dataFifo      <- replicateM(mkFIFOF);
   Vector#(8, FIFOF#(Bit#(1)))  ctrlFifo      <- replicateM(mkFIFOF);
   Vector#(8, FIFOF#(Bit#(8)))  controlFifo   <- replicateM(mkFIFOF);
   Vector#(8, FIFOF#(Bit#(66))) dataFieldFifo <- replicateM(mkFIFOF);
   Vector#(8, FIFOF#(Bit#(15))) typeRegFifo   <- replicateM(mkFIFOF);
   FIFOF#(Bit#(1)) lane0Seq9cFifo       <- mkFIFOF;
   FIFOF#(Bit#(1)) lane0Seq5cFifo       <- mkFIFOF;
   FIFOF#(Bit#(1)) lane4Seq9cFifo       <- mkFIFOF;
   FIFOF#(Bit#(1)) lane4Seq5cFifo       <- mkFIFOF;

   rule cyc;
      cycle <= cycle + 1;
   endrule

   //-------------------------------------------------------------------------------
   // Extract the control bytes from the data_field bus. This is only
   // routed to the output when the sync_field is \"10\", indicating that
   // a control character has been sent. An idle is 0x00 at the input and this is
   // converted into a 0v07 for the xgmii. The others will be set to error. This
   // is because the other valid control characters except error are decoded
   // by the type field. The positions of each byte are given in figure 49-7 in the spec
   //-------------------------------------------------------------------------------
   rule stage1_decode;
      let v <- toGet(decoderIn).get;
      Bit#(2) sync_field = 0;
      Bit#(8) type_field = 0;
      Bit#(66) data_field = 0;
      Bit#(1) type_1e = 0;
      Bit#(1) type_2d = 0;
      Bit#(1) type_33 = 0;
      Bit#(1) type_66 = 0;
      Bit#(1) type_55 = 0;
      Bit#(1) type_78 = 0;
      Bit#(1) type_4b = 0;
      Bit#(1) type_87 = 0;
      Bit#(1) type_99 = 0;
      Bit#(1) type_aa = 0;
      Bit#(1) type_b4 = 0;
      Bit#(1) type_cc = 0;
      Bit#(1) type_d2 = 0;
      Bit#(1) type_e1 = 0;
      Bit#(1) type_ff = 0;
      Bit#(1) data_word   = 0;
      Bit#(1) control_word = 0;

      Bit#(1) lane0Seq9c = 0;
      Bit#(1) lane0Seq5c = 0;
      Bit#(1) lane4Seq9c = 0;
      Bit#(1) lane4Seq5c = 0;

      Bit#(15) type_reg = 0;

      sync_field = v[1:0];
      type_field = v[9:2];
      data_field = v;

      if(verbose) $display("%d: data in %h", cycle, v);
      Vector#(8, Bit#(8)) ctrl;
      for (Integer i=0; i<8; i=i+1) begin
         Integer idx_hi = (i+1)*7+9;
         Integer idx_lo = (i+1)*7+3;
         if (data_field[idx_hi:idx_lo] == 7'b0000000) begin
            ctrl[i] = 8'b00000111 ; // Idle character.
         end
         else if (data_field[idx_hi:idx_lo] == 7'b0101101) begin
            ctrl[i] = 8'b00011100 ; // Reserved 0 character.
         end
         else if (data_field[idx_hi:idx_lo] == 7'b0110011) begin
            ctrl[i] = 8'b00111100 ; // Reserved 1 character.
         end
         else if (data_field[idx_hi:idx_lo] == 7'b1001011) begin
            ctrl[i] = 8'b01111100 ; // Reserved 2 character.
         end
         else if (data_field[idx_hi:idx_lo] == 7'b1010101) begin
            ctrl[i] = 8'b10111100 ; // Reserved 3 character.
         end
         else if (data_field[idx_hi:idx_lo] == 7'b1100110) begin
            ctrl[i] = 8'b11011100 ; // Reserved 4 character.
         end
         else if (data_field[idx_hi:idx_lo] == 7'b1111000) begin
            ctrl[i] = 8'b11110111 ; // Reserved 5 character.
         end
         else begin
            ctrl[i] = 8'b11111110 ; // Error character.
         end
         controlFifo[i].enq(ctrl[i]);
      end

      //for (Integer i=0; i<8; i=i+1) begin
      //   if(verbose) $display("%d: ctrl[%d]=%h", cycle, i, ctrl[i]);
      //end

      //-------------------------------------------------------------------------------
      // Decode the sync field and the type field to determine what sort of data
      // word was transmitted. The different types are given in figure 49-7 in the spec.
      //-------------------------------------------------------------------------------
      data_word = ~(sync_field[0]) & sync_field[1] ;
      control_word = sync_field[0] & ~(sync_field[1]) ;
      type_1e = ~(type_field[7]) & ~(type_field[6]) & ~(type_field[5]) & type_field[4] & type_field[3] & type_field[2] & type_field[1] & ~(type_field[0]) ;
      type_2d = ~(type_field[7]) & ~(type_field[6]) & type_field[5] & ~(type_field[4]) & type_field[3] & type_field[2] & ~(type_field[1]) & type_field[0] ;
      type_33 = ~(type_field[7]) & ~(type_field[6]) & type_field[5] & type_field[4] & ~(type_field[3]) & ~(type_field[2]) & type_field[1] & type_field[0] ;
      type_66 = ~(type_field[7]) & type_field[6] & type_field[5] & ~(type_field[4]) & ~(type_field[3]) & type_field[2] & type_field[1] & ~(type_field[0]) ;
      type_55 = ~(type_field[7]) & type_field[6] & ~(type_field[5]) & type_field[4] & ~(type_field[3]) & type_field[2] & ~(type_field[1]) & type_field[0] ;
      type_78 = ~(type_field[7]) & type_field[6] & type_field[5] & type_field[4] & type_field[3] & ~(type_field[2]) & ~(type_field[1]) & ~(type_field[0]) ;
      type_4b = ~(type_field[7]) & type_field[6] & ~(type_field[5]) & ~(type_field[4]) & type_field[3] & ~(type_field[2]) & type_field[1] & type_field[0] ;
      type_87 = type_field[7] & ~(type_field[6]) & ~(type_field[5]) & ~(type_field[4]) & ~(type_field[3]) & type_field[2] & type_field[1] & type_field[0] ;
      type_99 = type_field[7] & ~(type_field[6]) & ~(type_field[5]) & type_field[4] & type_field[3] & ~(type_field[2]) & ~(type_field[1]) & type_field[0] ;
      type_aa = type_field[7] & ~(type_field[6]) & type_field[5] & ~(type_field[4]) & type_field[3] & ~(type_field[2]) & type_field[1] & ~(type_field[0]) ;
      type_b4 = type_field[7] & ~(type_field[6]) & type_field[5] & type_field[4] & ~(type_field[3]) & type_field[2] & ~(type_field[1]) & ~(type_field[0]) ;
      type_cc = type_field[7] & type_field[6] & ~(type_field[5]) & ~(type_field[4]) & type_field[3] & type_field[2] & ~(type_field[1]) & ~(type_field[0]) ;
      type_d2 = type_field[7] & type_field[6] & ~(type_field[5]) & type_field[4] & ~(type_field[3]) & ~(type_field[2]) & type_field[1] & ~(type_field[0]) ;
      type_e1 = type_field[7] & type_field[6] & type_field[5] & ~(type_field[4]) & ~(type_field[3]) & ~(type_field[2]) & ~(type_field[1]) & type_field[0] ;
      type_ff = type_field[7] & type_field[6] & type_field[5] & type_field[4] & type_field[3] & type_field[2] & type_field[1] & type_field[0] ;

      //-------------------------------------------------------------------------------
      // Translate these signals to give the type of data in each byte.
      // Prior to this the type signals above are registered as the delay through the
      // above equations could be considerable.
      //-------------------------------------------------------------------------------
      type_reg = ({(control_word & type_ff), (control_word & type_e1), (control_word & type_d2), (control_word & type_cc), (control_word & type_b4), (control_word & type_aa), (control_word & type_99), (control_word & type_87), (control_word & type_4b), (control_word & type_78), (control_word & type_55), (control_word & type_66), (control_word & type_33), (control_word & type_2d), (control_word & type_1e)}) ;

      if(verbose) $display("data_field %h", data_field);
      if(verbose) $display("typereg %h", type_reg);

      lane0Seq9c = (sync_field[0] & ~(sync_field[1])) & ((type_66 | type_55 | type_4b) & ~(data_field[35]) & ~(data_field[34]) & ~(data_field[33]) & ~(data_field[32])) ;
      lane0Seq5c = (sync_field[0] & ~(sync_field[1])) & ((type_66 | type_55 | type_4b) & data_field[35] & data_field[34] & data_field[33] & data_field[32]) ;
      lane4Seq9c = (sync_field[0] & ~(sync_field[1])) & ((type_2d | type_55) & ~(data_field[39]) & ~(data_field[38]) & ~(data_field[37]) & ~(data_field[36])) ;
      lane4Seq5c = (sync_field[0] & ~(sync_field[1])) & ((type_2d | type_55) & data_field[39] & data_field[38] & data_field[37] & data_field[36]) ;

      if(verbose) $display("laneseq %d %d %d %d", lane0Seq9c, lane0Seq5c, lane4Seq9c, lane4Seq5c);
 
      for (Integer i=0; i<8; i=i+1) begin
         dataFieldFifo[i].enq(data_field);
         typeRegFifo[i].enq(type_reg);
      end
      lane0Seq9cFifo.enq(lane0Seq9c);
      lane0Seq5cFifo.enq(lane0Seq5c);
      lane4Seq9cFifo.enq(lane4Seq9c);
      lane4Seq5cFifo.enq(lane4Seq5c);
   endrule

   //-------------------------------------------------------------------------------
   // Put the input data into the correct byte lane at the output.
   //-------------------------------------------------------------------------------
   rule for_lane0;
      let type_reg <- toGet(typeRegFifo[0]).get();
      let control  <- toGet(controlFifo[0]).get();
      let data_field <- toGet(dataFieldFifo[0]).get();
      let lane0_seq_9c <- toGet(lane0Seq9cFifo).get();
      let lane0_seq_5c <- toGet(lane0Seq5cFifo).get();

      Bit#(8) data = 0;
      Bit#(1) ctrl = 0;
      if (type_reg[2:0] != 3'b000)
      begin
         data = control; // Control character.
         ctrl = 1'b1 ;
      end
      else if ((type_reg[3]) == 1'b1 && lane0_seq_9c == 1'b1)
      begin
         data = 8'b10011100 ; // Sequence field (9C).
         ctrl = 1'b1 ;
      end
      else if ((type_reg[3]) == 1'b1 && lane0_seq_5c == 1'b1)
      begin
         data = 8'b01011100 ; // Sequence field (5C).
         ctrl = 1'b1 ;
      end
      else if ((type_reg[4]) == 1'b1 && lane0_seq_9c == 1'b1)
      begin
         data = 8'b10011100 ; // Sequence field (9C).
         ctrl = 1'b1 ;
      end
      else if ((type_reg[4]) == 1'b1 && lane0_seq_5c == 1'b1)
      begin
         data = 8'b01011100 ; // Sequence field (5C).
         ctrl = 1'b1 ;
      end
      else if ((type_reg[5]) == 1'b1)
      begin
         data = 8'b11111011 ; // Start field.
         ctrl = 1'b1 ;
      end
      else if ((type_reg[6]) == 1'b1 && lane0_seq_9c == 1'b1)
      begin
         data = 8'b10011100 ; // Sequence field (9C).
         ctrl = 1'b1 ;
      end
      else if ((type_reg[6]) == 1'b1 && lane0_seq_5c == 1'b1)
      begin
         data = 8'b01011100 ; // Sequence field (5C).
         ctrl = 1'b1 ;
      end
      else if ((type_reg[7]) == 1'b1)
      begin
         data = 8'b11111101 ; // Termimation.
         ctrl = 1'b1 ;
      end
      else if (type_reg[14:8] != 7'b0000000)
      begin
         data = data_field[17:10] ; // Data byte 0.
         ctrl = 1'b0 ;
      end
      else
      begin
         // If the input doesn\'t contain a control character then the type field
         // is set to be the first data byte.
         data = data_field[9:2] ;
         ctrl = 1'b0 ;
      end
      dataFifo[0].enq(data);
      ctrlFifo[0].enq(ctrl);
   endrule

   rule for_lane1 ;
      let type_reg <- toGet(typeRegFifo[1]).get();
      let control  <- toGet(controlFifo[1]).get();
      let data_field <- toGet(dataFieldFifo[1]).get();
      Bit#(8) data = 0;
      Bit#(1) ctrl = 0;
      if (type_reg[2:0] != 3'b000)
      begin
         data = control; // Control character.
         ctrl = 1'b1 ;
      end
      else if (type_reg[6:3] != 4'b0000)
      begin
         data = data_field[17:10] ; // Data byte 1
         ctrl = 1'b0 ;
      end
      else if ((type_reg[7]) == 1'b1)
      begin
         data = control; // Control character.
         ctrl = 1'b1 ;
      end
      else if ((type_reg[8]) == 1'b1)
      begin
         data = 8'b11111101 ; // Termination.
         ctrl = 1'b1 ;
      end
      else if (type_reg[14:9] != 6'b000000)
      begin
         data = data_field[25:18] ; // Data byte 1
         ctrl = 1'b0 ;
      end
      else
      begin
         // If the input doesn\'t contain a control character then the type field
         // is set to be the second data byte.
         data = data_field[17:10] ;
         ctrl = 1'b0 ;
      end
      dataFifo[1].enq(data);
      ctrlFifo[1].enq(ctrl);
   endrule

   rule for_lane2 ;
      let type_reg <- toGet(typeRegFifo[2]).get();
      let control  <- toGet(controlFifo[2]).get();
      let data_field <- toGet(dataFieldFifo[2]).get();
      Bit#(8) data = 0;
      Bit#(1) ctrl = 0;
      if (type_reg[2:0] != 3'b000 || type_reg[8:7] != 2'b00)
      begin
         data = control; // Control character.
         ctrl = 1'b1 ;
      end
      else if (type_reg[6:3] != 4'b0000)
      begin
         data = data_field[25:18] ; // Data byte 2
         ctrl = 1'b0 ;
      end
      else if ((type_reg[9]) == 1'b1)
      begin
         data = 8'b11111101 ; // Termination.
         ctrl = 1'b1 ;
      end
      else if (type_reg[14:10] != 5'b00000)
      begin
         data = data_field[33:26] ; // Data byte 2
         ctrl = 1'b0 ;
      end
      else
      begin
         // If the input doesn\'t contain a control character then the type field
         // is set to be the third data byte.
         data = data_field[25:18] ;
         ctrl = 1'b0 ;
      end
      dataFifo[2].enq(data);
      ctrlFifo[2].enq(ctrl);
   endrule

   rule for_lane3 ;
      let type_reg <- toGet(typeRegFifo[3]).get();
      let control  <- toGet(controlFifo[3]).get();
      let data_field <- toGet(dataFieldFifo[3]).get();
      Bit#(8) data = 0;
      Bit#(1) ctrl = 0;
      if (type_reg[2:0] != 3'b000 || type_reg[9:7] != 3'b000)
      begin
         data = control; // Control character.
         ctrl = 1'b1 ;
      end
      else if (type_reg[6:3] != 4'b0000)
      begin
         data = data_field[33:26] ; // Data byte 3
         ctrl = 1'b0 ;
      end
      else if ((type_reg[10]) == 1'b1)
      begin
         data = 8'b11111101 ; // Termination.
         ctrl = 1'b1 ;
      end
      else if (type_reg[14:11] != 4'b0000)
      begin
         data = data_field[41:34] ; // Data byte 3
         ctrl = 1'b0 ;
      end
      else
      begin
         // If the input doesn\'t contain a control character then the type field
         // is set to be the fourth data byte.
         data = data_field[33:26] ;
         ctrl = 1'b0 ;
      end
      dataFifo[3].enq(data);
      ctrlFifo[3].enq(ctrl);
   endrule

   rule for_lane4 ;
      let type_reg <- toGet(typeRegFifo[4]).get();
      let control  <- toGet(controlFifo[4]).get();
      let data_field <- toGet(dataFieldFifo[4]).get();
      let lane4_seq_9c <- toGet(lane4Seq9cFifo).get();
      let lane4_seq_5c <- toGet(lane4Seq5cFifo).get();
      Bit#(8) data = 0;
      Bit#(1) ctrl = 0;
      if ((type_reg[0]) == 1'b1 || type_reg[10:6] != 5'b00000)
      begin
         data = control; // Control character.
         ctrl = 1'b1 ;
      end
      else if ((type_reg[1]) == 1'b1 && lane4_seq_9c == 1'b1)
      begin
         data = 8'b10011100 ; // Sequence field.
         ctrl = 1'b1 ;
      end
      else if ((type_reg[1]) == 1'b1 && lane4_seq_5c == 1'b1)
      begin
         data = 8'b01011100 ; // Sequence field.
         ctrl = 1'b1 ;
      end
      else if ((type_reg[2]) == 1'b1)
      begin
         data = 8'b11111011 ; // Start field.
         ctrl = 1'b1 ;
      end
      else if ((type_reg[3]) == 1'b1)
      begin
         data = 8'b11111011 ; // Start field.
         ctrl = 1'b1 ;
      end
      else if ((type_reg[4]) == 1'b1 && lane4_seq_9c == 1'b1)
      begin
         data = 8'b10011100 ; // Sequence field.
         ctrl = 1'b1 ;
      end
      else if ((type_reg[4]) == 1'b1 && lane4_seq_5c == 1'b1)
      begin
         data = 8'b01011100 ; // Sequence field.
         ctrl = 1'b1 ;
      end
      else if ((type_reg[5]) == 1'b1)
      begin
         data = data_field[41:34] ; // Termimation.
         ctrl = 1'b0 ;
      end
      else if ((type_reg[11]) == 1'b1)
      begin
         data = 8'b11111101 ; // Termination.
         ctrl = 1'b1 ;
      end
      else if (type_reg[14:12] != 3'b000)
      begin
         data = data_field[49:42] ; // Data byte 4.
         ctrl = 1'b0 ;
      end
      else
      begin
         // If the input doesn\'t contain a control character then the type field
         // is set to be the fifth data byte.
         data = data_field[41:34] ;
         ctrl = 1'b0 ;
      end
      dataFifo[4].enq(data);
      ctrlFifo[4].enq(ctrl);
   endrule

   rule for_lane5 ;
      let type_reg <- toGet(typeRegFifo[5]).get();
      let control  <- toGet(controlFifo[5]).get();
      let data_field <- toGet(dataFieldFifo[5]).get();
      Bit#(8) data = 0;
      Bit#(1) ctrl = 0;
      if ((type_reg[0]) == 1'b1 || type_reg[11:6] != 6'b000000)
      begin
         data = control; // Control character.
         ctrl = 1'b1 ;
      end
      else if (type_reg[5:1] != 5'b00000)
      begin
         data = data_field[49:42] ; // Data byte 5
         ctrl = 1'b0 ;
      end
      else if ((type_reg[12]) == 1'b1)
      begin
         data = 8'b11111101 ; // Termination.
         ctrl = 1'b1 ;
      end
      else if (type_reg[14:13] != 2'b00)
      begin
         data = data_field[57:50] ; // Data byte 5
         ctrl = 1'b0 ;
      end
      else
      begin
         // If the input doesn\'t contain a control character then the type field
         // is set to be the sixth data byte.
         data = data_field[49:42] ;
         ctrl = 1'b0 ;
      end
      dataFifo[5].enq(data);
      ctrlFifo[5].enq(ctrl);
   endrule

   rule for_lane6 ;
      let type_reg <- toGet(typeRegFifo[6]).get();
      let control  <- toGet(controlFifo[6]).get();
      let data_field <- toGet(dataFieldFifo[6]).get();
      Bit#(8) data = 0;
      Bit#(1) ctrl = 0;
      if ((type_reg[0]) == 1'b1 || type_reg[12:6] != 7'b0000000)
      begin
         data = control; // Control character.
         ctrl = 1'b1 ;
      end
      else if (type_reg[5:1] != 5'b00000)
      begin
         data = data_field[57:50] ; // Data byte 6
         ctrl = 1'b0 ;
      end
      else if ((type_reg[13]) == 1'b1)
      begin
         data = 8'b11111101 ; // Termination.
         ctrl = 1'b1 ;
      end
      else if ((type_reg[14]) == 1'b1)
      begin
         data = data_field[65:58] ; // Data byte 6
         ctrl = 1'b0 ;
      end
      else
      begin
         // If the input doesn\'t contain a control character then the type field
         // is set to be the seventh data byte.
         data = data_field[57:50] ;
         ctrl = 1'b0 ;
      end
      dataFifo[6].enq(data);
      ctrlFifo[6].enq(ctrl);
   endrule

   rule for_lane7 ;
      let type_reg <- toGet(typeRegFifo[7]).get();
      let control  <- toGet(controlFifo[7]).get();
      let data_field <- toGet(dataFieldFifo[7]).get();
      Bit#(8) data = 0;
      Bit#(1) ctrl = 0;
      if ((type_reg[0]) == 1'b1 || type_reg[13:6] != 8'b00000000)
      begin
         data = control; // Control character.
         ctrl = 1'b1 ;
      end
      else if (type_reg[5:1] != 5'b00000)
      begin
         data = data_field[65:58] ; // Data byte 7
         ctrl = 1'b0 ;
      end
      else if ((type_reg[14]) == 1'b1)
      begin
         data = 8'b11111101 ; // Termination.
         ctrl = 1'b1 ;
      end
      else
      begin
         // If the input doesn\'t contain a control character then the type field
         // is set to be the last data byte.
         data = data_field[65:58] ;
         ctrl = 1'b0 ;
      end
      dataFifo[7].enq(data);
      ctrlFifo[7].enq(ctrl);
   endrule

   rule for_output;
      let data7 <- toGet(dataFifo[7]).get();
      let ctrl7 <- toGet(ctrlFifo[7]).get();
      let data6 <- toGet(dataFifo[6]).get();
      let ctrl6 <- toGet(ctrlFifo[6]).get();
      let data5 <- toGet(dataFifo[5]).get();
      let ctrl5 <- toGet(ctrlFifo[5]).get();
      let data4 <- toGet(dataFifo[4]).get();
      let ctrl4 <- toGet(ctrlFifo[4]).get();
      let data3 <- toGet(dataFifo[3]).get();
      let ctrl3 <- toGet(ctrlFifo[3]).get();
      let data2 <- toGet(dataFifo[2]).get();
      let ctrl2 <- toGet(ctrlFifo[2]).get();
      let data1 <- toGet(dataFifo[1]).get();
      let ctrl1 <- toGet(ctrlFifo[1]).get();
      let data0 <- toGet(dataFifo[0]).get();
      let ctrl0 <- toGet(ctrlFifo[0]).get();

      fifo_out.enq({ctrl7,data7,ctrl6,data6,ctrl5,data5,ctrl4,data4,
                    ctrl3,data3,ctrl2,data2,ctrl1,data1,ctrl0,data0});
   endrule

   interface decoderOut=toPipeOut(fifo_out);
endmodule

endpackage
