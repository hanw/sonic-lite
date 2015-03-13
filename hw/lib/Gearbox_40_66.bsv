
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

interface Gearbox_40_66;
   interface PipeOut#(Bit#(66)) gbOut;
endinterface

module mkGearbox40to66#(PipeOut#(Bit#(40)) pmaOut) (Gearbox_40_66);

   let verbose = False;

   FIFOF#(Bit#(40)) cf <- mkSizedFIFOF(1);
   Vector#(66, Reg#(Bit#(1))) sr0        <- replicateM(mkReg(0));
   Vector#(66, Reg#(Bit#(1))) sr1        <- replicateM(mkReg(0));

   FIFOF#(Bit#(66)) fifo_out <- mkFIFOF;
   PipeOut#(Bit#(66)) pipe_out = toPipeOut(fifo_out);

   Reg#(Bit#(6)) state <- mkReg(0);
   Reg#(Int#(8)) sh_offset <- mkReg(0);
   Reg#(Int#(8)) sh_len <- mkReg(0);

   function ActionValue#(Vector#(66, Bit#(1))) updateSR1(Bit#(66) reg0, Bit#(66) reg1, Bit#(40) din, Int#(8) offset, Int#(8) len, Bool use0) = actionvalue
      Vector#(66, Bit#(1)) sr = unpack(0);

      if (use0) begin
         sr = unpack(reg0);
      end
      else begin
         sr = unpack(reg1);
      end

      for (Int#(8) idx = offset; idx < offset + len; idx = idx+1) begin
         sr[idx] = din[idx - offset];
      end
      if (verbose) $display("SR1: %h, %h, %h, %h", sr, din, offset, len);
      return sr;
   endactionvalue;

   function ActionValue#(Vector#(66, Bit#(1))) updateSR0(Bit#(40) din, Int#(8) len, Bool update) = actionvalue
      Vector#(66, Bit#(1)) sr = unpack(0);

      if (update) begin
         for (Int#(8) idx = 0; idx < len; idx = idx + 1) begin
            Int#(8) d_start = 40 - len;
            sr[idx] = din[d_start + idx];
         end
      end
      if (verbose) $display("SR0: %h, %h, %h", sr, din, len);
      return sr;
   endactionvalue;

   function ActionValue#(Vector#(66, Bit#(1))) updateSR(Bit#(66) sr0_packed, Bit#(66) sr1_packed, Bit#(40) din, Int#(8) offset, Int#(8) len, Bool use0, Bool update) = actionvalue
      let sr1_next <- updateSR1(sr0_packed, sr1_packed, din, offset, len, use0);
      writeVReg(take(sr1), sr1_next);
      let sr0_next <- updateSR0(din, 40-len, update);
      writeVReg(take(sr0), sr0_next);
      return sr1_next;
   endactionvalue;

   function ActionValue#(Bit#(66)) updateSR1Test(Bit#(40) din, Int#(8) offset, Int#(8) len, Bool use0) = actionvalue
      Vector#(66, Bit#(1)) sr = unpack(0);

      if (use0) begin
         sr = readVReg(sr0);
      end
      else begin
         sr = readVReg(sr1);
      end

      for (Int#(8) idx = offset; idx < offset + len; idx = idx+1) begin
         sr[idx] = din[idx - offset];
      end
      if (verbose) $display("SR1: %h, %h, %h, %h", sr, din, offset, len);
      return pack(sr);
   endactionvalue;

   function ActionValue#(Bit#(66)) updateSR0Test(Bit#(40) din, Int#(8) len, Bool update) = actionvalue
      Vector#(66, Bit#(1)) sr = unpack(0);

      if (update) begin
         for (Int#(8) idx = 0; idx < len; idx = idx + 1) begin
            Int#(8) d_start = 40 - len;
            sr[idx] = din[d_start + idx];
         end
      end
      if (verbose) $display("SR0: %h, %h, %h", sr, din, len);
      return pack(sr);
   endactionvalue;

   function Action updateTest(Bit#(40) din, Int#(8) offset, Int#(8) len, Bool use0, Bool update);
      return action
      Vector#(66, Bit#(1)) sr1_next = unpack(0);

      if (use0) begin
         sr1_next = readVReg(sr0);
      end
      else begin
         sr1_next = readVReg(sr1);
      end

      for (Int#(8) idx = offset; idx < offset + len; idx = idx+1) begin
         sr1_next[idx] = din[idx - offset];
      end
      writeVReg(take(sr1), sr1_next);

      Vector#(66, Bit#(1)) sr0_next = unpack(0);
      if (update) begin
         for (Int#(8) idx = 0; idx < len; idx = idx + 1) begin
            Int#(8) d_start = 40 - len;
            sr0_next[idx] = din[d_start + idx];
         end
      end
      writeVReg(take(sr0), sr0_next);
      endaction;
   endfunction
//   function Integer getOffset (Integer curr_state);
//      let offset;
//      case (curr_state)
//          0: offset = 0;   len = 40;  useSr0 = False; updateSr = False;
//          1: offset = 40;  len = 26;  useSr0 = False; updateSr = True;
//          2: offset = 14;  len = 40;  useSr0 = True;  updateSr = False;
//          3: offset = 54;  len = 12;  useSr0 = False; updateSr = False;
//          4: offset = 28;  len = 38;  useSr0 = True;  updateSr = True;
//          5: offset = 2;   len = 40;  useSr0 = True;  updateSr = False;
//          6: offset = 42;  len = 24;  useSr0 = False; updateSr = True;
//          7: offset = 16;  len = 40;  useSr0 = True;  updateSr = False;
//          8: offset = 56;  len = 10;  useSr0 = False; updateSr = True;
//          9: offset = 30;  len = 36;  useSr0 = True;  updateSr = True;
//         10: offset = 4;   len = 40;  useSr0 = True;  updateSr = False;
//         11: offset = 44;  len = 22;  useSr0 = False; updateSr = True;
//         12: offset = 18;  len = 40;  useSr0 = True;  updateSr = False;
//         13: offset = 58;  len = 8;   useSr0 = False; updateSr = True;
//         14: offset = 32;  len = 34;  useSr0 = False; updateSr = True;
//         15: offset = 6;   len = 40;  useSr0 = True;  updateSr = False;
//         16: offset = 46;  len = 20;  useSr0 = False; updateSr = True;
//         17: offset = 20;  len = 40;  useSr0 = True;  updateSr = False;
//         18: offset = 60;  len = 6;   useSr0 = False; updateSr = True;
//         19: offset = 34;  len = 32;  useSr0 = True;  updateSr = True;
//         20: offset = 8;   len = 40;  useSr0 = True;  updateSr = False;
//         21: offset = 48;  len = 18;  useSr0 = False; updateSr = True;
//         22: offset = 22;  len = 40;  useSr0 = True;  updateSr = False;
//         23: offset = 62;  len = 4;   useSr0 = False; updateSr = True;
//         24: offset = 36;  len = 30;  useSr0 = True;  updateSr = True;
//         25: offset = 10;  len = 40;  useSr0 = True;  updateSr = False;
//         26: offset = 50;  len = 16;  useSr0 = False; updateSr = True;
//         27: offset = 24;  len = 40;  useSr0 = True;  updateSr = False;
//         28: offset = 64;  len = 2;   useSr0 = False; updateSr = True;
//         29: offset = 38;  len = 28;  useSr0 = True;  updateSr = True;
//         30: offset = 12;  len = 40;  useSr0 = True;  updateSr = False;
//         31: offset = 52;  len = 14;  useSr0 = False; updateSr = True;
//         32: offset = 26;  len = 40;  useSr0 = True;  updateSr = False;
//         default: offset = 0;
//      endcase
//      return offset;
//   endfunction
//
//   function Integer getLen (Integer curr_state);
//      let len;
//      case (curr_state)
//          0: len = 40;
//          1: len = 26;
//          2: len = 40;
//          3: len = 12;
//          4: len = 38;
//          5: len = 40;
//          6: len = 24;
//          7: len = 40;
//          8: len = 10;
//          9: len = 36;
//         10: len = 40;
//         11: len = 22;
//         12: len = 40;
//         13: len = 8; 
//         14: len = 34;
//         15: len = 40;
//         16: len = 20;
//         17: len = 40;
//         18: len = 6; 
//         19: len = 32;
//         20: len = 40;
//         21: len = 18;
//         22: len = 40;
//         23: len = 4; 
//         24: len = 30;
//         25: len = 40;
//         26: len = 16;
//         27: len = 40;
//         28: len = 2; 
//         29: len = 28;
//         30: len = 40;
//         31: len = 14;
//         32: len = 40;
//         default: len = 0;
//      endcase
//      return len;
//   endfunction
//
//   function Bool getUseSr0 (Integer curr_state);
//      let useSr0;
//      case (curr_state)
//          0: useSr0 = False;
//          1: useSr0 = False;
//          2: useSr0 = True; 
//          3: useSr0 = False;
//          4: useSr0 = True; 
//          5: useSr0 = True; 
//          6: useSr0 = False;
//          7: useSr0 = True; 
//          8: useSr0 = False;
//          9: useSr0 = True; 
//         10: useSr0 = True; 
//         11: useSr0 = False;
//         12: useSr0 = True; 
//         13: useSr0 = False;
//         14: useSr0 = False;
//         15: useSr0 = True; 
//         16: useSr0 = False;
//         17: useSr0 = True; 
//         18: useSr0 = False;
//         19: useSr0 = True; 
//         20: useSr0 = True; 
//         21: useSr0 = False;
//         22: useSr0 = True; 
//         23: useSr0 = False;
//         24: useSr0 = True; 
//         25: useSr0 = True; 
//         26: useSr0 = False;
//         27: useSr0 = True; 
//         28: useSr0 = False;
//         29: useSr0 = True; 
//         30: useSr0 = True; 
//         31: useSr0 = False;
//         32: useSr0 = True; 
//         default: useSr0= False;
//      endcase
//      return useSr0;
//   endfunction
//
//   function Bool getUpdateSr (Integer curr_state);
//      let updateSr;
//      case (curr_state)
//          0: updateSr = False;
//          1: updateSr = True;
//          2: updateSr = False;
//          3: updateSr = False;
//          4: updateSr = True;
//          5: updateSr = False;
//          6: updateSr = True;
//          7: updateSr = False;
//          8: updateSr = True;
//          9: updateSr = True;
//         10: updateSr = False;
//         11: updateSr = True;
//         12: updateSr = False;
//         13: updateSr = True;
//         14: updateSr = True;
//         15: updateSr = False;
//         16: updateSr = True;
//         17: updateSr = False;
//         18: updateSr = True;
//         19: updateSr = True;
//         20: updateSr = False;
//         21: updateSr = True;
//         22: updateSr = False;
//         23: updateSr = True;
//         24: updateSr = True;
//         25: updateSr = False;
//         26: updateSr = True;
//         27: updateSr = False;
//         28: updateSr = True;
//         29: updateSr = True;
//         30: updateSr = False;
//         31: updateSr = True;
//         32: updateSr = False;
//         default: updateSr= False;
//      endcase
//      return updateSr;
//   endfunction
//
   rule state_machine (cf.notEmpty);
      let value = cf.first;
      cf.deq;
      let next_state = state;
      let offset = sh_offset;
      let len = sh_len;
      let useSr0 = False;
      let updateSr = False;

      case (state)
          32: next_state = 0;
          default: next_state = next_state + 1;
      endcase

      if (offset + 40 > 66) begin
         len = 66 - offset;
         useSr0 = True;
      end
      else begin
         len = 40;
         useSr0 = False;
      end

      offset = offset + 40;
      if (offset > 66) begin
         offset = offset - 66;
      end

      if (len + offset == 66) begin
         updateSr = True;
      end
      else begin
         updateSr = False;
      end

      state     <= next_state;
      sh_offset <= offset;
      sh_len    <= len;

      //let sr <- updateSR(pack(readVReg(sr0)), pack(readVReg(sr1)), value, offset, len, useSr0, updateSr);
      //updateTest(value, offset, len, useSr0, updateSr);

      Vector#(66, Bit#(1)) sr1_next = unpack(0);

      if (useSr0) begin
         sr1_next = readVReg(sr0);
      end
      else begin
         sr1_next = readVReg(sr1);
      end

      for (Int#(8) idx = offset; idx < offset + len; idx = idx+1) begin
         sr1_next[idx] = value[idx - offset];
      end
      writeVReg(take(sr1), sr1_next);
//
//      Vector#(66, Bit#(1)) sr0_next = unpack(0);
//      if (updateSr) begin
//         for (Int#(8) idx = 0; idx < len; idx = idx + 1) begin
//            Int#(8) d_start = 40 - len;
//            sr0_next[idx] = value[d_start + idx];
//         end
//      end
//      writeVReg(take(sr0), sr0_next);

      //if (verbose) $display("state %h: %h", state, pack(sr));
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

