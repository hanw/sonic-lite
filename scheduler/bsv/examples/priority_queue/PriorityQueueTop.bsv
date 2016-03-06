// Copyright (c) 2013 Nokia, Inc.
// Copyright (c) 2013 Quanta Research Cambridge, Inc.

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
import FIFO::*;
import Vector::*;
import GetPut::*;

import MinPriorityQueue::*;

interface PriorityQueueTopIndication;
    method Action status(Bit#(8) s);
endinterface

interface PriorityQueueTopRequest;
   method Action start();
endinterface

interface PriorityQueueTop;
   interface PriorityQueueTopRequest request;
endinterface

module mkPriorityQueueTop#(PriorityQueueTopIndication indication)(PriorityQueueTop);
   MinPriorityQueue#(32, Bit#(16), Bit#(16)) min_priority_queue <- mkMinPriorityQueue;

   Reg#(Bit#(1)) start_counting <- mkReg(0);
   Reg#(Bit#(1)) start_inserting <- mkReg(0);
   Reg#(Bit#(1)) start_get_insert_loop <- mkReg(0);
   Reg#(Bit#(1)) wait_for_completion <- mkReg(0);

   Reg#(Bit#(16)) count <- mkReg(0);
   Reg#(Bit#(16)) insertion_count <- mkReg(0);
   Reg#(Bit#(16)) iteration <- mkReg(0);

   Vector#(16, Bit#(16)) priority_vector = replicate(0);

   priority_vector[0] = 29;
   priority_vector[1] = 39;
   priority_vector[2] = 10;
   priority_vector[3] = 0;
   priority_vector[4] = 29;
   priority_vector[5] = 76;
   priority_vector[6] = 902;
   priority_vector[7] = 0;
   priority_vector[8] = 8;
   priority_vector[9] = 0;
   priority_vector[10] = 9;
   priority_vector[11] = 52;
   priority_vector[12] = 902;
   priority_vector[13] = 60;
   priority_vector[14] = 76;
   priority_vector[15] = 39;

   Reg#(Bit#(4)) index <- mkReg(0);

   rule counter (start_counting == 1);
       count <= count + 1;
       if (count == 1000)
       begin
           start_counting <= 0;
       end
   endrule

   rule insert (start_inserting == 1
                && start_get_insert_loop == 0
                && wait_for_completion == 0);
       Node#(Bit#(16), Bit#(16)) node = Node {
                                            v : count,
                                            p : priority_vector[index]
                                        };
       index <= index + 1;
       min_priority_queue.insert_req.put(node);
       wait_for_completion <= 1;
       insertion_count <= insertion_count + 1;
       if (insertion_count == 19)
       begin
           start_inserting <= 0;
           start_get_insert_loop <= 1;
       end
   endrule

   rule insert_res;
       let x <- toGet(min_priority_queue.insert_res).get;
       wait_for_completion <= 0;
   endrule

   rule get_min_node (start_inserting == 0
                      && start_get_insert_loop == 1
                      && wait_for_completion == 0);
       $display("Itr = %d clock = %d", iteration, count);
       iteration <= iteration + 1;
       if (iteration == 10)
           start_get_insert_loop <= 0;
       min_priority_queue.displayQueue();
       let x <- min_priority_queue.first;
       min_priority_queue.deq;
       $display("GET: (%d, %d)", x.v, x.p);
       x.p = x.p + 3;
       min_priority_queue.insert_req.put(x);
       wait_for_completion <= 1;
   endrule

   interface PriorityQueueTopRequest request;
       method Action start();
           start_inserting <= 1;
           start_counting <= 1;
       endmethod
   endinterface
endmodule
