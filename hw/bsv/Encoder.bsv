
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
import Ethernet::*;

interface Encoder;
   interface PipeIn#(Bit#(72)) encoderIn;
   interface PipeOut#(Bit#(66)) encoderOut;
   (* always_ready, always_enabled *)
   method Action tx_ready(Bool v);
   method PcsDbgRec dbg;
endinterface

typedef enum {CONTROL, START, DATA, TERMINATE, ERROR} State
deriving (Bits, Eq);

typedef struct {
   Bit#(8) laneData;
   Bit#(8) laneControl;
   Bit#(8) laneIdle;
   Bit#(8) laneTerminate;
   Bit#(8) laneRes0;
   Bit#(8) laneRes1;
   Bit#(8) laneRes2;
   Bit#(8) laneRes3;
   Bit#(8) laneRes4;
   Bit#(8) laneRes5;
   Bit#(8) laneStart;
   Bit#(8) laneError;
   Bit#(8) laneSeq;
   Bit#(8) laneSeqr;
   Bit#(64) xgmiiTxd;
   Bit#(8)  xgmiiTxc;
} LaneInfo deriving (Eq, Bits, FShow);

typedef struct {
   Bit#(7) laneCode0;
   Bit#(7) laneCode1;
   Bit#(7) laneCode2;
   Bit#(7) laneCode3;
   Bit#(7) laneCode4;
   Bit#(7) laneCode5;
   Bit#(7) laneCode6;
   Bit#(7) laneCode7;
   Bit#(17) typeReg;
   Bit#(4)  oCode0;
   Bit#(4)  oCode4;
   Bit#(64) xgmiiTxd;
   Bit#(8)  xgmiiTxc;
} TypeInfo deriving (Eq, Bits, FShow);

//(* synthesize *)
module mkEncoder#(Integer id)(Encoder);

   let verbose = True;

   Reg#(Bit#(32)) cycle         <- mkReg(0);

   FIFOF#(Bit#(72)) fifo_in    <- mkFIFOF;
   FIFOF#(Bit#(66)) fifo_out   <- mkFIFOF;
   Wire#(Bool) tx_ready_wire   <- mkDWire(False);

   // for debugging
   Reg#(Bit#(64)) debug_bytes <- mkReg(0);
   Reg#(Bit#(64)) debug_starts <- mkReg(0);
   Reg#(Bit#(64)) debug_ends <- mkReg(0);
   Reg#(Bit#(64)) debug_errorframes <- mkReg(0);
   Reg#(Bit#(64)) debug_frames <- mkReg(0);

   // TODO: remove all these fifos.
   //---------------------------------------------------------------------------------
   // Signals used to indicate what type of data is in each of the pre-xgmii data lanes.
   //---------------------------------------------------------------------------------
//   FIFOF#(Bit#(8)) laneDataFifo      <- mkBypassFIFOF;
//   FIFOF#(Bit#(8)) laneControlFifo   <- mkBypassFIFOF;
//   FIFOF#(Bit#(8)) laneIdleFifo      <- mkBypassFIFOF;
//   FIFOF#(Bit#(8)) laneTerminateFifo <- mkBypassFIFOF;
//   FIFOF#(Bit#(8)) laneRes0Fifo      <- mkBypassFIFOF;
//   FIFOF#(Bit#(8)) laneRes1Fifo      <- mkBypassFIFOF;
//   FIFOF#(Bit#(8)) laneRes2Fifo      <- mkBypassFIFOF;
//   FIFOF#(Bit#(8)) laneRes3Fifo      <- mkBypassFIFOF;
//   FIFOF#(Bit#(8)) laneRes4Fifo      <- mkBypassFIFOF;
//   FIFOF#(Bit#(8)) laneRes5Fifo      <- mkBypassFIFOF;
//
//   FIFOF#(Bit#(8)) laneStartFifo     <- mkBypassFIFOF;
//   FIFOF#(Bit#(8)) laneErrorFifo     <- mkBypassFIFOF;
//   FIFOF#(Bit#(8)) laneSeqFifo       <- mkBypassFIFOF;
//   FIFOF#(Bit#(8)) laneSeqrFifo      <- mkBypassFIFOF;

   //---------------------------------------------------------------------------------
   // Internal data and control bus signals.
   //---------------------------------------------------------------------------------
