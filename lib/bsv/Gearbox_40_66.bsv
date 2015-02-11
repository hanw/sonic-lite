
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

package Gearbox_40_66;

import FIFO::*;
import FIFOF::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;

import Pipe::*;
import MemTypes::*;

typedef 33 N_STATE;

interface Gearbox_40_66;
   interface PipeOut#(Bit#(66)) gbOut;
endinterface

(* mutually_exclusive = "state0, state1, state2, state3, state4, state5, state6, state7, state8, state9, state10, state11, state12, state13, state14, state15, state16, state17, state18, state19, state20, state21, state22, state23, state24, state25, state26, state27, state28, state29, state30, state31, state32" *)
module mkGearbox40to66#(PipeOut#(Bit#(40)) pmaOut) (Gearbox_40_66);

   let verbose = False;

   function Bit#(N_STATE) toState(Integer st);
      return 1 << st;
   endfunction

   FIFOF#(Bit#(40)) cf <- mkSizedFIFOF(1);
   Vector#(66, Reg#(Bit#(1))) sr0        <- replicateM(mkReg(0));
   Vector#(66, Reg#(Bit#(1))) sr1        <- replicateM(mkReg(0));

   FIFOF#(Bit#(66)) fifo_out <- mkFIFOF;
   PipeOut#(Bit#(66)) pipe_out = toPipeOut(fifo_out);

   Reg#(Bit#(N_STATE)) state <- mkReg(toState(0));

   function ActionValue#(Vector#(66, Bit#(1))) updateSR1(Bit#(66) reg0, Bit#(66) reg1, Bit#(40) din, Integer offset, Integer len, Bool use0) = actionvalue
      Vector#(66, Bit#(1)) sr = unpack(0);

      if (use0) begin
         sr = unpack(reg0);
      end
      else begin
         sr = unpack(reg1);
      end

      for (Integer idx = offset; idx < offset + len; idx = idx+1) begin
         sr[idx] = din[idx - offset];
      end
      if (verbose) $display("SR1: %h, %h, %h, %h", sr, din, offset, len);
      return sr;
   endactionvalue;

   function ActionValue#(Vector#(66, Bit#(1))) updateSR0(Bit#(40) din, Integer len, Bool update) = actionvalue
      Vector#(66, Bit#(1)) sr = unpack(0);

      if (update) begin
         for (Integer idx = 0; idx < len; idx = idx + 1) begin
            Integer d_start = 40 - len;
            sr[idx] = din[d_start + idx];
         end
      end
      if (verbose) $display("SR0: %h, %h, %h", sr, din, len);
      return sr;
   endactionvalue;

   function ActionValue#(Vector#(66, Bit#(1))) updateSR(Bit#(66) sr0_packed, Bit#(66) sr1_packed, Bit#(40) din, Integer offset, Integer len, Bool use0, Bool update) = actionvalue
      let sr1_next <- updateSR1(sr0_packed, sr1_packed, din, offset, len, use0);
      writeVReg(take(sr1), sr1_next);
      let sr0_next <- updateSR0(din, 40-len, update);
      writeVReg(take(sr0), sr0_next);
      return sr1_next;
   endactionvalue;

   rule state0 (state[0] == 1 && cf.notEmpty);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 0, 40, False, False);
      state <= toState(1);
      if (verbose) $display("state %h: %h", state, pack(sr));
   endrule
   rule state1 (state[1] == 1 && cf.notEmpty);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 40, 26, False, True);
      fifo_out.enq(pack(sr));
      state <= toState(2);
      if (verbose) $display("state %h: %h", state, pack(sr));
   endrule
   rule state2 (state[2] == 1 && cf.notEmpty);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 14, 40, True, False);
      state <= toState(3);
      if (verbose) $display("state %h: %h", state, pack(sr));
   endrule
   rule state3 (state[3] == 1 && cf.notEmpty);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 54, 12, False, True);
      fifo_out.enq(pack(sr));
      state <= toState(4);
      if (verbose) $display("state %h: %h", state, pack(sr));
   endrule
   rule state4 (state[4] == 1 && cf.notEmpty);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 28, 38, True, True);
      fifo_out.enq(pack(sr));
      state <= toState(5);
      if (verbose) $display("state %h: %h", state, pack(sr));
   endrule
   rule state5 (state[5] == 1 && cf.notEmpty);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 2, 40, True, False);
      state <= toState(6);
      if (verbose) $display("state %h: %h", state, pack(sr));
   endrule
   rule state6 (state[6] == 1);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 42, 24, False, True);
      fifo_out.enq(pack(sr));
      state <= toState(7);
      if (verbose) $display("state %h: %h, %h", state, readVReg(sr0), readVReg(sr1));
   endrule
   rule state7 (state[7] == 1);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 16, 40, True, False);
      state <= toState(8);
      if (verbose) $display("state %h: %h, %h", state, readVReg(sr0), readVReg(sr1));
   endrule
   rule state8 (state[8] == 1);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 56, 10, False, True);
      fifo_out.enq(pack(sr));
      state <= toState(9);
      if (verbose) $display("state %h: %h, %h", state, readVReg(sr0), readVReg(sr1));
   endrule
   rule state9 (state[9] == 1);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 30, 36, True, True);
      fifo_out.enq(pack(sr));
      state <= toState(10);
      if (verbose) $display("state %h: %h, %h", state, readVReg(sr0), readVReg(sr1));
   endrule
   rule state10 (state[10] == 1);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 4, 40, True, False);
      state <= toState(11);
      if (verbose) $display("state %h: %h, %h", state, readVReg(sr0), readVReg(sr1));
   endrule
   rule state11 (state[11] == 1);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 44, 22, False, True);
      fifo_out.enq(pack(sr));
      state <= toState(12);
      if (verbose) $display("state %h: %h, %h", state, readVReg(sr0), readVReg(sr1));
   endrule
   rule state12 (state[12] == 1);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 18, 40, True, False);
      state <= toState(13);
      if (verbose) $display("state %h: %h, %h", state, readVReg(sr0), readVReg(sr1));
   endrule
   rule state13 (state[13] == 1);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 58, 8, False, True);
      fifo_out.enq(pack(sr));
      state <= toState(14);
      if (verbose) $display("state %h: %h, %h", state, readVReg(sr0), readVReg(sr1));
   endrule
   rule state14 (state[14] == 1);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 32, 34, False, True);
      fifo_out.enq(pack(sr));
      state <= toState(15);
      if (verbose) $display("state %h: %h, %h", state, readVReg(sr0), readVReg(sr1));
   endrule
   rule state15 (state[15] == 1);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 6, 40, True, False);
      state <= toState(16);
      if (verbose) $display("state %h: %h, %h", state, readVReg(sr0), readVReg(sr1));
   endrule
   rule state16 (state[16] == 1);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 46, 20, False, True);
      fifo_out.enq(pack(sr));
      state <= toState(17);
      if (verbose) $display("state %h: %h, %h", state, readVReg(sr0), readVReg(sr1));
   endrule
   rule state17 (state[17] == 1);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 20, 40, True, False);
      state <= toState(18);
      if (verbose) $display("state %h: %h, %h", state, readVReg(sr0), readVReg(sr1));
   endrule
   rule state18 (state[18] == 1);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 60, 6, False, True);
      fifo_out.enq(pack(sr));
      state <= toState(19);
      if (verbose) $display("state %h: %h, %h", state, readVReg(sr0), readVReg(sr1));
   endrule
   rule state19 (state[19] == 1);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 34, 32, True, True);
      fifo_out.enq(pack(sr));
      state <= toState(20);
      if (verbose) $display("state %h: %h, %h", state, readVReg(sr0), readVReg(sr1));
   endrule
   rule state20 (state[20] == 1);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 8, 40, True, False);
      state <= toState(21);
      if (verbose) $display("state %h: %h, %h", state, readVReg(sr0), readVReg(sr1));
   endrule
   rule state21 (state[21] == 1);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 48, 18, False, True);
      fifo_out.enq(pack(sr));
      state <= toState(22);
      if (verbose) $display("state %h: %h, %h", state, readVReg(sr0), readVReg(sr1));
   endrule
   rule state22 (state[22] == 1);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 22, 40, True, False);
      state <= toState(23);
      if (verbose) $display("state %h: %h, %h", state, readVReg(sr0), readVReg(sr1));
   endrule
   rule state23 (state[23] == 1);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 62, 4, False, True);
      fifo_out.enq(pack(sr));
      state <= toState(24);
      if (verbose) $display("state %h: %h, %h", state, readVReg(sr0), readVReg(sr1));
   endrule
   rule state24 (state[24] == 1);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 36, 30, True, True);
      fifo_out.enq(pack(sr));
      state <= toState(25);
      if (verbose) $display("state %h: %h, %h", state, readVReg(sr0), readVReg(sr1));
   endrule
   rule state25 (state[25] == 1);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 10, 40, True, False);
      state <= toState(26);
      if (verbose) $display("state %h: %h, %h", state, readVReg(sr0), readVReg(sr1));
   endrule
   rule state26 (state[26] == 1);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 50, 16, False, True);
      fifo_out.enq(pack(sr));
      state <= toState(27);
      if (verbose) $display("state %h: %h, %h", state, readVReg(sr0), readVReg(sr1));
   endrule
   rule state27 (state[27] == 1);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 24, 40, True, False);
      state <= toState(28);
      if (verbose) $display("state %h: %h, %h", state, readVReg(sr0), readVReg(sr1));
   endrule
   rule state28 (state[28] == 1);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 64, 2, False, True);
      fifo_out.enq(pack(sr));
      state <= toState(29);
      if (verbose) $display("state %h: %h, %h", state, readVReg(sr0), readVReg(sr1));
   endrule
   rule state29 (state[29] == 1);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 38, 28, True, True);
      fifo_out.enq(pack(sr));
      state <= toState(30);
      if (verbose) $display("state %h: %h, %h", state, readVReg(sr0), readVReg(sr1));
   endrule
   rule state30 (state[30] == 1);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 12, 40, True, False);
      state <= toState(31);
      if (verbose) $display("state %h: %h, %h", state, readVReg(sr0), readVReg(sr1));
   endrule
   rule state31 (state[31] == 1);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 52, 14, False, True);
      fifo_out.enq(pack(sr));
      state <= toState(32);
      if (verbose) $display("state %h: %h, %h", state, readVReg(sr0), readVReg(sr1));
   endrule
   rule state32 (state[32] == 1);
      let value = cf.first();
      cf.deq;
      let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, 26, 40, True, False);
      fifo_out.enq(pack(sr));
      state <= toState(0);
      if (verbose) $display("state %h: %h, %h", state, readVReg(sr0), readVReg(sr1));
   endrule

   rule pma_out;
      let v <- toGet(pmaOut).get;
      //if(verbose) $display("Rx Pma Out: %h", v);
      cf.enq(v);
   endrule

   interface gbOut = pipe_out;
