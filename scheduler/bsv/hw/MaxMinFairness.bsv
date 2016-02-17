import Vector::*;
import DefaultValue::*;

import SchedulerTypes::*;

interface MaxMinFairness;
    method Action addFlow(ServerIndex src, ServerIndex dst);
    method Bool flowExists(ServerIndex src, ServerIndex dst);
    method Action removeFlow(ServerIndex src, ServerIndex dst);
    method Action addToFlowCountMatrix(ServerIndex src, ServerIndex dst);
    method Action remFromFlowCountMatrix(ServerIndex src, ServerIndex dst);
    method ServerIndex getFlowCount(ServerIndex src, ServerIndex dst);
    method Action printMatrix(ServerIndex host_index);
endinterface

(* synthesize *)
module mkMaxMinFairness (MaxMinFairness);
    Vector#(NUM_OF_SERVERS, Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))))
                                  flow_matrix <- replicateM(replicateM(mkReg(0)));
    Vector#(NUM_OF_SERVERS, Vector#(NUM_OF_SERVERS, Reg#(ServerIndex)))
                            flow_count_matrix <- replicateM(replicateM(mkReg(0)));

    Reg#(ServerIndex) s <- mkReg(fromInteger(valueof(NUM_OF_SERVERS)));
    Reg#(ServerIndex) d <- mkReg(fromInteger(valueof(NUM_OF_SERVERS)));
    Reg#(Bool) add_to_matrix <- mkReg(False);

    Reg#(Bit#(1)) stop_adding_removing_flag <- mkReg(0);

    for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
    begin
        for (Integer j = 0; j < valueof(NUM_OF_SERVERS); j = j + 1)
        begin
            rule update_flow_count (s == fromInteger(i) || d == fromInteger(j));
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

    method Action addFlow(ServerIndex src, ServerIndex dst);
        if (flow_matrix[src][dst] == 0)
            flow_matrix[src][dst] <= 1;
    endmethod

    method Bool flowExists(ServerIndex src, ServerIndex dst);
        if (flow_matrix[src][dst] == 1)
            return True;
        else return False;
    endmethod

    method Action removeFlow(ServerIndex src, ServerIndex dst);
        if (flow_matrix[src][dst] == 1)
            flow_matrix[src][dst] <= 0;
    endmethod

    method Action addToFlowCountMatrix(ServerIndex src, ServerIndex dst);
        if (flow_matrix[src][dst] == 0)
        begin
            s <= src;
            d <= dst;
            add_to_matrix <= True;
            stop_adding_removing_flag <= 1;
        end
    endmethod

    method Action remFromFlowCountMatrix(ServerIndex src, ServerIndex dst);
        if (flow_matrix[src][dst] == 1)
        begin
            s <= src;
            d <= dst;
            add_to_matrix <= False;
            stop_adding_removing_flag <= 1;
        end
    endmethod

    method ServerIndex getFlowCount(ServerIndex src, ServerIndex dst);
        return flow_count_matrix[src][dst];
    endmethod

    method Action printMatrix(ServerIndex host_index);
        $display("[SCHED (%d)] Flow count matrix");
        for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
        begin
            for (Integer j = 0; j < valueof(NUM_OF_SERVERS); j = j + 1)
            begin
                $display("%d", flow_count_matrix[i][j]);
            end
        end
        $display("\n");
    endmethod
endmodule