//   FIFOF#(Bit#(64)) xgmiiTxdFifo1 <- mkBypassFIFOF;
//   FIFOF#(Bit#(8))  xgmiiTxcFifo1 <- mkBypassFIFOF;
//   FIFOF#(Bit#(64)) xgmiiTxdFifo2 <- mkBypassFIFOF;
//   FIFOF#(Bit#(8))  xgmiiTxcFifo2 <- mkBypassFIFOF;
//   //---------------------------------------------------------------------------------
//   // Signals for the type field generation.
//   //---------------------------------------------------------------------------------
//   FIFOF#(Bit#(17)) typeRegFifo    <- mkBypassFIFOF;
//   FIFOF#(Bit#(4))  oCode0Fifo     <- mkBypassFIFOF;
//   FIFOF#(Bit#(4))  oCode4Fifo     <- mkBypassFIFOF;
//   FIFOF#(Vector#(8, Bit#(7))) laneCodeFifo <- mkBypassFIFOF;

   FIFO#(LaneInfo) laneInfoFifo <- mkFIFO;
   FIFO#(TypeInfo) typeInfoFifo <- mkFIFO;

   rule cyc;
      cycle <= cycle + 1;
   endrule

   //-------------------------------------------------------------------------------
   // Generate the lane 0 data and control signals. These are dependent on just the
   // TXC(0) input from the MAC. 0 indicates data, 1 indicates control.
   //-------------------------------------------------------------------------------
   rule generateLaneInfo(tx_ready_wire);
      Vector#(8, Bit#(8)) txd;
      Vector#(8, Bit#(1)) txc;
      Bit#(8) lane_data;
      Bit#(8) lane_control;
      Bit#(8) lane_idle;
      Bit#(8) lane_terminate;
      Bit#(8) lane_res0;
      Bit#(8) lane_res1;
      Bit#(8) lane_res2;
      Bit#(8) lane_res3;
      Bit#(8) lane_res4;
      Bit#(8) lane_res5;
      Bit#(8) lane_start;
      Bit#(8) lane_error;
      Bit#(8) lane_seq;
      Bit#(8) lane_seqr;
      Bit#(64) xgmii_txd;
      Bit#(8)  xgmii_txc;

      let v <- toGet(fifo_in).get;
      for (Integer i=0; i<8; i=i+1) begin
         txd[i] = v[9*i+7 : 9*i];
         txc[i] = v[9*i+8];
      end

      xgmii_txd = pack(txd);
      xgmii_txc = pack(txc);


      for (Integer i=0; i<8; i=i+1) begin
         lane_data[i] = ~txc[i];
         lane_control[i] = txc[i];
         lane_idle[i] = ~(txd[i][7]) & ~(txd[i][6]) & ~(txd[i][5]) & ~(txd[i][4]) &
                         ~(txd[i][3]) & txd[i][2] & txd[i][1] & txd[i][0] & txc[i][0];
         lane_start[i] = txd[i][7] & txd[i][6] & txd[i][5] & txd[i][4] &
                          txd[i][3] & ~(txd[i][2]) & txd[i][1] & txd[i][0] & txc[i][0];
         // Terminate = 0xFD
         lane_terminate[i] = txd[i][7] & txd[i][6] & txd[i][5] & txd[i][4] &
                              txd[i][3] & txd[i][2] & ~(txd[i][1]) & txd[i][0] & txc[i][0];
         // Error = 0xFE
         lane_error[i] = txd[i][7] & txd[i][6] & txd[i][5] & txd[i][4] &
                          txd[i][3] & txd[i][2] & txd[i][1] & ~(txd[i][0]) & txc[i][0];
         // Sequence = 0x9C
         lane_seq[i] = txd[i][7] & ~(txd[i][6]) & ~(txd[i][5]) & txd[i][4] &
                        txd[i][3] & txd[i][2] & ~(txd[i][1]) & ~(txd[i][0]) & txc[i][0];
         // Reserved 0
         lane_res0[i] = ~(txd[i][7]) & ~(txd[i][6]) & ~(txd[i][5]) & txd[i][4] &
                           txd[i][3] & txd[i][2] & ~(txd[i][1]) & ~(txd[i][0]) & txc[i][0];
         // Reserved 1
         lane_res1[i] = ~(txd[i][7]) & ~(txd[i][6]) & txd[i][5] & txd[i][4] &
                           txd[i][3] & txd[i][2] & ~(txd[i][1]) & ~(txd[i][0]) & txc[i][0];
         // Reserved 2
         lane_res2[i] = ~(txd[i][7]) & txd[i][6] & txd[i][5] & txd[i][4] &
                           txd[i][3] & txd[i][2] & ~(txd[i][1]) & ~(txd[i][0]) & txc[i][0];
         // Reserved 3
         lane_res3[i] = txd[i][7] & ~(txd[i][6]) & txd[i][5] & txd[i][4] &
                         txd[i][3] & txd[i][2] & ~(txd[i][1]) & ~(txd[i][0]) & txc[i][0];
         // Reserved 4
         lane_res4[i] = txd[i][7] & txd[i][6] & ~(txd[i][5]) & txd[i][4] &
                         txd[i][3] & txd[i][2] & ~(txd[i][1]) & ~(txd[i][0]) & txc[i][0];
         // Reserved 5
         lane_res5[i] = txd[i][7] & txd[i][6] & txd[i][5] & txd[i][4] &
                       ~(txd[i][3]) & txd[i][2] & txd[i][1] & txd[i][0] & txc[i][0];
         // Reserved Ordered Set
         lane_seqr[i] = ~(txd[i][7]) & txd[i][6] & ~(txd[i][5]) & txd[i][4] &
                           txd[i][3] & txd[i][2] & ~(txd[i][1]) & ~(txd[i][0]) & txc[i][0];
      end

      laneInfoFifo.enq(LaneInfo{laneData      : lane_data,
                                laneControl   : lane_control,
                                laneIdle      : lane_idle,
                                laneTerminate : lane_terminate,
                                laneRes0      : lane_res0,
                                laneRes1      : lane_res1,
                                laneRes2      : lane_res2,
                                laneRes3      : lane_res3,
                                laneRes4      : lane_res4,
                                laneRes5      : lane_res5,
                                laneStart     : lane_start,
                                laneError     : lane_error,
                                laneSeq       : lane_seq,
                                laneSeqr      : lane_seqr,
                                xgmiiTxd      : xgmii_txd,
                                xgmiiTxc      : xgmii_txc});
