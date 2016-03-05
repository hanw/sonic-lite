import List::*;
import Vector::*;
import BuildVector::*;
import FIFO::*;
import SpecialFIFOs::*;
import GetPut::*;
import DefaultValue::*;

import PriorityEncoder::*;

typedef 32 SIZE;

typedef struct {
    valueType v;
    priorityType p;
} Node#(type valueType, type priorityType) deriving(Bits, Eq);

instance DefaultValue#(Node#(Bit#(size_t), Bit#(size_t)));
    defaultValue = Node {
        v : 0,
        p : maxBound
    };
endinstance

interface MinPriorityQueue#(type valueType, type priorityType);
    interface Put#(Node#(valueType, priorityType)) insert_req;
    interface Get#(void) insert_res;
    method ActionValue#(Node#(valueType, priorityType)) first();
    method Action deq();
    method Action clear();
    method Action displayQueue();
endinterface

function Bit#(1) compare (Node#(Bit#(size_t), Bit#(size_t)) x,
                          Node#(Bit#(size_t), Bit#(size_t)) y);
    if (x.p > y.p)
        return 1;
    else
        return 0;
endfunction

module mkMinPriorityQueue(MinPriorityQueue#(Bit#(size_t), Bit#(size_t)));
    PE#(SIZE) priority_encoder <- mkPEncoder;
    Vector#(SIZE, Reg#(Node#(Bit#(size_t), Bit#(size_t))))
                   sorted_list <- replicateM(mkReg(defaultValue));
    Reg#(Node#(Bit#(size_t), Bit#(size_t))) node_to_insert <- mkReg(defaultValue);
    Reg#(Bit#(TLog#(SIZE))) curr_size <- mkReg(0);
    Reg#(Bit#(1)) insert_in_progress <- mkReg(0);
    FIFO#(void) insert_res_fifo <- mkBypassFIFO;

    rule insert (insert_in_progress == 1);
        let x <- toGet(priority_encoder.bin).get;
        $display("get from pe %h", x);
        case (x) matches
           tagged Valid .index : begin
              let v = readVReg(sorted_list);
              let shiftedV = shiftOutFromN(defaultValue, v, 1);
              /*TODO: implement with map(function, vec) */
              Vector#(SIZE, Node#(Bit#(size_t), Bit#(size_t))) outV = newVector;
              for (Integer i=0; i<valueOf(SIZE); i=i+1) begin
                  if (fromInteger(i) < index)
                     outV[i] = v[i];
                  else if (fromInteger(i) == index)
                     outV[i] = node_to_insert;
                  else
                     outV[i] = shiftedV[i];
              end
              writeVReg(sorted_list, outV);
              insert_in_progress <= 0;
              curr_size <= curr_size + 1;
              insert_res_fifo.enq(?);
           end
           tagged Invalid: $display("invalid output %h", x);
        endcase
    endrule

    method ActionValue#(Node#(Bit#(size_t), Bit#(size_t))) first() if (curr_size > 0);
        return head(readVReg(sorted_list));
    endmethod

    method Action deq() if (insert_in_progress == 0 && curr_size > 0);
        let v = append(tail(readVReg(sorted_list)), vec(defaultValue));
        writeVReg(sorted_list, v);
        curr_size <= curr_size - 1;
    endmethod

    method Action clear() if (insert_in_progress == 0 && curr_size > 0);
        writeVReg(sorted_list, defaultValue);
        curr_size <= 0;
    endmethod

    method Action displayQueue();
        for (Integer i = 0; i < valueof(SIZE); i = i + 1)
            $display("(%d %d)", sorted_list[i].v, sorted_list[i].p);
    endmethod

    interface Put insert_req;
        method Action put (Node#(Bit#(size_t), Bit#(size_t)) v) if (insert_in_progress == 0);
            node_to_insert <= v;
            insert_in_progress <= 1;
            let r = map(uncurry(compare), zip(readVReg(sorted_list), replicate(v)));
            priority_encoder.oht.put(pack(r));
        endmethod
    endinterface
    interface Get insert_res = toGet(insert_res_fifo);
endmodule

