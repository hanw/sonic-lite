import Vector::*;
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

module mkMinPriorityQueue (MinPriorityQueue#(Bit#(size_t), Bit#(size_t)));
    FIFO#(void) insert_res_fifo <- mkBypassFIFO;

    PE#(SIZE) priority_encoder <- mkPEncoder;

    Vector#(SIZE, Reg#(Node#(Bit#(size_t), Bit#(size_t))))
                   sorted_list <- replicateM(mkReg(defaultValue));
    Reg#(Node#(Bit#(size_t), Bit#(size_t))) node_to_insert <- mkReg(defaultValue);
    Reg#(Bit#(TLog#(SIZE))) location_to_insert <- mkReg(0);
    Reg#(Bit#(TLog#(SIZE))) curr_size <- mkReg(0);

    Reg#(Bit#(1)) insert_in_progress <- mkReg(0);

    Vector#(SIZE, FIFO#(void))
        insert_in_correct_location_fifo <- replicateM(mkBypassFIFO);

    Reg#(Bit#(64)) count <- mkReg(0);
    rule counter;
        count <= count + 1;
    endrule

    rule get_correct_location_rule (insert_in_progress == 1);
        let x <- toGet(priority_encoder.bin).get;
        $display("get from pe %h", x);
        case (x) matches
            tagged Valid .index : insert_in_correct_location_fifo[index].enq(?);
            tagged Invalid: $display("invalid output %h", x);
        endcase
    endrule

    for (Integer i = 0; i < valueof(SIZE); i = i + 1)
    begin
        rule insert_in_correct_location_rule (insert_in_progress == 1);
            let y <- toGet(insert_in_correct_location_fifo[i]).get;
            for (Integer j = i; j < valueof(SIZE)-1; j = j + 1)
                sorted_list[j + 1] <= sorted_list[j];
            sorted_list[i] <= node_to_insert;
            insert_in_progress <= 0;
            curr_size <= curr_size + 1;
            insert_res_fifo.enq(?);
        endrule
    end

    method ActionValue#(Node#(Bit#(size_t), Bit#(size_t))) first()
                                               if (curr_size > 0);
        return sorted_list[0];
    endmethod

    method Action deq() if (insert_in_progress == 0 && curr_size > 0);
        for (Integer i = 0; i < valueof(SIZE)-1; i = i + 1)
            sorted_list[i] <= sorted_list[i + 1];
        sorted_list[valueof(SIZE)-1] <= defaultValue;
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
            $display("sorted_list %h", readVReg(sorted_list));
            let r = map(uncurry(compare), zip(readVReg(sorted_list), replicate(v)));
            $display("put %h", r);
            priority_encoder.oht.put(pack(r));
        endmethod
    endinterface
    interface Get insert_res = toGet(insert_res_fifo);
endmodule

