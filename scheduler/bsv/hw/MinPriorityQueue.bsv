// Copyright (c) 2016 Cornell University

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

import Assert::*;
import BuildVector::*;
import ClientServer::*;
import DefaultValue::*;
import FIFO::*;
import FIFOF::*;
import GetPut::*;
import PriorityEncoder::*;
import SpecialFIFOs::*;
import Vector::*;

typedef struct {
    a v;
    b p;
} Node#(type a, type b) deriving(Bits, Eq);

instance DefaultValue#(Node#(a, b))
    provisos (Bits#(a, a__)
             ,Bits#(b, b__)
             ,Bounded#(a)
             ,Bounded#(b)
             ,Literal#(a));
    defaultValue = Node {
        v : minBound,
        p : maxBound
    };
endinstance

interface MinPriorityQueue#(numeric type depth, type v, type p);
    interface Server#(Node#(v, p), void) insert;
    interface Server#(Node#(v, p), void) remove;
    method ActionValue#(Node#(v, p)) first();
    method Action deq();
    method Action clear();
    method ActionValue#(Bit#(TLog#(depth))) size();
    method Action displayQueue();
endinterface

function Bit#(1) comparePriority (Node#(v, p) x, Node#(v, p) y)
    provisos (Ord#(p), Eq#(p));
    if (x.p > y.p)
        return 1;
    else
        return 0;
endfunction

function Bit#(1) compareValue (Node#(v, p) x, Node#(v, p) y)
    provisos (Ord#(v), Eq#(v));
    if (x.v == y.v)
        return 1;
    else
        return 0;
endfunction

module mkMinPriorityQueue(MinPriorityQueue#(n, v, p))
    provisos (Bits#(v, v__)
             ,Bits#(p, p__)
             ,Bounded#(v)
             ,Bounded#(p)
             ,Literal#(v)
             ,Ord#(p)
             ,Ord#(v)
             ,Eq#(p)
             ,Eq#(v)
             ,Add#(a__, 1, n)
             ,PriorityEncoder::PEncoder#(n));

    PE#(n) priority_encoder <- mkPEncoder;
    Vector#(n, Reg#(Node#(v, p))) sorted_list <- replicateM(mkReg(defaultValue));
    Reg#(Node#(v, p)) node_to_insert <- mkReg(defaultValue);
    Reg#(Node#(v, p)) node_to_remove <- mkReg(defaultValue);
    Reg#(Bit#(TLog#(n))) curr_size <- mkReg(0);
    FIFO#(void) insert_res_fifo <- mkBypassFIFO;
    FIFOF#(Node#(v, p)) insert_req_fifo <- mkSizedFIFOF(4);
    FIFO#(void) remove_res_fifo <- mkBypassFIFO;
    FIFOF#(Node#(v, p)) remove_req_fifo <- mkSizedFIFOF(4);

    Reg#(Bit#(1)) insert_in_progress <- mkReg(0);
    Reg#(Bit#(1)) remove_in_progress <- mkReg(0);
    Bool deq_ok = (curr_size > 0);

    rule insert_item (insert_in_progress == 1);
        let x <- toGet(priority_encoder.bin).get;
        dynamicAssert(!isValid(x), "Error: priority encoder returns invalid location");
        case (x) matches
           tagged Valid .index : begin
              let v = readVReg(sorted_list);
              let shiftedV = shiftOutFromN(defaultValue, v, 1);
              /*TODO: implement with map(function, vec) */
              Vector#(n, Node#(v, p)) outV = newVector;
              for (Integer i=0; i<valueOf(n); i=i+1) begin
                  if (fromInteger(i) < index)
                     outV[i] = v[i];
                  else if (fromInteger(i) == index)
                     outV[i] = node_to_insert;
                  else
                     outV[i] = shiftedV[i];
              end
              writeVReg(sorted_list, outV);
              curr_size <= curr_size + 1;
              insert_res_fifo.enq(?);
              $display("HERE-2 %d %d", outV[0].v, outV[0].p);
           end
        endcase
        insert_in_progress <= 0;
    endrule

    rule remove_item (remove_in_progress == 1);
        let x <- toGet(priority_encoder.bin).get;
        dynamicAssert(!isValid(x), "Error: priority encoder returns invalid location");
        case (x) matches
            tagged Valid .index : begin
                let v = readVReg(sorted_list);
                let shiftedV = shiftOutFrom0(defaultValue, v, 1);
                Vector#(n, Node#(v, p)) outV = newVector;
                for (Integer i=0; i<valueOf(n); i=i+1) begin
                    if (fromInteger(i) < index)
                        outV[i] = v[i];
                    else
                        outV[i] = shiftedV[i];
                end
                writeVReg(sorted_list, outV);
                curr_size <= curr_size - 1;
                remove_res_fifo.enq(?);
            end
        endcase
        remove_in_progress <= 0;
    endrule

    rule handle_insert_req (insert_in_progress == 0 && remove_in_progress == 0);
       let v <- toGet(insert_req_fifo).get;
       node_to_insert <= v;
       let r = map(uncurry(comparePriority),
                   zip(readVReg(sorted_list), replicate(v)));
       priority_encoder.oht.put(pack(r));
       insert_in_progress <= 1;
       $display("HERE-1 %d %d size = %d", v.v, v.p, curr_size);
    endrule

    rule handle_remove_req (insert_in_progress == 0 && remove_in_progress == 0);
       let v <- toGet(remove_req_fifo).get;
       node_to_remove <= v;
       let r = map(uncurry(compareValue),
                   zip(readVReg(sorted_list), replicate(v)));
       priority_encoder.oht.put(pack(r));
       remove_in_progress <= 1;
    endrule

    method ActionValue#(Node#(v, p)) first() if (curr_size > 0);
        return head(readVReg(sorted_list));
    endmethod

    method Action deq() if (deq_ok);
        let v = append(tail(readVReg(sorted_list)), vec(defaultValue));
        writeVReg(sorted_list, v);
        curr_size <= curr_size - 1;
    endmethod

    method Action clear();
        writeVReg(sorted_list, defaultValue);
        curr_size <= 0;
    endmethod

    method ActionValue#(Bit#(TLog#(n))) size();
        return curr_size;
    endmethod

    method Action displayQueue();
        for (Integer i = 0; i < valueof(n); i = i + 1)
            $write("(%d,%d)", sorted_list[i].v, sorted_list[i].p);
        $display;
    endmethod

    interface Server insert;
       interface request = toPut(insert_req_fifo);
       interface response = toGet(insert_res_fifo);
    endinterface

    interface Server remove;
       interface request = toPut(remove_req_fifo);
       interface response = toGet(remove_res_fifo);
    endinterface
endmodule

