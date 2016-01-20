import FIFO::*;
import FIFOF::*;
import Vector::*;
import GetPut::*;
import DefaultValue::*;
import Clocks::*;

import DMASimulator::*;
import Mac::*;
import SchedulerTypes::*;
import Scheduler::*;
import RingBufferTypes::*;
import RingBuffer::*;
import Addresses::*;
import GlobalClock::*;

interface SchedulerTopIndication;
`ifdef DEBUG
   method Action test_func_resp();
`endif

`ifdef DEBUG_SCHEDULER
   method Action set_start_time_result(Bit#(8) op_outcome);
   method Action get_start_time_result(Bit#(64) start_time, Bit#(8) op_outcome);
   method Action set_interval_result(Bit#(8) op_outcome);
   method Action get_interval_result(Bit#(64) interval, Bit#(8) op_outcome);
   method Action insert_result(Bit#(8) op_outcome);
   method Action display_result(Bit#(32) server_ip, Bit#(64) server_mac, Bit#(8) op_outcome);
`endif
endinterface

interface SchedulerTopRequest;
`ifdef DEBUG
   method Action test_func();
`endif

`ifdef DEBUG_SCHEDULER
   method Action set_start_time(Bit#(64) start_time);
   method Action get_start_time();
   method Action set_interval(Bit#(64) interval);
   method Action get_interval();
   method Action insert(Bit#(32) server_ip, Bit#(64) server_mac);
   method Action display(Bit#(32) serverIdx);
   method Action start_scheduler();
   method Action stop_scheduler();
`endif
endinterface

interface SchedulerTop;
   interface SchedulerTopRequest request;
endinterface

module mkSchedulerTop#(SchedulerTopIndication indication)(SchedulerTop);

`ifdef DEBUG

   FIFO#(Bit#(1)) test_fifo <- mkFIFO;

   rule resp;
    test_fifo.deq;
    indication.test_func_resp();
   endrule

`endif

