/* Copyright (c) 2015 Cornell University.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

import Clocks                ::*;
import StmtFSM               ::*;

(* synthesize *)
module tb1 (Empty);
   Reg#(Bit#(16)) simCycle <- mkReg(0);
   Reg#(Bit#(1)) a <- mkReg(0);

   Stmt test =
   seq
       while(True) seq
       a<=1'b1;
       //par
       //$display("I am noww running one more step at ", $time);
       a<=1'b0;
       //endpar
       endseq
   endseq;

   FSM fsm <- mkFSM(test);

   rule always_run(fsm.done);
       $display("I am noww running one more step at ", $time);
       fsm.start;
   endrule

   rule increment_cycle;
      simCycle <= simCycle + 1;
   endrule

   rule terminate (simCycle==200);
      $display("[%d]: %m: tb termination", $time);
      $finish;
   endrule
endmodule
