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

module mkTest (Empty);

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
        scheduler[i] <- mkScheduler(i, txClock, txReset, rxClock, rxReset,
                                    clocked_by txClock, reset_by txReset);
    end

    Vector#(NUM_OF_SERVERS, DMASimulator) dma_sim;
    Vector#(NUM_OF_SERVERS, Mac) mac;

    for (Integer i = 0; i < fromInteger(valueof(NUM_OF_SERVERS)); i = i + 1)
    begin
        dma_sim[i] <- mkDMASimulator(i, scheduler[i], clocked_by txClock, reset_by txReset);
        mac[i] <- mkMac(i, scheduler, txClock, txReset, rxClock, rxReset,
                        clocked_by txClock, reset_by txReset);
    end


    Vector#(NUM_OF_SERVERS, Reg#(Addresses)) address
        <- replicateM(mkReg(defaultValue, clocked_by txClock, reset_by txReset));

    Reg#(Bit#(1)) loaded_ip <- mkReg(0, clocked_by txClock, reset_by txReset);
    Reg#(Bit#(1)) loaded_mac <- mkReg(0, clocked_by txClock, reset_by txReset);

    rule load_ip_addresses_into_register (loaded_ip == 0);
        loaded_ip <= 1;
        address[0].ip_addr <= 'hc0a80001;
        address[1].ip_addr <= 'hc0a80002;
        address[2].ip_addr <= 'hc0a80003;
        address[3].ip_addr <= 'hc0a80004;
        address[4].ip_addr <= 'hc0a80005;
        //address[5].ip_addr <= 'hc0a80006;
        //address[6].ip_addr <= 'hc0a80007;
        //address[7].ip_addr <= 'hc0a80008;
        //address[8].ip_addr <= 'hc0a80009;
        //address[9].ip_addr <= 'hc0a8000a;
    endrule

    rule load_mac_addresses_into_register (loaded_ip == 1 && loaded_mac == 0);
        loaded_mac <= 1;
        address[0].mac_addr <= 'hffab4859fbc4;
        address[1].mac_addr <= 'hab4673df3647;
        address[2].mac_addr <= 'h2947baffe64c;
        address[3].mac_addr <= 'h5bdc664dffee;
        address[4].mac_addr <= 'h85774bbcfeaa;
        //address[5].mac_addr <= 'h95babbdfe857;
        //address[6].mac_addr <= 'h7584bcaafe65;
        //address[7].mac_addr <= 'h1baeef3647af;
        //address[8].mac_addr <= 'hbcaffe43562b;
        //address[9].mac_addr <= 'hc64bafe66381;
    endrule

    Vector#(NUM_OF_SERVERS, Reg#(AddrIndex)) count
              <- replicateM(mkReg(fromInteger(valueof(NUM_OF_SERVERS)),
                                  clocked_by txClock, reset_by txReset));

    Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) done_populating_table
                    <- replicateM(mkReg(0, clocked_by txClock, reset_by txReset));

    Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) once
                    <- replicateM(mkReg(0, clocked_by txClock, reset_by txReset));

    Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) stop
                    <- replicateM(mkReg(0, clocked_by txClock, reset_by txReset));

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
        endrule

        rule consume_res;
            let res <- scheduler[i].insert_response.get;
        endrule

        rule set_start_time (done_populating_table[i] == 1);
            done_populating_table[i] <= 0;
            scheduler[i].request.put(makeSchedReqRes(0, 0, 20, 0, 0, SETTIME, SUCCESS));
        endrule

        rule set_start_interval;
            let res <- scheduler[i].settime_response.get;
            scheduler[i].request.put
                        (makeSchedReqRes(0, 0, 0, 10, 0, SETINTERVAL, SUCCESS));
        endrule

        rule start_scheduler_dma_mac (once[i] == 0);
            let res <- scheduler[i].setinterval_response.get;
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

    Reg#(Bit#(64)) counter <- mkReg(0, clocked_by txClock, reset_by txReset);

    rule clk (once[0] == 1
             && once[1] == 1
             && once[2] == 1
             && once[3] == 1
             && once[4] == 1
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
            end
        end
    endrule

endmodule

