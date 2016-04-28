import Vector::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import DefaultValue::*;
import ClientServer::*;
import GetPut::*;

import SchedulerTypes::*;

typedef struct {
    Bit#(1) active;
    Bit#(16) flow_id;
    Bit#(16) seq_num;
} FlowElement deriving(Bits, Eq);

instance DefaultValue#(FlowElement);
    defaultValue = FlowElement {
                    active  : 0,
                    flow_id : 0,
                    seq_num : 0
                };
endinstance

typedef struct {
    ServerIndex src;
    ServerIndex dst;
    ServerIndex mid;
} BottleneckCountParams deriving(Bits, Eq);

interface MaxMinFairness;
    interface Server#(BottleneckCountParams, ServerIndex) bottleneck_count;
    method Action addFlow(ServerIndex src,
                          ServerIndex dst,
                          Bit#(16) flow_id,
                          Bit#(16) seq_num);
    method Bool flowExists(ServerIndex src,
                           ServerIndex dst);
    method Action removeFlow(ServerIndex src,
                             ServerIndex dst,
                             Bit#(16) flow_id,
                             Bit#(16) seq_num);
    method Action addToFlowCountMatrix(ServerIndex src,
                                       ServerIndex dst,
                                       Bit#(16) flow_id,
                                       Bit#(16) seq_num);
    method Action remFromFlowCountMatrix(ServerIndex src,
                                         ServerIndex dst);
    method Action printMatrix(ServerIndex host_index);
endinterface

(* synthesize *)
module mkMaxMinFairness (MaxMinFairness);
    Vector#(NUM_OF_SERVERS, Vector#(NUM_OF_SERVERS, Reg#(FlowElement)))
                       flow_matrix <- replicateM(replicateM(mkReg(defaultValue)));
    Vector#(NUM_OF_SERVERS, Vector#(NUM_OF_SERVERS, Reg#(ServerIndex)))
                            flow_count_matrix <- replicateM(replicateM(mkReg(0)));

    Reg#(ServerIndex) s <- mkReg(fromInteger(valueof(NUM_OF_SERVERS)));
    Reg#(ServerIndex) d <- mkReg(fromInteger(valueof(NUM_OF_SERVERS)));
    Reg#(Bool) add_to_matrix <- mkReg(False);

    Reg#(Bit#(1)) stop_adding_removing_flag <- mkReg(0);

    FIFOF#(BottleneckCountParams) bottleneck_count_req_fifo <- mkSizedFIFOF(2);
    FIFOF#(ServerIndex) bottleneck_count_res_fifo <- mkSizedFIFOF(2);

    rule handle_bottleneck_count_req;
        let req <- toGet(bottleneck_count_req_fifo).get;
        bottleneck_count_res_fifo.enq(max(flow_count_matrix[req.src][req.mid],
                                          flow_count_matrix[req.mid][req.dst]));
    endrule

    for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
    begin
        for (Integer j = 0; j < valueof(NUM_OF_SERVERS); j = j + 1)
        begin
            rule update_flow_count ((s == fromInteger(i) || d == fromInteger(j))
                                    && (i != j));
                if (add_to_matrix)
                    flow_count_matrix[i][j] <= flow_count_matrix[i][j] + 1;
                else
                begin
                    if (flow_count_matrix[i][j] > 0)
                        flow_count_matrix[i][j] <= flow_count_matrix[i][j] - 1;
                end
            endrule
        end
    end

    rule stop_adding_removing (stop_adding_removing_flag == 1);
        stop_adding_removing_flag <= 0;
        s <= fromInteger(valueof(NUM_OF_SERVERS));
        d <= fromInteger(valueof(NUM_OF_SERVERS));
    endrule

    method Action addFlow(ServerIndex src, ServerIndex dst, Bit#(16) flow_id,
                          Bit#(16) seq_num);
        if (flow_matrix[src][dst].active == 0)
        begin
            FlowElement f = FlowElement {
                                active : 1,
                                flow_id : 0,
                                seq_num : 0
                            };
            flow_matrix[src][dst] <= f;
        end
    endmethod

    method Bool flowExists(ServerIndex src, ServerIndex dst);
        if (flow_matrix[src][dst].active == 1)
            return True;
        else return False;
    endmethod

    method Action removeFlow(ServerIndex src, ServerIndex dst, Bit#(16) flow_id,
                             Bit#(16) seq_num);
        if (flow_matrix[src][dst].active == 1)
        begin
            FlowElement f = FlowElement {
                                active : 1,
                                flow_id : flow_id,
                                seq_num : seq_num
                            };
            flow_matrix[src][dst] <= f;
        end
    endmethod

    method Action addToFlowCountMatrix(ServerIndex src, ServerIndex dst,
                                       Bit#(16) flow_id, Bit#(16) seq_num);
        if (flow_matrix[src][dst].active == 0)
        begin
            s <= src;
            d <= dst;
            add_to_matrix <= True;
            stop_adding_removing_flag <= 1;
        end
    endmethod

    method Action remFromFlowCountMatrix(ServerIndex src, ServerIndex dst);
        if (flow_matrix[src][dst].active == 1)
        begin
            s <= src;
            d <= dst;
            add_to_matrix <= False;
            stop_adding_removing_flag <= 1;
        end
    endmethod

    method Action printMatrix(ServerIndex host_index);
        $display("[SCHED (%d)] Flow count matrix", host_index);
        for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
        begin
            for (Integer j = 0; j < valueof(NUM_OF_SERVERS); j = j + 1)
            begin
                $write("%d ", flow_count_matrix[i][j]);
            end
            $display;
        end
    endmethod

    interface Server bottleneck_count;
        interface request = toPut(bottleneck_count_req_fifo);
        interface response = toGet(bottleneck_count_res_fifo);
    endinterface
endmodule
