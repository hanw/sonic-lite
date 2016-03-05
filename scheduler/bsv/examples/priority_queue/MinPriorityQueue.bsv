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

function Int#(2) compare (Node#(Bit#(size_t), Bit#(size_t)) x,
                          Node#(Bit#(size_t), Bit#(size_t)) y);
    if (x.p > y.p)
        return 1;
    else if (x.p == y.p)
        return 0;
    else
        return -1;
endfunction

module mkMinPriorityQueue (MinPriorityQueue#(Bit#(size_t), Bit#(size_t)));
    FIFO#(Node#(Bit#(size_t), Bit#(size_t)))
        insert_req_fifo <- mkSizedFIFO(valueof(SIZE));
    FIFO#(void) insert_res_fifo <- mkBypassFIFO;

    PE#(SIZE) priority_encoder <- mkPEncoder;

    Vector#(SIZE, Reg#(Node#(Bit#(size_t), Bit#(size_t))))
                   sorted_list <- replicateM(mkReg(defaultValue));
    Vector#(SIZE, Reg#(Bit#(1))) b_vector <- replicateM(mkReg(0));
    Reg#(Node#(Bit#(size_t), Bit#(size_t))) node_to_insert <- mkReg(defaultValue);
    Reg#(Bit#(TLog#(SIZE))) location_to_insert <- mkReg(0);
    Reg#(Bit#(TLog#(SIZE))) curr_size <- mkReg(0);

    Reg#(Bit#(1)) insert_in_progress <- mkReg(0);

    Vector#(SIZE, FIFO#(void)) create_bit_vector_fifo <- replicateM(mkFIFO);
    FIFO#(void) find_correct_location_fifo <- mkPipelineFIFO;
    Vector#(SIZE, FIFO#(void))
        insert_in_correct_location_fifo <- replicateM(mkBypassFIFO);

    Reg#(Bit#(64)) count <- mkReg(0);
    rule counter;
        count <= count + 1;
    endrule

    for (Integer i = 0; i < valueof(SIZE); i = i + 1)
    begin
        rule create_bit_vector_rule (insert_in_progress == 1);
            let x <- toGet(create_bit_vector_fifo[i]).get;
            if (i == 0)
                find_correct_location_fifo.enq(?);
            if (compare(sorted_list[i], node_to_insert) > 0)
                b_vector[i] <= 1;
            else
                b_vector[i] <= 0;
        endrule
    end

    rule find_correct_location_rule (insert_in_progress == 1);
        let x <- toGet(find_correct_location_fifo).get;
        Bit#(SIZE) temp = 0;
        for (Integer i = 0; i < valueof(SIZE); i = i + 1)
        begin
            temp[i] = b_vector[i];
        end
        priority_encoder.oht.put(temp);
    endrule

    rule get_correct_location_rule (insert_in_progress == 1);
        let x <- toGet(priority_encoder.bin).get;
        case (x) matches
            tagged Valid .index : insert_in_correct_location_fifo[index].enq(?);
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

    rule handle_insert_req (insert_in_progress == 0);
        let req <- toGet(insert_req_fifo).get;
        node_to_insert <= req;
        insert_in_progress <= 1;
        for (Integer i = 0; i < valueof(SIZE); i = i + 1)
            create_bit_vector_fifo[i].enq(?);
    endrule

    method ActionValue#(Node#(Bit#(size_t), Bit#(size_t))) first()
                                               if (curr_size > 0);
        return sorted_list[0];
    endmethod

    method Action deq() if (insert_in_progress == 0);
        if (curr_size > 0)
        begin
            for (Integer i = 0; i < valueof(SIZE)-1; i = i + 1)
                sorted_list[i] <= sorted_list[i + 1];
            sorted_list[valueof(SIZE)-1] <= defaultValue;
            curr_size <= curr_size - 1;
        end
    endmethod

    method Action clear() if (insert_in_progress == 0);
        if (curr_size > 0)
        begin
            for (Integer i = 0; i < valueof(SIZE); i = i + 1)
                sorted_list[i] <= defaultValue;
            curr_size <= 0;
        end
    endmethod

    method Action displayQueue();
        for (Integer i = 0; i < valueof(SIZE); i = i + 1)
            $display("(%d %d)", sorted_list[i].v, sorted_list[i].p);
    endmethod

    interface Put insert_req = toPut(insert_req_fifo);
    interface Get insert_res = toGet(insert_res_fifo);
endmodule