//      laneDataFifo.enq(lane_data);
//      laneControlFifo.enq(lane_control);
//      laneIdleFifo.enq(lane_idle);
//      laneTerminateFifo.enq(lane_terminate);
//      laneRes0Fifo.enq(lane_res0);
//      laneRes1Fifo.enq(lane_res1);
//      laneRes2Fifo.enq(lane_res2);
//      laneRes3Fifo.enq(lane_res3);
//      laneRes4Fifo.enq(lane_res4);
//      laneRes5Fifo.enq(lane_res5);
//      laneStartFifo.enq(lane_start);
//      laneErrorFifo.enq(lane_error);
//      laneSeqFifo.enq(lane_seq);
//      laneSeqrFifo.enq(lane_seqr);
//
//      xgmiiTxdFifo1.enq(xgmii_txd);
//      xgmiiTxcFifo1.enq(xgmii_txc);
      if(verbose) $display("%d: encoder%d xgmii_txd=%h, txc=%h", cycle, id, xgmii_txd, xgmii_txc);
      if(verbose) $display("%d: encoder%d lane_data = %h", cycle, id, lane_data);
      if(verbose) $display("%d: encoder%d lane_control = %h", cycle, id, lane_control);
      if(verbose) $display("%d: encoder%d lane_seq = %h", cycle, id, lane_seq);
      if(verbose) $display("%d: encoder%d lane_idle = %h", cycle, id, lane_idle);
   endrule

   //-------------------------------------------------------------------------------
   // Decode the TXC input to decide on the value of the type field that is appended
   // to the data stream. This is only present for double words that contain
   // one or more control characters.
   //-------------------------------------------------------------------------------
   rule stage2_type_field;
      Bit#(1) type_1e;
      Bit#(1) type_2d;
      Bit#(1) type_33;
      Bit#(1) type_66;
      Bit#(1) type_55;
      Bit#(1) type_78;
      Bit#(1) type_4b;
      Bit#(1) type_87;
      Bit#(1) type_99;
      Bit#(1) type_aa;
      Bit#(1) type_b4;
      Bit#(1) type_cc;
      Bit#(1) type_d2;
      Bit#(1) type_e1;
      Bit#(1) type_ff;
      Bit#(1) type_illegal;
      Bit#(1) type_data;
      Bit#(4) o_code0;
      Bit#(4) o_code4;
      Bit#(17) type_reg;
      Vector#(8, Bit#(7)) lane_code;

      let lane_info <- toGet(laneInfoFifo).get();
      let lane_data      =  lane_info.laneData;
      let lane_control   =  lane_info.laneControl;
      let lane_idle      =  lane_info.laneIdle;
      let lane_terminate =  lane_info.laneTerminate;
      let lane_res0      =  lane_info.laneRes0;
      let lane_res1      =  lane_info.laneRes1;
      let lane_res2      =  lane_info.laneRes2;
      let lane_res3      =  lane_info.laneRes3;
      let lane_res4      =  lane_info.laneRes4;
      let lane_res5      =  lane_info.laneRes5;
      let lane_start     =  lane_info.laneStart;
      let lane_error     =  lane_info.laneError;
      let lane_seq       =  lane_info.laneSeq;
      let lane_seqr      =  lane_info.laneSeqr;
      let xgmii_txd      =  lane_info.xgmiiTxd;
      let xgmii_txc      =  lane_info.xgmiiTxc;