`ifdef FULL_SYSTEM_TEST

    Clock defaultClock <- exposeCurrentClock();
    Reset defaultReset <- exposeCurrentReset();
    Clock txClock <- mkAbsoluteClock(0, 64);
    Reset txReset <- mkSyncReset(2, defaultReset, txClock);
    Clock rxClock <- mkAbsoluteClock(0, 64);
    Reset rxReset <- mkSyncReset(2, defaultReset, rxClock);

    GlobalClock clk <- mkGlobalClock(clocked_by txClock, reset_by txReset);

    Vector#(NUM_OF_SERVERS,
            Scheduler#(SchedReqResType, SchedReqResType,
            ReadReqType, ReadResType, WriteReqType, WriteResType)) scheduler;

    for (Integer i = 0; i < fromInteger(valueof(NUM_OF_SERVERS)); i = i + 1)
    begin
        scheduler[i] <- mkScheduler(i, txClock, txReset, rxClock, rxReset,
                                    clocked_by txClock, reset_by txReset);
    end

    Vector#(NUM_OF_SERVERS, DMASimulator) dma_sim;
    Vector#(NUM_OF_SERVERS, Mac) mac;

    for (Integer i = 0; i < fromInteger(valueof(NUM_OF_SERVERS)); i = i + 1)
    begin
        dma_sim[i] <- mkDMASimulator(i, scheduler[i],
                                     clocked_by txClock, reset_by txReset);
        mac[i] <- mkMac(i, scheduler[i], txClock, txReset, rxClock, rxReset);
    end


    Vector#(NUM_OF_SERVERS, Reg#(ServerIndex)) count
              <- replicateM(mkReg(fromInteger(valueof(NUM_OF_SERVERS)),
                                  clocked_by txClock, reset_by txReset));

    Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) done_populating_table
                    <- replicateM(mkReg(0, clocked_by txClock, reset_by txReset));

    Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) fire_once
                    <- replicateM(mkReg(0, clocked_by txClock, reset_by txReset));

    Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) stop
                    <- replicateM(mkReg(0, clocked_by txClock, reset_by txReset));

    for (Integer i = 0; i < fromInteger(valueof(NUM_OF_SERVERS)); i = i + 1)
    begin
        rule populate_sched_table (count[i] > 0);
            ServerIndex idx = (count[i] + fromInteger(i))
                                  % fromInteger(valueof(NUM_OF_SERVERS));
            scheduler[i].request.put(makeSchedReqRes(ip_address(idx),
                                                     mac_address(idx),
                                                     0, 0, idx, INSERT,
                                                     SUCCESS));
            count[i] <= count[i] - 1;
            if (count[i] == 1)
                done_populating_table[i] <= 1;
        endrule

        rule consume_res;
            let res <- scheduler[i].insert_response.get;
        endrule

        rule set_start_time (done_populating_table[i] == 1);
            done_populating_table[i] <= 0;
            scheduler[i].request.put
                        (makeSchedReqRes(0, 0, 10020, 0, 0, SETTIME, SUCCESS));
        endrule

        rule set_start_interval;
            let res <- scheduler[i].settime_response.get;
            scheduler[i].request.put
                        (makeSchedReqRes(0, 0, 0, 8, 0, SETINTERVAL, SUCCESS));
        endrule

        /* Wait for 10,000 cycles to let the MAC initialize */
        rule start_scheduler_and_dma (fire_once[i] == 0 && clk.currTime() > 10000);
            let res <- scheduler[i].setinterval_response.get;
            scheduler[i].request.put
                 (makeSchedReqRes(0, 0, 0, 0, 0, STARTSCHED, SUCCESS));
            if (i < 2)
			    dma_sim[i].start();
            fire_once[i] <= 1;
        endrule

        rule stop_dma (stop[i] == 1);
            stop[i] <= 0;
            dma_sim[i].stop();
			scheduler[i].request.put
			    (makeSchedReqRes(0, 0, 0, 0, 0, STOPSCHED, SUCCESS));
        endrule
    end

    /* This rule is to configure when to stop the DMA and collect stats */
    Reg#(Bit#(64)) counter <- mkReg(0, clocked_by txClock, reset_by txReset);
    rule count_cycles (fire_once[0] == 1
             && fire_once[1] == 1
             && fire_once[2] == 1
             && fire_once[3] == 1
             && fire_once[4] == 1
             && counter <= 1000000);
        counter <= counter + 1;
        if (counter <= 100000)
            $display("CLK = %d", counter);
        if (counter == 100000)
        begin
            $display("[TOP] Number of cycles DMA ran for = %d", counter);
            for (Integer i = 0; i < fromInteger(valueof(NUM_OF_SERVERS)); i = i + 1)
            begin
                stop[i] <= 1;
                scheduler[i].print_stats();
				scheduler[i].print_queue_stats();
            end
        end
    endrule

    /* Simulating connection wires via SyncFIFOs */

    Vector#(NUM_OF_SERVERS, Vector#(NUM_OF_PORTS, SyncFIFOIfc#(Bit#(72))))
    wire_fifo <- replicateM(replicateM(mkSyncFIFO(16, txClock, txReset, rxClock)));

    for (Integer i = 0; i < fromInteger(valueof(NUM_OF_SERVERS)); i = i + 1)
    begin
        for (Integer j = 0; j < fromInteger(valueof(NUM_OF_PORTS)); j = j + 1)
        begin
		rule tx_rule;
		    	let v = mac[i].tx(j);
                (wire_fifo[i])[j].enq(v);
                //$display("[%d %d] MAC tx data = %d", i, j, v);
            endrule
        end
    end

    rule rx_rule_0_0;
        let v <- toGet((wire_fifo[1])[0]).get;
        mac[0].rx(0, v);
        //$display("Getting from (1, 0) to (0, 0)");
    endrule

    rule rx_rule_0_1;
        let v <- toGet((wire_fifo[2])[0]).get;
        mac[0].rx(1, v);
        //$display("Getting from (2, 0) to (0, 1)");
    endrule

    rule rx_rule_0_2;
        let v <- toGet((wire_fifo[3])[0]).get;
        mac[0].rx(2, v);
        //$display("Getting from (3, 0) to (0, 2)");
    endrule

    rule rx_rule_0_3;
        let v <- toGet((wire_fifo[4])[0]).get;
        mac[0].rx(3, v);
        //$display("Getting from (4, 0) to (0, 3)");
    endrule

    rule rx_rule_1_0;
        let v <- toGet((wire_fifo[0])[0]).get;
        mac[1].rx(0, v);
        //$display("Getting from (0, 0) to (1, 0)");
    endrule

    rule rx_rule_1_1;
        let v <- toGet((wire_fifo[2])[1]).get;
        mac[1].rx(1, v);
        //$display("Getting from (2, 1) to (1, 1)");
    endrule

    rule rx_rule_1_2;
        let v <- toGet((wire_fifo[3])[1]).get;
        mac[1].rx(2, v);
        //$display("Getting from (3, 1) to (1, 2)");
    endrule

    rule rx_rule_1_3;
        let v <- toGet((wire_fifo[4])[1]).get;
        mac[1].rx(3, v);
        //$display("Getting from (4, 1) to (1, 3)");
    endrule

    rule rx_rule_2_0;
        let v <- toGet((wire_fifo[0])[1]).get;
        mac[2].rx(0, v);
        //$display("Getting from (0, 1) to (2, 0)");
    endrule

    rule rx_rule_2_1;
        let v <- toGet((wire_fifo[1])[1]).get;
        mac[2].rx(1, v);
        //$display("Getting from (1, 1) to (2, 1)");
    endrule

    rule rx_rule_2_2;
        let v <- toGet((wire_fifo[3])[2]).get;
        mac[2].rx(2, v);
        //$display("Getting from (3, 2) to (2, 2)");
    endrule

    rule rx_rule_2_3;
        let v <- toGet((wire_fifo[4])[2]).get;
        mac[2].rx(3, v);
        //$display("Getting from (4, 2) to (2, 3)");
    endrule

    rule rx_rule_3_0;
        let v <- toGet((wire_fifo[0])[2]).get;
        mac[3].rx(0, v);
        //$display("Getting from (0, 2) to (3, 0)");
    endrule

    rule rx_rule_3_1;
        let v <- toGet((wire_fifo[1])[2]).get;
        mac[3].rx(1, v);
        //$display("Getting from (1, 2) to (3, 1)");
    endrule

    rule rx_rule_3_2;
        let v <- toGet((wire_fifo[2])[2]).get;
        mac[3].rx(2, v);
        //$display("Getting from (2, 2) to (3, 2)");
    endrule

    rule rx_rule_3_3;
        let v <- toGet((wire_fifo[4])[3]).get;
        mac[3].rx(3, v);
        //$display("Getting from (4, 3) to (3, 3)");
    endrule

    rule rx_rule_4_0;
        let v <- toGet((wire_fifo[0])[3]).get;
        mac[4].rx(0, v);
        //$display("Getting from (0, 3) to (4, 0)");
    endrule

    rule rx_rule_4_1;
        let v <- toGet((wire_fifo[1])[3]).get;
        mac[4].rx(1, v);
        //$display("Getting from (1, 3) to (4, 1)");
    endrule

    rule rx_rule_4_2;
        let v <- toGet((wire_fifo[2])[3]).get;
        mac[4].rx(2, v);
        //$display("Getting from (2, 3) to (4, 2)");
    endrule

    rule rx_rule_4_3;
        let v <- toGet((wire_fifo[3])[3]).get;
        mac[4].rx(3, v);
        //$display("Getting from (3, 3) to (4, 3)");
    endrule

`endif

