import List::*;
import Vector::*;
import BuildVector::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import GetPut::*;
import DefaultValue::*;

import PriorityEncoder::*;

typedef 32 SIZE;

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

interface MinPriorityQueue#(type v, type p);
    interface Put#(Node#(v, p)) insert_req;
    interface Get#(void) insert_res;
    method ActionValue#(Node#(v, p)) first();
    method Action deq();
    method Action clear();
    method Action displayQueue();
endinterface

function Bit#(1) compare (Node#(v, p) x, Node#(v, p) y)
    provisos (Ord#(p));
    if (x.p > y.p)
        return 1;
    else
        return 0;
endfunction

module mkMinPriorityQueue(MinPriorityQueue#(v, p))
    provisos (Bits#(v, v__)
             ,Bits#(p, p__)
             ,Bounded#(v)
             ,Bounded#(p)
             ,Literal#(v)
             ,Ord#(p));

    PE#(SIZE) priority_encoder <- mkPEncoder;
    Vector#(SIZE, Reg#(Node#(v, p))) sorted_list <- replicateM(mkReg(defaultValue));
    Reg#(Node#(v, p)) node_to_insert <- mkReg(defaultValue);
    Reg#(Bit#(TLog#(SIZE))) curr_size <- mkReg(0);
    FIFO#(void) insert_res_fifo <- mkBypassFIFO;
    FIFOF#(Node#(v, p)) insert_req_fifo <- mkSizedBypassFIFOF(4);

    Bool deq_ok = (curr_size > 0);

    rule insert;
        let x <- toGet(priority_encoder.bin).get;
        case (x) matches
           tagged Valid .index : begin
              let v = readVReg(sorted_list);
              let shiftedV = shiftOutFromN(defaultValue, v, 1);
              /*TODO: implement with map(function, vec) */
              Vector#(SIZE, Node#(v, p)) outV = newVector;
              for (Integer i=0; i<valueOf(SIZE); i=i+1) begin
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
           end
           tagged Invalid: $display("invalid output %h", x);
        endcase
    endrule

    rule handle_insert_req;
       let v <- toGet(insert_req_fifo).get;
       node_to_insert <= v;
       let r = map(uncurry(compare), zip(readVReg(sorted_list), replicate(v)));
       priority_encoder.oht.put(pack(r));
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

    method Action displayQueue();
        for (Integer i = 0; i < valueof(SIZE); i = i + 1)
            $display("(%d %d)", sorted_list[i].v, sorted_list[i].p);
    endmethod

    interface Put insert_req = toPut(insert_req_fifo);
    interface Get insert_res = toGet(insert_res_fifo);
endmodule