//      let lane_data    <- toGet(laneDataFifo).get();
//      let lane_control <- toGet(laneControlFifo).get();
//      let lane_idle    <- toGet(laneIdleFifo).get();
//      let lane_terminate <- toGet(laneTerminateFifo).get();
//      let lane_res0    <- toGet(laneRes0Fifo).get();
//      let lane_res1    <- toGet(laneRes1Fifo).get();
//      let lane_res2    <- toGet(laneRes2Fifo).get();
//      let lane_res3    <- toGet(laneRes3Fifo).get();
//      let lane_res4    <- toGet(laneRes4Fifo).get();
//      let lane_res5    <- toGet(laneRes5Fifo).get();
//      let lane_start   <- toGet(laneStartFifo).get();
//      let lane_error   <- toGet(laneErrorFifo).get();
//      let lane_seq     <- toGet(laneSeqFifo).get();
//      let lane_seqr    <- toGet(laneSeqrFifo).get();
//
//      let xgmii_txd <- toGet(xgmiiTxdFifo1).get();
//      let xgmii_txc <- toGet(xgmiiTxcFifo1).get();

      // All the data is control characters (usually idles) :-
      type_1e = lane_control[0] & ~(lane_terminate[0]) & ~(lane_error[0]) & lane_control[1] & lane_control[2] & lane_control[3] & lane_control[4] & lane_control[5] & lane_control[6] & lane_control[7] ;
      // The input contains control codes upto lane 3 but an ordered set from lane 4 onwards :-
      type_2d = lane_control[0] & lane_control[1] & lane_control[2] & lane_control[3] & lane_seq[4] & lane_data[5] & lane_data[6] & lane_data[7] ;
      // The input contains a start of packet in lane 4 :-
      type_33 = lane_control[0] & lane_control[1] & lane_control[2] & lane_control[3] & lane_start[4] & lane_data[5] & lane_data[6] & lane_data[7] ;
      // The input contains an ordered set in lanes 0 to 3 and the start of a packet
      // in lanes 4 to 7 :-
      type_66 = lane_seq[0] & lane_data[1] & lane_data[2] & lane_data[3] & lane_start[4] & lane_data[5] & lane_data[6] & lane_data[7] ;
      // The input contains two ordered sets, one starting in lane 0 and the other in lane 4 :-
      type_55 = lane_seq[0] & lane_data[1] & lane_data[2] & lane_data[3] & lane_seq[4] & lane_data[5] & lane_data[6] & lane_data[7] ;
      // The input contains a start of packet in lane 0 :-
      type_78 = lane_start[0] & lane_data[1] & lane_data[2] & lane_data[3] & lane_data[4] & lane_data[5] & lane_data[6] & lane_data[7] ;
      // The input contains an ordered set starting in lane 0 and control characters
      // in lanes 4 to 7 :-
      type_4b = lane_seq[0] & lane_data[1] & lane_data[2] & lane_data[3] & lane_control[4] & lane_control[5] & lane_control[6] & lane_control[7] ;
      // The following types are used to code inputs that contain the end of the packet.
      // The end of packet delimiter (terminate) can occur in any lane. There is a
      // type field associated with each position.
      //
      // Terminate in lane 0 :-
      type_87 = lane_terminate[0] & lane_control[1] & lane_control[2] & lane_control[3] & lane_control[4] & lane_control[5] & lane_control[6] & lane_control[7] ;
      // Terminate in lane 1 :-
      type_99 = lane_data[0] & lane_terminate[1] & lane_control[2] & lane_control[3] & lane_control[4] & lane_control[5] & lane_control[6] & lane_control[7] ;
      // Terminate in lane 2 :-
      type_aa = lane_data[0] & lane_data[1] & lane_terminate[2] & lane_control[3] & lane_control[4] & lane_control[5] & lane_control[6] & lane_control[7] ;
      // Terminate in lane 3 :-
      type_b4 = lane_data[0] & lane_data[1] & lane_data[2] & lane_terminate[3] & lane_control[4] & lane_control[5] & lane_control[6] & lane_control[7] ;
      // Terminate in lane 4 :-
      type_cc = lane_data[0] & lane_data[1] & lane_data[2] & lane_data[3] & lane_terminate[4] & lane_control[5] & lane_control[6] & lane_control[7] ;
      // Terminate in lane 5 :-
      type_d2 = lane_data[0] & lane_data[1] & lane_data[2] & lane_data[3] & lane_data[4] & lane_terminate[5] & lane_control[6] & lane_control[7] ;
      // Terminate in lane 6 :-
      type_e1 = lane_data[0] & lane_data[1] & lane_data[2] & lane_data[3] & lane_data[4] & lane_data[5] & lane_terminate[6] & lane_control[7] ;
      // Terminate in lane 7 :-
      type_ff = lane_data[0] & lane_data[1] & lane_data[2] & lane_data[3] & lane_data[4] & lane_data[5] & lane_data[6] & lane_terminate[7] ;
      // None of the above scenarios means that the data is in an illegal format.
      type_illegal = lane_control[0] | lane_control[1] | lane_control[2] | lane_control[3] | lane_control[4] | lane_control[5] | lane_control[6] | lane_control[7] ;
      type_data = lane_data[0] & lane_data[1] & lane_data[2] & lane_data[3] & lane_data[4] & lane_data[5] & lane_data[6] & lane_data[7] ;
      //-------------------------------------------------------------------------------
      // Translate these signals to give the actual type field output.
      // Prior to this the type signals above are registered as the delay through the
      // above equations could be considerable.
      //-------------------------------------------------------------------------------
      type_reg = {type_data, type_illegal, type_ff, type_e1, type_d2, type_cc, type_b4, type_aa, type_99, type_87, type_4b, type_78, type_55, type_66, type_33, type_2d, type_1e} ;

      //-------------------------------------------------------------------------------
      // Work out the ocode that is sent
      //-------------------------------------------------------------------------------
      if (lane_seqr[0] == 1) begin
         o_code0 = 4'b1111;
      end
      else begin
         o_code0 = 4'b0000;
      end

      if (lane_seqr[4] == 1) begin
         o_code4 = 4'b1111;
      end
      else begin
         o_code4 = 4'b0000;
      end

      // The idle and error control characters are mapped from their 8-bit xgmii
      // representation into a 7-bit output representation. Idle (0x07) maps to 0x00
      // and error (0xFE) maps to 0x1e. The other control characters are encoded
      // by the type field.
      for (Integer i=0; i<8; i=i+1) begin
         if (lane_idle[i] == 1'b1) begin
            lane_code[i] =  7'b0000000 ;
         end
         else if (lane_res0[i] == 1'b1) begin
            lane_code[i] =  7'b0101101 ;
         end
         else if (lane_res1[i] == 1'b1) begin
            lane_code[i] =  7'b0110011 ;
         end
         else if (lane_res2[i] == 1'b1) begin
            lane_code[i] =  7'b1001011 ;
         end
         else if (lane_res3[i] == 1'b1) begin
            lane_code[i] =  7'b1010101 ;
         end
         else if (lane_res4[i] == 1'b1) begin
            lane_code[i] =  7'b1100110 ;
         end
         else if (lane_res5[i] == 1'b1) begin
            lane_code[i] =  7'b1111000 ;
         end
         else begin
            lane_code[i] =  7'b0011110 ;
         end
      end

      typeInfoFifo.enq(TypeInfo{laneCode0 : lane_code[0],
                                laneCode1 : lane_code[1],
                                laneCode2 : lane_code[2],
                                laneCode3 : lane_code[3],
                                laneCode4 : lane_code[4],
                                laneCode5 : lane_code[5],
                                laneCode6 : lane_code[6],
                                laneCode7 : lane_code[7],
                                typeReg   : type_reg,
                                oCode0    : o_code0,
                                oCode4    : o_code4,
                                xgmiiTxd  : xgmii_txd,
                                xgmiiTxc  : xgmii_txc});
//      laneCodeFifo.enq(lane_code);
//      typeRegFifo.enq(type_reg);
//      oCode0Fifo.enq(o_code0);
//      oCode4Fifo.enq(o_code4);
//      xgmiiTxdFifo2.enq(xgmii_txd);
//      xgmiiTxcFifo2.enq(xgmii_txc);
   endrule

   rule stage3_generate_fields;
      Bit#(8)  type_field;
      Bit#(2)  sync_field;
      Bit#(56) data_field;
      Bit#(66) data_out;
      Vector#(8, Bit#(7)) lane_code;

      let typeinfo <- toGet(typeInfoFifo).get;
      let type_reg  = typeinfo.typeReg;
      let xgmii_txd = typeinfo.xgmiiTxd;
      let xgmii_txc = typeinfo.xgmiiTxc;
      let o_code0   = typeinfo.oCode0;
      let o_code4   = typeinfo.oCode4;
      lane_code[0] = typeinfo.laneCode0;
      lane_code[1] = typeinfo.laneCode1;
      lane_code[2] = typeinfo.laneCode2;
      lane_code[3] = typeinfo.laneCode3;
      lane_code[4] = typeinfo.laneCode4;
      lane_code[5] = typeinfo.laneCode5;
      lane_code[6] = typeinfo.laneCode6;
      lane_code[7] = typeinfo.laneCode7;

      debug_frames <= debug_frames + 1;
      if ((type_reg[0]) == 1'b1) begin
         type_field =  8'b00011110 ;
         debug_errorframes <= debug_errorframes + 1;
      end
      else if ((type_reg[1]) == 1'b1) begin
         type_field =  8'b00101101 ;
      end
      else if ((type_reg[2]) == 1'b1) begin
         type_field =  8'b00110011 ;
         debug_starts <= debug_starts + 1;
         debug_bytes <= debug_bytes + 3;
      end
      else if ((type_reg[3]) == 1'b1) begin
         type_field =  8'b01100110 ;
         debug_starts <= debug_starts + 1;
         debug_bytes <= debug_bytes + 3;
      end
      else if ((type_reg[4]) == 1'b1) begin
         type_field =  8'b01010101 ;
      end
      else if ((type_reg[5]) == 1'b1) begin
         type_field =  8'b01111000 ;
         debug_starts <= debug_starts + 1;
         debug_bytes <= debug_bytes + 7;
      end
      else if ((type_reg[6]) == 1'b1) begin
         type_field =  8'b01001011 ;
      end
      else if ((type_reg[7]) == 1'b1) begin
         type_field =  8'b10000111 ;
         debug_ends <= debug_ends + 1;
      end
      else if ((type_reg[8]) == 1'b1) begin
         type_field =  8'b10011001 ;
         debug_ends <= debug_ends + 1;
         debug_bytes <= debug_bytes + 1;
      end
      else if ((type_reg[9]) == 1'b1) begin
         type_field =  8'b10101010 ;
         debug_ends <= debug_ends + 1;
         debug_bytes <= debug_bytes + 2;
      end
      else if ((type_reg[10]) == 1'b1) begin
         type_field =  8'b10110100 ;
         debug_ends <= debug_ends + 1;
         debug_bytes <= debug_bytes + 3;
      end
      else if ((type_reg[11]) == 1'b1) begin
         type_field =  8'b11001100 ;
         debug_ends <= debug_ends + 1;
         debug_bytes <= debug_bytes + 4;
      end
      else if ((type_reg[12]) == 1'b1) begin
         type_field =  8'b11010010 ;
         debug_ends <= debug_ends + 1;
         debug_bytes <= debug_bytes + 5;
      end
      else if ((type_reg[13]) == 1'b1) begin
         type_field =  8'b11100001 ;
         debug_ends <= debug_ends + 1;
         debug_bytes <= debug_bytes + 6;
      end
      else if ((type_reg[14]) == 1'b1) begin
         type_field =  8'b11111111 ;
         debug_ends <= debug_ends + 1;
         debug_bytes <= debug_bytes + 7;
      end
      else if ((type_reg[15]) == 1'b1) begin
         type_field =  8'b00011110 ;
      end
      else begin
         type_field = xgmii_txd[7:0]; //FIXME
         debug_bytes <= debug_bytes + 8;
      end

      // Firstly the sync field. This is 01 for a data double and 10 for a double
      // containing a control character.
      if (type_reg == 17'b10000000000000000) begin
         sync_field = 2'b10 ;
      end
      else begin
         sync_field = 2'b01 ;
      end

      //-------------------------------------------------------------------------------
      // Rest of the data output depends on the type_field :-
      //-------------------------------------------------------------------------------
      if ((type_reg[0]) == 1'b1) begin
         // type 0x1e
         data_field = {lane_code[7], lane_code[6], lane_code[5], lane_code[4], lane_code[3], lane_code[2], lane_code[1], lane_code[0]} ;
      end
      else if ((type_reg[1]) == 1'b1) begin
         // type 0x2d
         data_field =  {xgmii_txd[63:40], o_code4, lane_code[3], lane_code[2], lane_code[1], lane_code[0]} ;
      end
      else if ((type_reg[2]) == 1'b1) begin
         // type 0x33
         data_field =  {xgmii_txd[63:40], 4'b0000, lane_code[3], lane_code[2], lane_code[1], lane_code[0]} ;
      end
      else if ((type_reg[3]) == 1'b1) begin
         // type 0x66
         data_field =  {xgmii_txd[63:40], 4'b0000, o_code0, xgmii_txd[31:8]} ;
      end
      else if ((type_reg[4]) == 1'b1) begin
         // type 0x55
         data_field =  {xgmii_txd[63:40], o_code4, o_code0, xgmii_txd[31:8]} ;
      end
      else if ((type_reg[5]) == 1'b1) begin
         // type 0x78
         data_field =  xgmii_txd[63:8] ;
      end
      else if ((type_reg[6]) == 1'b1) begin
         // type 0x4b
         data_field = {lane_code[7], lane_code[6], lane_code[5], lane_code[4], o_code0, xgmii_txd[31:8]} ;
      end
      else if ((type_reg[7]) == 1'b1) begin
         // type 0x87
         data_field =  {lane_code[7], lane_code[6], lane_code[5], lane_code[4], lane_code[3], lane_code[2], lane_code[1], 7'b0000000} ;
      end
      else if ((type_reg[8]) == 1'b1) begin
         // type 0x99
         data_field =  {lane_code[7], lane_code[6], lane_code[5], lane_code[4], lane_code[3], lane_code[2], 6'b000000, xgmii_txd[7:0]} ;
      end
      else if ((type_reg[9]) == 1'b1) begin
         // type 0xaa
         data_field =  {lane_code[7], lane_code[6], lane_code[5], lane_code[4], lane_code[3], 5'b00000, xgmii_txd[15:0]} ;
      end
      else if ((type_reg[10]) == 1'b1) begin
         // type 0xb4
         data_field =  {lane_code[7], lane_code[6], lane_code[5], lane_code[4], 4'b0000, xgmii_txd[23:0]} ;
      end
      else if ((type_reg[11]) == 1'b1) begin
         // type 0xcc
         data_field =  {lane_code[7], lane_code[6], lane_code[5], 3'b000, xgmii_txd[31:0]} ;
      end
      else if ((type_reg[12]) == 1'b1) begin
         // type 0xd2
         data_field =  {lane_code[7], lane_code[6], 2'b00, xgmii_txd[39:0]} ;
      end
      else if ((type_reg[13]) == 1'b1) begin
         // type 0xe1
         data_field =  {lane_code[7], 1'b0, xgmii_txd[47:0]} ;
      end
      else if ((type_reg[14]) == 1'b1) begin
         // type 0xff
         data_field =  xgmii_txd[55:0] ;
      end
      else if ((type_reg[15]) == 1'b1) begin
         // The data has a control character in it but it
         // doesn\'t conform to one of the above formats.
         data_field =  {lane_code[7], lane_code[6], lane_code[5], lane_code[4], lane_code[3], lane_code[2], lane_code[1], lane_code[0]} ;
      end
      else begin
         // If the input doesn\'t contain a control character then the data
         // is set to be the rest of the data.
         data_field =  xgmii_txd[63:8] ;
      end

      data_out = {data_field, type_field, sync_field};
      if(verbose) $display("%d: encoder%d data=%h type=%h sync=%h", cycle, id, data_field, type_field, sync_field);
      if(verbose) $display("%d encoder%d debug_bytes %d", cycle, id, debug_bytes);
      if(verbose) $display("%d encoder%d debug_starts %d", cycle, id, debug_starts);
      fifo_out.enq(data_out);
   endrule

   method Action tx_ready(Bool v);
      tx_ready_wire <= v;
   endmethod
   interface encoderIn = toPipeIn(fifo_in);
   interface encoderOut = toPipeOut(fifo_out);
   method PcsDbgRec dbg;
      return PcsDbgRec{bytes:debug_bytes, starts:debug_starts, ends:debug_ends, errorframes:debug_errorframes, frames:debug_frames};
   endmethod
endmodule

endpackage
