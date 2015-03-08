
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

package Gearbox_66_40;

import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;

import Pipe::*;
import MemTypes::*;

typedef 33 N_STATE;

interface Gearbox_66_40;
   interface PipeOut#(Bit#(40)) gbOut;
endinterface

(* mutually_exclusive = "state0, state1, state2, state3, state4, state5, state6, state7, state8, state9, state10, state11, state12, state13, state14, state15, state16, state17, state18, state19, state20, state21, state22, state23, state24, state25, state26, state27, state28, state29, state30, state31, state32" *)
module mkGearbox66to40#(PipeOut#(Bit#(66)) gbIn) (Gearbox_66_40);

   let verbose = False;

   function Bit#(N_STATE) toState(Integer st);
      return 1 << st;
   endfunction

   FIFOF#(Bit#(66)) cf <- mkBypassFIFOF;
   Vector#(104, Reg#(Bit#(1))) stor      <- replicateM(mkReg(0));

   FIFOF#(Bit#(40)) fifo_out <- mkFIFOF;
   PipeOut#(Bit#(40)) pipe_out = toPipeOut(fifo_out);

   Reg#(Bit#(N_STATE)) state <- mkReg(toState(0));
   Reg#(Bit#(32)) cycle <- mkReg(0);

   function ActionValue#(Vector#(104, Bit#(1))) updateStor(Bit#(104) _stor, Bit#(66) din, Integer offset, Bool shift40) = actionvalue
      Vector#(104, Bit#(1)) _stor_next = unpack(0);

      if (shift40) begin
         _stor_next = unpack(zeroExtend(_stor[103:40]));
      end
      else begin
         for (Integer idx = 0; idx < offset; idx=idx+1) begin
            _stor_next[idx] = _stor[40+idx];
         end
         for (Integer idx = 0; idx < 66; idx=idx+1) begin
            _stor_next[offset+idx] = din[idx];
         end
      end
      //if(verbose) $display("%h %h", _stor, _stor_next);
      return _stor_next;
   endactionvalue;

   function Action updateState(Bit#(104) _stor) = action
      writeVReg(take(stor), unpack(_stor));
      if (fifo_out.notFull) begin //FIXME: may drop data if fifo_out is full.
         fifo_out.enq(pack(_stor[39:0]));
      end
      //if(verbose) $display("%h", _stor);
   endaction;

   rule cyc;
      cycle <= cycle + 1;
   endrule

   rule state0(state[0] == 1);
      let v <- toGet(gbIn).get;
      let sr <- updateStor(pack(readVReg(stor)), v, 0, False);
      updateState(pack(sr));
      state <= toState(1);
      if(verbose) $display("%d: state %h %h, %h", cycle, state, v, pack(sr));
   endrule

   rule state1(state[1] == 1);
      let v <- toGet(gbIn).get;
      let sr <- updateStor(pack(readVReg(stor)), v, 26, False);
      updateState(pack(sr));
      state <= toState(2);
      if(verbose) $display("%d: state %h %h, %h", cycle, state, v, pack(sr));
   endrule

   rule state2(state[2] == 1);
      let sr <- updateStor(pack(readVReg(stor)), 0, 0, True);
      updateState(pack(sr));
      state <= toState(3);
      if(verbose) $display("%d: state %h, %h", cycle, state, pack(sr));
   endrule

   rule state3(state[3] == 1);
      let v <- toGet(gbIn).get;
      let sr <- updateStor(pack(readVReg(stor)), v, 12, False);
      updateState(pack(sr));
      state <= toState(4);
      if(verbose) $display("%d: state %h %h, %h", cycle, state, v, pack(sr));
   endrule

   rule state4(state[4] == 1);
      let v <- toGet(gbIn).get;
      let sr <- updateStor(pack(readVReg(stor)), v, 38, False);
      updateState(pack(sr));
      state <= toState(5);
      if(verbose) $display("%d: state %h %h, %h", cycle, state, v, pack(sr));
   endrule

   rule state5(state[5] == 1);
      let sr <- updateStor(pack(readVReg(stor)), 0, 0, True);
      updateState(pack(sr));
      state <= toState(6);
      if(verbose) $display("%d: state %h, %h", cycle, state, pack(sr));
   endrule

   rule state6(state[6] == 1);
      let v <- toGet(gbIn).get;
      let sr <- updateStor(pack(readVReg(stor)), v, 24, False);
      updateState(pack(sr));
      state <= toState(7);
      if(verbose) $display("%d: state %h %h, %h", cycle, state, v, pack(sr));
   endrule

   rule state7(state[7] == 1);
      let sr <- updateStor(pack(readVReg(stor)), 0, 0, True);
      updateState(pack(sr));
      state <= toState(8);
      if(verbose) $display("%d: state %h, %h", cycle, state, pack(sr));
   endrule

   rule state8(state[8] == 1);
      let v <- toGet(gbIn).get;
      let sr <- updateStor(pack(readVReg(stor)), v, 10, False);
      updateState(pack(sr));
      state <= toState(9);
      if(verbose) $display("%d: state %h %h, %h", cycle, state, v, pack(sr));
   endrule

   rule state9(state[9] == 1);
      let v <- toGet(gbIn).get;
      let sr <- updateStor(pack(readVReg(stor)), v, 36, False);
      updateState(pack(sr));
      state <= toState(10);
      if(verbose) $display("%d: state %h %h, %h", cycle, state, v, pack(sr));
   endrule

   rule state10(state[10] == 1);
      let sr <- updateStor(pack(readVReg(stor)), 0, 0, True);
      updateState(pack(sr));
      state <= toState(11);
      if(verbose) $display("%d: state %h, %h", cycle, state, pack(sr));
   endrule

   rule state11(state[11] == 1);
      let v <- toGet(gbIn).get;
      let sr <- updateStor(pack(readVReg(stor)), v, 22, False);
      updateState(pack(sr));
      state <= toState(12);
      if(verbose) $display("%d: state %h %h, %h", cycle, state, v, pack(sr));
   endrule

   rule state12(state[12] == 1);
      let sr <- updateStor(pack(readVReg(stor)), 0, 0, True);
      updateState(pack(sr));
      state <= toState(13);
      if(verbose) $display("%d: state %h, %h", cycle, state, pack(sr));
   endrule

   rule state13(state[13] == 1);
      let v <- toGet(gbIn).get;
      let sr <- updateStor(pack(readVReg(stor)), v, 8, False);
      updateState(pack(sr));
      state <= toState(14);
      if(verbose) $display("%d: state %h %h, %h", cycle, state, v, pack(sr));
   endrule

   rule state14(state[14] == 1);
      let v <- toGet(gbIn).get;
      let sr <- updateStor(pack(readVReg(stor)), v, 34, False);
      updateState(pack(sr));
      state <= toState(15);
      if(verbose) $display("%d: state %h %h, %h", cycle, state, v, pack(sr));
   endrule

   rule state15(state[15] == 1);
      let sr <- updateStor(pack(readVReg(stor)), 0, 0, True);
      updateState(pack(sr));
      state <= toState(16);
      if(verbose) $display("%d: state %h, %h", cycle, state, pack(sr));
   endrule

   rule state16(state[16] == 1);
      let v <- toGet(gbIn).get;
      let sr <- updateStor(pack(readVReg(stor)), v, 20, False);
      updateState(pack(sr));
      state <= toState(17);
      if(verbose) $display("%d: state %h %h, %h", cycle, state, v, pack(sr));
   endrule

   rule state17(state[17] == 1);
      let sr <- updateStor(pack(readVReg(stor)), 0, 0, True);
      updateState(pack(sr));
      state <= toState(18);
      if(verbose) $display("%d: state %h, %h", cycle, state, pack(sr));
   endrule

   rule state18(state[18] == 1);
      let v <- toGet(gbIn).get;
      let sr <- updateStor(pack(readVReg(stor)), v, 16, False);
      updateState(pack(sr));
      state <= toState(19);
      if(verbose) $display("%d: state %h %h, %h", cycle, state, v, pack(sr));
   endrule

   rule state19(state[19] == 1);
      let v <- toGet(gbIn).get;
      let sr <- updateStor(pack(readVReg(stor)), v, 32, False);
      updateState(pack(sr));
      state <= toState(20);
      if(verbose) $display("%d: state %h %h, %h", cycle, state, v, pack(sr));
   endrule

   rule state20(state[20] == 1);
      let sr <- updateStor(pack(readVReg(stor)), 0, 0, True);
      updateState(pack(sr));
      state <= toState(21);
      if(verbose) $display("%d: state %h, %h", cycle, state, pack(sr));
   endrule

   rule state21(state[21] == 1);
      let v <- toGet(gbIn).get;
      let sr <- updateStor(pack(readVReg(stor)), v, 18, False);
      updateState(pack(sr));
      state <= toState(22);
      if(verbose) $display("%d: state %h %h, %h", cycle, state, v, pack(sr));
   endrule

   rule state22(state[22] == 1);
      let sr <- updateStor(pack(readVReg(stor)), 0, 0, True);
      updateState(pack(sr));
      state <= toState(23);
      if(verbose) $display("%d: state %h, %h", cycle, state, pack(sr));
   endrule

   rule state23(state[23] == 1);
      let v <- toGet(gbIn).get;
      let sr <- updateStor(pack(readVReg(stor)), v, 4, False);
      updateState(pack(sr));
      state <= toState(24);
      if(verbose) $display("%d: state %h %h, %h", cycle, state, v, pack(sr));
   endrule

   rule state24(state[24] == 1);
      let v <- toGet(gbIn).get;
      let sr <- updateStor(pack(readVReg(stor)), v, 30, False);
      updateState(pack(sr));
      state <= toState(25);
      if(verbose) $display("%d: state %h %h, %h", cycle, state, v, pack(sr));
   endrule

   rule state25(state[25] == 1);
      let sr <- updateStor(pack(readVReg(stor)), 0, 0, True);
      updateState(pack(sr));
      state <= toState(26);
      if(verbose) $display("%d: state %h, %h", cycle, state, pack(sr));
   endrule

   rule state26(state[26] == 1);
      let v <- toGet(gbIn).get;
      let sr <- updateStor(pack(readVReg(stor)), v, 16, False);
      updateState(pack(sr));
      state <= toState(27);
      if(verbose) $display("%d: state %h %h, %h", cycle, state, v, pack(sr));
   endrule

   rule state27(state[27] == 1);
      let sr <- updateStor(pack(readVReg(stor)), 0, 0, True);
      updateState(pack(sr));
      state <= toState(28);
      if(verbose) $display("%d: state %h, %h", cycle, state, pack(sr));
   endrule

   rule state28(state[28] == 1);
      let v <- toGet(gbIn).get;
      let sr <- updateStor(pack(readVReg(stor)), v, 2, False);
      updateState(pack(sr));
      state <= toState(29);
      if(verbose) $display("%d: state %h %h, %h", cycle, state, v, pack(sr));
   endrule

   rule state29(state[29] == 1);
      let v <- toGet(gbIn).get;
      let sr <- updateStor(pack(readVReg(stor)), v, 28, False);
      updateState(pack(sr));
      state <= toState(30);
      if(verbose) $display("%d: state %h %h, %h", cycle, state, v, pack(sr));
   endrule

   rule state30(state[30] == 1);
      let sr <- updateStor(pack(readVReg(stor)), 0, 0, True);
      updateState(pack(sr));
      state <= toState(31);
      if(verbose) $display("%d: state %h, %h", cycle, state, pack(sr));
   endrule

   rule state31(state[31] == 1);
      let v <- toGet(gbIn).get;
      let sr <- updateStor(pack(readVReg(stor)), v, 14, False);
      updateState(pack(sr));
      state <= toState(32);
      if(verbose) $display("%d: state %h %h, %h", cycle, state, v, pack(sr));
   endrule

   rule state32(state[32] == 1);
      let sr <- updateStor(pack(readVReg(stor)), 0, 0, True);
      updateState(pack(sr));
      state <= toState(0);
      if(verbose) $display("%d: state %h, %h", cycle, state, pack(sr));
   endrule

   interface gbOut = pipe_out;
endmodule
endpackage

//Reference: 
//always @(posedge clk) begin
//	din_r <= din[65:0];
//	
//	gbstate <= (sclr | gbstate[5]) ? 6'h0 : (gbstate + 1'b1);
//	   
//	if (gbstate[5]) begin 
//		stor <= {40'h0,stor[103:40]};    // holding 0	
//	end    
//	else begin	
//		case (gbstate[4:0])
//			5'h0 : begin stor[65:0] <= din[65:0];  end   // holding 26
//			5'h1 : begin stor[91:26] <= din[65:0]; stor[25:0] <= stor[65:40];   end   // holding 52
//			5'h2 : begin stor <= {40'h0,stor[103:40]};  end   // holding 12
//			5'h3 : begin stor[77:12] <= din[65:0]; stor[11:0] <= stor[51:40];   end   // holding 38
//			5'h4 : begin stor[103:38] <= din[65:0]; stor[37:0] <= stor[77:40];   end   // holding 64
//			5'h5 : begin stor <= {40'h0,stor[103:40]};  end   // holding 24
//			5'h6 : begin stor[89:24] <= din[65:0]; stor[23:0] <= stor[63:40];   end   // holding 50
//			5'h7 : begin stor <= {40'h0,stor[103:40]};  end   // holding 10
//			5'h8 : begin stor[75:10] <= din[65:0]; stor[9:0] <= stor[49:40];   end   // holding 36
//			5'h9 : begin stor[101:36] <= din[65:0]; stor[35:0] <= stor[75:40];   end   // holding 62
//			5'ha : begin stor <= {40'h0,stor[103:40]};  end   // holding 22
//			5'hb : begin stor[87:22] <= din[65:0]; stor[21:0] <= stor[61:40];   end   // holding 48
//			5'hc : begin stor <= {40'h0,stor[103:40]};  end   // holding 8
//			5'hd : begin stor[73:8] <= din[65:0]; stor[7:0] <= stor[47:40];   end   // holding 34
//			5'he : begin stor[99:34] <= din[65:0]; stor[33:0] <= stor[73:40];   end   // holding 60
//			5'hf : begin stor <= {40'h0,stor[103:40]};  end   // holding 20
//			5'h10 : begin stor[85:20] <= din[65:0]; stor[19:0] <= stor[59:40];   end   // holding 46
//			5'h11 : begin stor <= {40'h0,stor[103:40]};  end   // holding 6
//			5'h12 : begin stor[71:6] <= din[65:0]; stor[5:0] <= stor[45:40];   end   // holding 32
//			5'h13 : begin stor[97:32] <= din[65:0]; stor[31:0] <= stor[71:40];   end   // holding 58
//			5'h14 : begin stor <= {40'h0,stor[103:40]};  end   // holding 18
//			5'h15 : begin stor[83:18] <= din[65:0]; stor[17:0] <= stor[57:40];   end   // holding 44
//			5'h16 : begin stor <= {40'h0,stor[103:40]};  end   // holding 4
//			5'h17 : begin stor[69:4] <= din[65:0]; stor[3:0] <= stor[43:40];   end   // holding 30
//			5'h18 : begin stor[95:30] <= din[65:0]; stor[29:0] <= stor[69:40];   end   // holding 56
//			5'h19 : begin stor <= {40'h0,stor[103:40]};  end   // holding 16
//			5'h1a : begin stor[81:16] <= din[65:0]; stor[15:0] <= stor[55:40];   end   // holding 42
//			5'h1b : begin stor <= {40'h0,stor[103:40]};  end   // holding 2
//			5'h1c : begin stor[67:2] <= din[65:0]; stor[1:0] <= stor[41:40];   end   // holding 28
//			5'h1d : begin stor[93:28] <= din[65:0]; stor[27:0] <= stor[67:40];   end   // holding 54
//			5'h1e : begin stor <= {40'h0,stor[103:40]};  end   // holding 14
//			5'h1f : begin stor[79:14] <= din[65:0]; stor[13:0] <= stor[53:40];   end   // holding 40
//		endcase
//	end
//end
//
//