`ifdef DEBUG_SCHEDULER

   Scheduler#(SchedReqResType, SchedReqResType,
              ReadReqType, ReadResType, WriteReqType, WriteResType)
        scheduler1 <- mkScheduler(0, txClock, txReset, rxClock, rxReset);

   Reg#(ServerIndex) serverIdx <- mkReg(0);
   Reg#(Bit#(1)) display_in_progress <- mkReg(0);

   rule set_start_time_res;
       let res <- scheduler1.settime_response.get;
       if (res.op_outcome == SUCCESS)
       begin
           indication.set_start_time_result(1);
       end
       else
           indication.set_start_time_result(0);
   endrule

   rule get_start_time_res;
       let res <- scheduler1.gettime_response.get;
       if (res.op_outcome == SUCCESS)
           indication.get_start_time_result(res.start_time, 1);
       else
           indication.get_start_time_result(0, 0);
   endrule

   rule set_interval_res;
       let res <- scheduler1.setinterval_response.get;
       if (res.op_outcome == SUCCESS)
           indication.set_interval_result(1);
       else
           indication.set_interval_result(0);
   endrule

   rule get_interval_res;
       let res <- scheduler1.getinterval_response.get;
       if (res.op_outcome == SUCCESS)
           indication.get_interval_result(res.interval, 1);
       else
           indication.get_interval_result(0, 0);
   endrule

   rule insert_res;
       let res <- scheduler1.insert_response.get;
       if (res.op_outcome == SUCCESS)
           indication.insert_result(1);
       else
           indication.insert_result(0);
   endrule

   rule display_res;
       let res <- scheduler1.display_response.get;
       if (res.op_outcome == SUCCESS)
           indication.display_result(zeroExtend(res.server_ip),
                                     zeroExtend(res.server_mac), 1);
       else
           indication.display_result(0, 0, 0);
   endrule

`endif

   interface SchedulerTopRequest request;

    `ifdef DEBUG

       method Action test_func();
           $display("called set start time");
           indication.test_func_resp();
       endmethod

   `endif

   `ifdef DEBUG_SCHEDULER

       method Action set_start_time(Bit#(64) start_time);
           scheduler1.request.put
                       (makeSchedReqRes(0, 0, start_time, 0, 0, SETTIME, SUCCESS));
       endmethod

       method Action get_start_time();
           scheduler1.request.put(makeSchedReqRes(0, 0, 0, 0, 0, GETTIME, SUCCESS));
       endmethod

       method Action set_interval(Bit#(64) interval);
           scheduler1.request.put
                    (makeSchedReqRes(0, 0, 0, interval, 0, SETINTERVAL, SUCCESS));
       endmethod

       method Action get_interval();
           scheduler1.request.put
                          (makeSchedReqRes(0, 0, 0, 0, 0, GETINTERVAL, SUCCESS));
       endmethod

       method Action insert(Bit#(32) server_ip, Bit#(64) server_mac);
           scheduler1.request.put
       (makeSchedReqRes(server_ip, truncate(server_mac), 0, 0, 0, INSERT, SUCCESS));
       endmethod

       method Action display(Bit#(32) serverIdx);
           scheduler1.request.put
                 (makeSchedReqRes(0, 0, 0, 0, truncate(serverIdx), DISPLAY, SUCCESS));
       endmethod

       method Action start_scheduler();
           scheduler1.request.put
                           (makeSchedReqRes(0, 0, 0, 0, 0, STARTSCHED, SUCCESS));
       endmethod

       method Action stop_scheduler();
           scheduler1.request.put(makeSchedReqRes(0, 0, 0, 0, 0, STOPSCHED, SUCCESS));
       endmethod

   `endif

   endinterface

endmodule
