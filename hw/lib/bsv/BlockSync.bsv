
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

package BlockSync;

import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;

import Pipe::*;

interface BlockSync;
   interface PipeIn#(Bit#(66)) blockSyncIn;
   interface PipeOut#(Bit#(66)) dataOut;
   (* always_ready, always_enabled *)
   method Action rx_ready(Bool v);
   method Bool lock();
endinterface

typedef enum {LOCK_INIT, RESET_CNT, TEST_SH, GOOD_64, SLIP} State
deriving (Bits, Eq);

(* synthesize *)
module mkBlockSync(BlockSync);

   let verbose = False;

   Reg#(Bit#(32)) cycle <- mkReg(0);
   Reg#(State) curr_state <- mkReg(LOCK_INIT);
   Reg#(Bool) block_lock  <- mkReg(False);
   Reg#(Bool) slip_done   <- mkReg(False);
   Reg#(Bit#(8)) sh_cnt  <- mkReg(0);
   Reg#(Bit#(8)) sh_invalid_cnt <- mkReg(0);

   Reg#(Bit#(66)) rx_b1   <- mkReg(0);
   Reg#(Bit#(66)) rx_b2   <- mkReg(0);

   Reg#(Bit#(8)) offset   <- mkReg(0);
   FIFOF#(Bit#(66)) fifo_in <- mkFIFOF;
   FIFOF#(Bit#(66)) fifo_out <- mkFIFOF;
   FIFOF#(Bit#(66)) cfFifo <- mkFIFOF;

   Wire#(Bool) rx_ready_wire <- mkDWire(False);

   rule cyc;
      cycle <= cycle + 1;
   endrule

   rule slip_data(rx_ready_wire);
      Bit#(66) rx_b1_shifted;
      Bit#(66) rx_b2_shifted;
      Bit#(66) shifted;
      let v <- toGet(fifo_in).get;
      //if(verbose) $display("%d: blocksync dataIn=%h offset=%h", cycle, v, offset);
      rx_b1_shifted = rx_b1 << offset;
      rx_b2_shifted = rx_b2 >> (66 - offset);
      shifted = rx_b1_shifted | rx_b2_shifted;

      rx_b1 <= v;
      rx_b2 <= rx_b1;

      cfFifo.enq(shifted);
      //if(verbose) $display("%d: blocksync r1=%h r2=%h rs=%h", cycle, rx_b1, rx_b2, shifted);
   endrule

   rule state_lock_init (curr_state == LOCK_INIT);
      let v <- toGet(cfFifo).get;
      block_lock <= False;
      offset     <= 60; //FIXME
      curr_state <= RESET_CNT;
      fifo_out.enq(v);
      //if(verbose) $display("%d: blocksync state_lock_init %d", cycle, curr_state);
   endrule

   rule state_reset_cnt (curr_state == RESET_CNT);
      let v <- toGet(cfFifo).get;
      sh_cnt <= 0;
      sh_invalid_cnt <= 0;
      slip_done <= False;
      curr_state <= TEST_SH;
      fifo_out.enq(v);
      if(verbose) $display("%d: state_reset_cnt", cycle);
   endrule

   // Optimized-away VALID_SH and INVALID_SH state
   rule state_test_sh (curr_state == TEST_SH);
      let v <- toGet(cfFifo).get;
      Bool sh_valid = unpack(v[0] ^ v[1]);

      // VALID_SH
      if (sh_valid) begin
         sh_cnt <= sh_cnt + 1;
         if (sh_cnt < 64) begin
            curr_state <= TEST_SH;
         end
         else if (sh_cnt == 64 && sh_invalid_cnt == 0) begin
            curr_state <= GOOD_64;
         end
         else if (sh_cnt == 64 && sh_invalid_cnt > 0) begin
            curr_state <= RESET_CNT;
         end
         else begin
            curr_state <= RESET_CNT;
         end
      end

      // INVALID_SH
      else begin
         sh_cnt <= sh_cnt + 1;
         sh_invalid_cnt <= sh_invalid_cnt + 1;
         if (sh_cnt == 64 && sh_invalid_cnt < 16 && block_lock) begin
            curr_state <= RESET_CNT;
         end
         else if (sh_invalid_cnt == 16 || !block_lock) begin
            curr_state <= SLIP;
         end
         else if (sh_cnt < 64 && sh_invalid_cnt < 16 && block_lock) begin
            curr_state <= TEST_SH;
         end
         else begin
            curr_state <= RESET_CNT;
         end
      end

      fifo_out.enq(v);
      if(verbose) $display("%d: blocksync state_test_sh v=%h, vld=%d, lock=%d, sh_cnt=%d, invld_cnt=%d", cycle, v, pack(sh_valid), pack(block_lock), sh_cnt, sh_invalid_cnt);
   endrule

   rule slip (curr_state == SLIP);
      let v <- toGet(cfFifo).get;
      block_lock <= False;
      if (offset >= 65) begin
         offset <= 0;
      end
      else begin
         offset <= offset + 1;
      end
      curr_state <= RESET_CNT;
      fifo_out.enq(v);
      if(verbose) $display("%d: blocksync state_slip offset=%d", cycle, offset);
   endrule

   rule state_good_64 (curr_state == GOOD_64);
      let v <- toGet(cfFifo).get;
      //Bool sh_valid = unpack(v[0]^v[1]);
      //if (sh_valid) begin
      block_lock <= True;
      fifo_out.enq(v);
      //end
      curr_state <= RESET_CNT;
      if(verbose) $display("%d: blocksync state_good_64 %d, %d, enqueue %h", cycle, curr_state, pack(block_lock), v);
   endrule

   method Action rx_ready (Bool v);
      rx_ready_wire <= v;
   endmethod

   interface blockSyncIn = toPipeIn(fifo_in);
   interface dataOut = toPipeOut(fifo_out);
   interface lock = block_lock;
endmodule
endpackage
