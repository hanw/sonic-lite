import FIFO::*;
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
   method Action display(Bit#(32) addrIdx);
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

    Vector#(NUM_OF_SERVERS,
            Scheduler#(SchedReqResType, SchedReqResType,
            ReadReqType, ReadResType, WriteReqType, WriteResType)) scheduler;


    for (Integer i = 0; i < fromInteger(valueof(NUM_OF_SERVERS)); i = i + 1)
    begin
        scheduler[i] <- mkScheduler(i, defaultClock, defaultReset,
                                       txClock, txReset, rxClock, rxReset);
    end

    Vector#(NUM_OF_SERVERS, DMASimulator) dma_sim;
    Vector#(NUM_OF_SERVERS, Mac) mac;

    for (Integer i = 0; i < fromInteger(valueof(NUM_OF_SERVERS)); i = i + 1)
    begin
        dma_sim[i] <- mkDMASimulator(i, scheduler[i]);
        mac[i] <- mkMac(i, scheduler, defaultClock, defaultReset,
                                      txClock, txReset, rxClock, rxReset);
    end


    Vector#(12, Reg#(Addresses)) address <- replicateM(mkReg(defaultValue));
    Reg#(Bit#(1)) loaded_ip <- mkReg(0);
    Reg#(Bit#(1)) loaded_mac <- mkReg(0);

    rule load_ip_addresses_into_register (loaded_ip == 0);
        loaded_ip <= 1;
        address[0].ip_addr <= 'hc0a80001;
        address[1].ip_addr <= 'hc0a80002;
//        address[2].ip_addr <= 'hc0a80003;
//        address[3].ip_addr <= 'hc0a80004;
//        address[4].ip_addr <= 'hc0a80005;
//        address[5].ip_addr <= 'hc0a80006;
//        address[6].ip_addr <= 'hc0a80007;
//        address[7].ip_addr <= 'hc0a80008;
//        address[8].ip_addr <= 'hc0a80009;
//        address[9].ip_addr <= 'hc0a8000a;
//        address[10].ip_addr <= 'hc0a8000b;
//        address[11].ip_addr <= 'hc0a8000c;
    endrule

    rule load_mac_addresses_into_register (loaded_ip == 1 && loaded_mac == 0);
        loaded_mac <= 1;
        address[0].mac_addr <= 'hffab4859fbc4;
        address[1].mac_addr <= 'hab4673df3647;
//        address[2].mac_addr <= 'h2947baffe64c;
//        address[3].mac_addr <= 'h5bdc664dffee;
//        address[4].mac_addr <= 'h85774bbcfeaa;
//        address[5].mac_addr <= 'h95babbdfe857;
//        address[6].mac_addr <= 'h7584bcaafe65;
//        address[7].mac_addr <= 'h1baeef3647af;
//        address[8].mac_addr <= 'hbcaffe43562b;
//        address[9].mac_addr <= 'hc64bafe66381;
//        address[10].mac_addr <= 'hd6b4392ba774;
//        address[11].mac_addr <= 'hefa553617bbc;
    endrule

    Vector#(NUM_OF_SERVERS, Reg#(AddrIndex)) count
              <- replicateM(mkReg(fromInteger(valueof(NUM_OF_SERVERS))));

    Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) done_populating_table
                                                 <- replicateM(mkReg(0));

    Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) once <- replicateM(mkReg(0));

    Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) stop <- replicateM(mkReg(0));

    for (Integer i = 0; i < fromInteger(valueof(NUM_OF_SERVERS)); i = i + 1)
    begin
        rule populate_sched_table (count[i] > 0 && loaded_ip == 1 && loaded_mac == 1);
            AddrIndex idx = (count[i] + fromInteger(i))
                                  % fromInteger(valueof(NUM_OF_SERVERS));
            scheduler[i].request.put(makeSchedReqRes(address[idx].ip_addr,
                                                     address[idx].mac_addr,
                                                     0, 0, idx, INSERT, SUCCESS));
            count[i] <= count[i] - 1;
            if (count[i] == 1)
                done_populating_table[i] <= 1;
            $display("[TEST (%d)] Populating table; idx = %d", i, idx);
        endrule

        rule consume_res;
            let res <- scheduler[i].insert_response.get;
        endrule

        rule set_start_time (done_populating_table[i] == 1);
            $display("[TEST (%d)] Setting time", i);
            done_populating_table[i] <= 0;
            scheduler[i].request.put(makeSchedReqRes(0, 0, 20, 0, 0, SETTIME, SUCCESS));
        endrule

        rule set_start_interval;
            let res <- scheduler[i].settime_response.get;
            $display("[TEST (%d)] Setting interval", i);
            scheduler[i].request.put
                        (makeSchedReqRes(0, 0, 0, 1000, 0, SETINTERVAL, SUCCESS));
        endrule

        rule start_scheduler_dma_mac (once[i] == 0);
            let res <- scheduler[i].setinterval_response.get;
            $display("[TEST (%d)] Starting scheduler, dma and mac", i);
            scheduler[i].request.put(makeSchedReqRes(0, 0, 0, 0, 0, STARTSCHED, SUCCESS));
            dma_sim[i].start();
            mac[i].start();
            once[i] <= 1;
        endrule

        rule stop_dma (stop[i] == 1);
            stop[i] <= 0;
            dma_sim[i].stop();
        endrule
    end

    Reg#(Bit#(64)) counter <- mkReg(0);

    rule clk (once[0] == 1
             && once[1] == 1
//             && once[2] == 1
//             && once[3] == 1
             && counter < 1000);
        counter <= counter + 1;
        if (counter == 10)
        begin
            for (Integer i = 0; i < fromInteger(valueof(NUM_OF_SERVERS)); i = i + 1)
                stop[i] <= 1;
        end
    endrule

`endif

`ifdef DEBUG_SCHEDULER

   Scheduler#(SchedReqResType, SchedReqResType,
              ReadReqType, ReadResType, WriteReqType, WriteResType)
        scheduler1 <- mkScheduler(0, defaultClock, defaultReset, txClock, txReset,
                                      rxClock, rxReset);

   Reg#(AddrIndex) addrIdx <- mkReg(0);
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

       method Action display(Bit#(32) addrIdx);
           scheduler1.request.put
                 (makeSchedReqRes(0, 0, 0, 0, truncate(addrIdx), DISPLAY, SUCCESS));
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