endmodule

endpackage

//|State |     SR0 (66 bits)           |         SR1 (66 bits)         | Valid | Shift |
//    0    -----------------------------------------[39               0]    0       0
//    1    -------------------[13     0] [65     40][39               0]    1       1
//    2    -------------------------------------[53           14][13  0]    0       0
//    3    ----------------[27        0] [65:54][53           14][13  0]    1       1
//    4    ------------------------[1:0] [65          28][27          0]    1       1
//    5    ----------------------------------------[41           2][1:0]    0       0
//    6    ------------------[15      0] [65    42][41           2][1:0]    1       1
//    7    -------------------------------------[55          16][15   0]    0       0
//    8    -----------------[29       0] [65:56][55          16][15   0]    1       1
//    9    ------------------------[3:0] [65            30][29        0]    1       1
//   10    -------------------------------------[43          4][3     0]    0       0
//   11    --------------    [17      0] [65 44][43          4][3     0]    1       1
//   12    -------------------------------------[58       18][17      0]    0       0
//   13    ----------------[31        0] [65 58][57       18][17      0]    1       1
//   14    ----------------------- [5:0] [65            32][31        0]    1       1
//   15    --------------------------------------[45          6][5    0]    0       0
//   16    ------------------[19      0] [65  46][45          6][5    0]    1       1
//   17    -------------------------------------[59       20][19      0]    0       0
//   18    ----------------[33        0] [65  60][59      20][19      0]    1       1
//   19    ------------------------[7:0] [65        34][33            0]    1       1
//   20    -------------------------------------[47         8][7      0]    0       0
//   21    ------------------[21      0] [65   48][47       8][7      0]    1       1
//   22    ---------------------------------[61      22][21           0]    0       0
//   23    ------------[35            0] [65:62][61  22][21           0]    1       1
//   24    --------------------[9     0] [65      36][35              0]    1       1
//   25    -----------------------------------[49           10][9     0]    0       0
//   26    ------------------[23      0] [65   50][49       10][9     0]    1       1
//   27    ---------------------------------[63         24][23        0]    0       0
//   28    -----------[37             0] [65:64][63     24][23        0]    1       1
//   29    ---------------------[11   0] [65          38][37          0]    1       1
//   30    -----------------------------------[51         12][11      0]    0       0
//   31    ---------------[25         0] [65  52][51      12][11      0]    1       1
//   32    ------------------------------[65           26][25         0]    1       1

