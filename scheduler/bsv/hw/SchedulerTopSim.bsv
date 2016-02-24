import FIFO::*;
import FIFOF::*;
import Pipe::*;
import Vector::*;
import GetPut::*;
import Connectable::*;
import DefaultValue::*;
import Clocks::*;

import DMASimulator::*;
import Mac::*;
import SchedulerTypes::*;
import Scheduler::*;
import RingBufferTypes::*;
import RingBuffer::*;
import Addresses::*;

import AlteraMacWrap::*;
import EthMac1::*;

interface SchedulerTopSimIndication;
	method Action display_time_slots_count(Bit#(64) num_of_time_slots);
	method Action display_host_pkt_count(Bit#(64) num_of_host_pkt);
	method Action display_non_host_pkt_count(Bit#(64) num_of_non_host_pkt);
	method Action display_received_pkt_count(Bit#(64) num_of_received_pkt);
	method Action display_rxWrite_pkt_count(Bit#(64) num_of_rxWrite_pkt);
	method Action display_dma_stats(Bit#(64) num_of_pkt_generated);
	method Action display_mac_send_count(Bit#(64) count);
    method Action display_sop_count_from_mac_rx(Bit#(64) count);
    method Action display_eop_count_from_mac_rx(Bit#(64) count);
	method Action display_queue_0_stats(Vector#(16, Bit#(64)) queue0_stats);
	method Action display_queue_1_stats(Vector#(16, Bit#(64)) queue1_stats);
	method Action display_queue_2_stats(Vector#(16, Bit#(64)) queue2_stats);
	method Action display_queue_3_stats(Vector#(16, Bit#(64)) queue3_stats);
//	method Action debug_dma(Bit#(32) dst_index);
//	method Action debug_sched(Bit#(8) sop, Bit#(8) eop, Bit#(64) data_high,
//	                          Bit#(64) data_low);
//	method Action debug_mac_tx(Bit#(8) sop, Bit#(8) eop, Bit#(64) data);
//	method Action debug_mac_rx(Bit#(8) sop, Bit#(8) eop, Bit#(64) data);
endinterface

interface SchedulerTopSimRequest;
    method Action start_scheduler_and_dma(Bit#(32) idx,
		                                  Bit#(32) dma_transmission_rate,
		                                  Bit#(64) cycles);
	method Action debug();
endinterface

interface SchedulerTopSim;
    interface SchedulerTopSimRequest request2;
    interface `PinType pins;
endinterface

module mkSchedulerTopSim#(SchedulerTopSimIndication indication2)(SchedulerTopSim);
    // Clocks
    Clock defaultClock <- exposeCurrentClock();
    Reset defaultReset <- exposeCurrentReset();

    Clock txClock <- mkAbsoluteClock(0, 64);
    Reset txReset <- mkAsyncReset(2, defaultReset, txClock);

    Vector#(NUM_OF_ALTERA_PORTS, Clock) rxClock;
    Vector#(NUM_OF_ALTERA_PORTS, Reset) rxReset;

	for (Integer i = 0; i < valueOf(NUM_OF_ALTERA_PORTS); i = i + 1)
	begin
		rxClock[i] <- mkAbsoluteClock(0, 64);
		rxReset[i] <- mkAsyncReset(2, defaultReset, rxClock[i]);
	end

/*-------------------------------------------------------------------------------*/
    Vector#(NUM_OF_SERVERS,
            Scheduler#(ReadReqType, ReadResType, WriteReqType, WriteResType))
    scheduler <- replicateM(mkScheduler(defaultClock, defaultReset,
	                        txClock, txReset, rxClock, rxReset,
                            clocked_by txClock, reset_by txReset));

    Vector#(NUM_OF_SERVERS, DMASimulator) dma_sim;
    Vector#(NUM_OF_SERVERS, Mac) mac;

    for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
    begin
        dma_sim[i] <- mkDMASimulator(scheduler[i], defaultClock, defaultReset,
								         clocked_by txClock, reset_by txReset);
        mac[i] <- mkMac(scheduler[i], txClock, txReset, txReset,
                                         rxClock, rxReset, rxReset);

    end

/*-------------------------------------------------------------------------------*/
	Reg#(Bit#(1)) debug_flag <- mkReg(0);

	SyncFIFOIfc#(Bit#(64)) num_of_cycles_to_run_dma_for_fifo
	                      <- mkSyncFIFO(1, defaultClock, defaultReset, txClock);
    Reg#(Bit#(64)) num_of_cycles_to_run_dma_for <- mkReg(0, clocked_by txClock,
                                                            reset_by txReset);

	rule deq_num_of_cycles_to_run_dma_for;
		let x <- toGet(num_of_cycles_to_run_dma_for_fifo).get;
		num_of_cycles_to_run_dma_for <= x;
	endrule

    Reg#(Bit#(1)) start_counting <- mkReg(0, clocked_by txClock, reset_by txReset);
    Reg#(Bit#(64)) counter <- mkReg(0, clocked_by txClock, reset_by txReset);

	Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) get_dma_stats_flag
	            <- replicateM(mkReg(0, clocked_by txClock, reset_by txReset));
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) get_time_slots_flag
	            <- replicateM(mkReg(0, clocked_by txClock, reset_by txReset));
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) get_host_pkt_flag
	            <- replicateM(mkReg(0, clocked_by txClock, reset_by txReset));
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) get_non_host_pkt_flag
	            <- replicateM(mkReg(0, clocked_by txClock, reset_by txReset));
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) get_received_pkt_flag
	            <- replicateM(mkReg(0, clocked_by txClock, reset_by txReset));
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) get_rxWrite_pkt_flag
	            <- replicateM(mkReg(0, clocked_by txClock, reset_by txReset));
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) get_fwd_queue_stats_flag
	            <- replicateM(mkReg(0, clocked_by txClock, reset_by txReset));
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) get_mac_send_count_flag
	            <- replicateM(mkReg(0, clocked_by txClock, reset_by txReset));
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) get_sop_count_flag
	      <- replicateM(mkReg(0, clocked_by rxClock[0], reset_by rxReset[0]));
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) get_eop_count_flag
	        <- replicateM(mkReg(0, clocked_by rxClock[0], reset_by rxReset[0]));
    Vector#(NUM_OF_SERVERS, SyncFIFOIfc#(Bit#(1))) mac_rx_debug_fifo
                <- replicateM(mkSyncFIFO(1, txClock, txReset, rxClock[0]));

    /* This rule is to configure when to stop the DMA and collect stats */
    rule count_cycles (start_counting == 1);
        if (counter == num_of_cycles_to_run_dma_for)
        begin
            for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
            begin
			    dma_sim[i].stop();
			    scheduler[i].stop();
                get_dma_stats_flag[i] <= 1;
            end

			/* reset state */
			counter <= 0;
			start_counting <= 0;
        end
		else
			counter <= counter + 1;
    endrule

    for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
    begin
        rule get_dma_statistics (get_dma_stats_flag[i] == 1);
            dma_sim[i].getDMAStats();
            get_dma_stats_flag[i] <= 0;
            get_time_slots_flag[i] <= 1;
        endrule

        rule get_time_slot_statistics (get_time_slots_flag[i] == 1);
            scheduler[i].timeSlotsCount();
            get_time_slots_flag[i] <= 0;
            get_host_pkt_flag[i] <= 1;
        endrule

        rule get_host_pkt_statistics (get_host_pkt_flag[i] == 1);
            scheduler[i].hostPktCount();
            get_host_pkt_flag[i] <= 0;
            get_non_host_pkt_flag[i] <= 1;
        endrule

        rule get_non_host_pkt_statistics (get_non_host_pkt_flag[i] == 1);
            scheduler[i].nonHostPktCount();
            get_non_host_pkt_flag[i] <= 0;
            get_received_pkt_flag[i] <= 1;
        endrule

        rule get_received_pkt_statistics (get_received_pkt_flag[i] == 1);
            scheduler[i].receivedPktCount();
            get_received_pkt_flag[i] <= 0;
            get_rxWrite_pkt_flag[i] <= 1;
        endrule

        rule get_rxWrite_pkt_statistics (get_rxWrite_pkt_flag[i] == 1);
            scheduler[i].rxWritePktCount();
            get_rxWrite_pkt_flag[i] <= 0;
            get_mac_send_count_flag[i] <= 1;
        endrule

        rule get_mac_send_count (get_mac_send_count_flag[i] == 1);
            get_mac_send_count_flag[i] <= 0;
            //mac[i].getMacSendCountForPort0();
            get_fwd_queue_stats_flag[i] <= 1;
        endrule

        rule get_fwd_queue_statistics (get_fwd_queue_stats_flag[i] == 1);
            scheduler[i].fwdQueueLen();
            get_fwd_queue_stats_flag[i] <= 0;
            mac_rx_debug_fifo[i].enq(1);
        endrule

        rule deq_from_mac_rx_debug_fifo;
            let res <- toGet(mac_rx_debug_fifo[i]).get;
            get_sop_count_flag[i] <= 1;
        endrule

        rule get_sop_count (get_sop_count_flag[i] == 1);
            //mac[i].getSOPCountForPort0();
            get_sop_count_flag[i] <= 0;
            get_eop_count_flag[i] <= 1;
        endrule

        rule get_eop_count (get_eop_count_flag[i] == 1);
            //mac[i].getEOPCountForPort0();
            get_eop_count_flag[i] <= 0;
        endrule
    end

/*------------------------------------------------------------------------------*/
	// Start DMA and Scheduler

	SyncFIFOIfc#(Bit#(32)) dma_transmission_rate_fifo
	         <- mkSyncFIFO(1, defaultClock, defaultReset, txClock);

	SyncFIFOIfc#(ServerIndex) num_of_servers_fifo
	         <- mkSyncFIFO(1, defaultClock, defaultReset, txClock);

	SyncFIFOIfc#(ServerIndex) host_index_fifo
	         <- mkSyncFIFO(1, defaultClock, defaultReset, txClock);

	Vector#(NUM_OF_SERVERS, Reg#(ServerIndex))
          host_index <- replicateM(mkReg(0, clocked_by txClock, reset_by txReset));
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(32)))
      dma_trans_rate <- replicateM(mkReg(0, clocked_by txClock, reset_by txReset));
	Vector#(NUM_OF_SERVERS, Reg#(ServerIndex))
      num_of_servers <- replicateM(mkReg(0, clocked_by txClock, reset_by txReset));

	Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) host_index_ready <- replicateM(mkReg(0,
	                                       clocked_by txClock, reset_by txReset));
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) dma_trans_rate_ready
                    <- replicateM(mkReg(0, clocked_by txClock, reset_by txReset));
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) num_of_servers_ready
                    <- replicateM(mkReg(0, clocked_by txClock, reset_by txReset));

	rule deq_from_host_index_fifo;
		let x <- toGet(host_index_fifo).get;
        for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
        begin
		    host_index[i] <= fromInteger(i);
		    host_index_ready[i] <= 1;
        end
	endrule

	rule deq_from_dma_transmission_rate_fifo;
		let x <- toGet(dma_transmission_rate_fifo).get;
        for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
        begin
		    dma_trans_rate[i] <= x;
		    dma_trans_rate_ready[i] <= 1;
        end
	endrule

	rule deq_from_num_of_servers_fifo;
		let x <- toGet(num_of_servers_fifo).get;
        for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
        begin
		    num_of_servers[i] <= x;
		    num_of_servers_ready[i] <= 1;
        end
	endrule

	Vector#(NUM_OF_SERVERS, Reg#(ServerIndex))
            count <- replicateM(mkReg(fromInteger(valueof(NUM_OF_SERVERS)),
                                    clocked_by txClock, reset_by txReset));
	Vector#(NUM_OF_SERVERS, Reg#(ServerIndex))
        table_idx <- replicateM(mkReg(0, clocked_by txClock, reset_by txReset));
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(1)))
        done_populating_table <- replicateM(mkReg(0, clocked_by txClock,
                                                     reset_by txReset));

    for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
    begin
        rule populate_sched_table (count[i] > 0 && host_index_ready[i] == 1);
            ServerIndex idx = (count[i] + fromInteger(i)) %
                                       fromInteger(valueof(NUM_OF_SERVERS));
            scheduler[i].insertToSchedTable
                          (table_idx[i], ip_address(idx), mac_address(idx));
            table_idx[i] <= table_idx[i] + 1;
            count[i] <= count[i] - 1;
            if (count[i] == 1)
                done_populating_table[i] <= 1;
        endrule

        rule start_dma (done_populating_table[i] == 1
                        && host_index_ready[i] == 1 && dma_trans_rate_ready[i] == 1
                        && num_of_servers_ready[i] == 1);
            if (dma_trans_rate[i] != 0)
                dma_sim[i].start(host_index[i],
                                 dma_trans_rate[i],
                                 num_of_servers[i]);
            scheduler[i].start(host_index[i]);
            if (i==0)
                start_counting <= 1;

            /* reset the state */
            host_index_ready[i] <= 0;
            dma_trans_rate_ready[i] <= 0;
            num_of_servers_ready[i] <= 0;
            count[i] <= fromInteger(valueof(NUM_OF_SERVERS));
            table_idx[i] <= 0;
            done_populating_table[i] <= 0;
        endrule
    end

/*------------------------------------------------------------------------------*/
    /* Simulating connection wires via SyncFIFOs */

    SyncFIFOIfc#(Bit#(72)) wire_fifo_0_0 <- mkSyncFIFO(16, txClock, txReset, rxClock[0]);
    SyncFIFOIfc#(Bit#(72)) wire_fifo_0_1 <- mkSyncFIFO(16, txClock, txReset, rxClock[0]);
    SyncFIFOIfc#(Bit#(72)) wire_fifo_0_2 <- mkSyncFIFO(16, txClock, txReset, rxClock[0]);

    SyncFIFOIfc#(Bit#(72)) wire_fifo_1_0 <- mkSyncFIFO(16, txClock, txReset, rxClock[0]);
    SyncFIFOIfc#(Bit#(72)) wire_fifo_1_1 <- mkSyncFIFO(16, txClock, txReset, rxClock[1]);
    SyncFIFOIfc#(Bit#(72)) wire_fifo_1_2 <- mkSyncFIFO(16, txClock, txReset, rxClock[1]);

    SyncFIFOIfc#(Bit#(72)) wire_fifo_2_0 <- mkSyncFIFO(16, txClock, txReset, rxClock[1]);
    SyncFIFOIfc#(Bit#(72)) wire_fifo_2_1 <- mkSyncFIFO(16, txClock, txReset, rxClock[1]);
    SyncFIFOIfc#(Bit#(72)) wire_fifo_2_2 <- mkSyncFIFO(16, txClock, txReset, rxClock[2]);

    SyncFIFOIfc#(Bit#(72)) wire_fifo_3_0 <- mkSyncFIFO(16, txClock, txReset, rxClock[2]);
    SyncFIFOIfc#(Bit#(72)) wire_fifo_3_1 <- mkSyncFIFO(16, txClock, txReset, rxClock[2]);
    SyncFIFOIfc#(Bit#(72)) wire_fifo_3_2 <- mkSyncFIFO(16, txClock, txReset, rxClock[2]);

    rule tx_rule_0_0;
        let v = mac[0].tx(0);
        wire_fifo_0_0.enq(v);
    endrule

    rule tx_rule_0_1;
        let v = mac[0].tx(1);
        wire_fifo_0_1.enq(v);
    endrule

    rule tx_rule_0_2;
        let v = mac[0].tx(2);
        wire_fifo_0_2.enq(v);
    endrule

    rule tx_rule_1_0;
        let v = mac[1].tx(0);
        wire_fifo_1_0.enq(v);
    endrule

    rule tx_rule_1_1;
        let v = mac[1].tx(1);
        wire_fifo_1_1.enq(v);
    endrule

    rule tx_rule_1_2;
        let v = mac[1].tx(2);
        wire_fifo_1_2.enq(v);
    endrule

    rule tx_rule_2_0;
        let v = mac[2].tx(0);
        wire_fifo_2_0.enq(v);
    endrule

    rule tx_rule_2_1;
        let v = mac[2].tx(1);
        wire_fifo_2_1.enq(v);
    endrule

    rule tx_rule_2_2;
        let v = mac[2].tx(2);
        wire_fifo_2_2.enq(v);
    endrule

    rule tx_rule_3_0;
        let v = mac[3].tx(0);
        wire_fifo_3_0.enq(v);
    endrule

    rule tx_rule_3_1;
        let v = mac[3].tx(1);
        wire_fifo_3_1.enq(v);
    endrule

    rule tx_rule_3_2;
        let v = mac[3].tx(2);
        wire_fifo_3_2.enq(v);
    endrule

    rule rx_rule_0_0;
        let v <- toGet(wire_fifo_1_0).get;
        mac[0].rx(0, v);
        //$display("Getting from (1, 0) to (0, 0)");
    endrule

    rule rx_rule_0_1;
        let v <- toGet(wire_fifo_2_0).get;
        mac[0].rx(1, v);
        //$display("Getting from (2, 0) to (0, 1)");
    endrule

    rule rx_rule_0_2;
        let v <- toGet(wire_fifo_3_0).get;
        mac[0].rx(2, v);
        //$display("Getting from (3, 0) to (0, 2)");
    endrule

    rule rx_rule_1_0;
        let v <- toGet(wire_fifo_0_0).get;
        mac[1].rx(0, v);
        //$display("Getting from (0, 0) to (1, 0)");
    endrule

    rule rx_rule_1_1;
        let v <- toGet(wire_fifo_2_1).get;
        mac[1].rx(1, v);
        //$display("Getting from (2, 1) to (1, 1)");
    endrule

    rule rx_rule_1_2;
        let v <- toGet(wire_fifo_3_1).get;
        mac[1].rx(2, v);
        //$display("Getting from (3, 1) to (1, 2)");
    endrule

    rule rx_rule_2_0;
        let v <- toGet(wire_fifo_0_1).get;
        mac[2].rx(0, v);
        //$display("Getting from (0, 1) to (2, 0)");
    endrule

    rule rx_rule_2_1;
        let v <- toGet(wire_fifo_1_1).get;
        mac[2].rx(1, v);
        //$display("Getting from (1, 1) to (2, 1)");
    endrule

    rule rx_rule_2_2;
        let v <- toGet(wire_fifo_3_2).get;
        mac[2].rx(2, v);
        //$display("Getting from (3, 2) to (2, 2)");
    endrule

    rule rx_rule_3_0;
        let v <- toGet(wire_fifo_0_2).get;
        mac[3].rx(0, v);
        //$display("Getting from (0, 2) to (3, 0)");
    endrule

    rule rx_rule_3_1;
        let v <- toGet(wire_fifo_1_2).get;
        mac[3].rx(1, v);
        //$display("Getting from (1, 2) to (3, 1)");
    endrule

    rule rx_rule_3_2;
        let v <- toGet(wire_fifo_2_2).get;
        mac[3].rx(2, v);
        //$display("Getting from (2, 2) to (3, 2)");
    endrule

/* ------------------------------------------------------------------------------
*                               INDICATION RULES
* ------------------------------------------------------------------------------*/
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(64))) time_slots_reg <- replicateM(mkReg(0));
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) fire_time_slots <- replicateM(mkReg(0));

    for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
    begin
        rule time_slots_rule;
            let res <- scheduler[i].time_slots_response.get;
            time_slots_reg[i] <= res;
            fire_time_slots[i] <= 1;
        endrule

        rule time_slots (fire_time_slots[i] == 1);
            fire_time_slots[i] <= 0;
            //indication2.display_time_slots_count(time_slots_reg);
            $display("[SCHED (%d)] TIME SLOTS = %d", i, time_slots_reg[i]);
        endrule
    end

/*------------------------------------------------------------------------------*/
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(64))) host_pkt_reg <- replicateM(mkReg(0));
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) fire_host_pkt <- replicateM(mkReg(0));

    for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
    begin
        rule host_pkt_rule;
            let res <- scheduler[i].host_pkt_response.get;
            host_pkt_reg[i] <= res;
            fire_host_pkt[i] <= 1;
        endrule

        rule host_pkt (fire_host_pkt[i] == 1);
            fire_host_pkt[i] <= 0;
            //indication2.display_host_pkt_count(host_pkt_reg);
            $display("[SCHED (%d)] HOST PKT = %d", i, host_pkt_reg[i]);
        endrule
    end

/*------------------------------------------------------------------------------*/
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(64))) non_host_pkt_reg<-replicateM(mkReg(0));
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) fire_non_host_pkt<-replicateM(mkReg(0));

    for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
    begin
        rule non_host_pkt_rule;
            let res <- scheduler[i].non_host_pkt_response.get;
            non_host_pkt_reg[i] <= res;
            fire_non_host_pkt[i] <= 1;
        endrule

        rule non_host_pkt (fire_non_host_pkt[i] == 1);
            fire_non_host_pkt[i] <= 0;
            //indication2.display_non_host_pkt_count(non_host_pkt_reg);
            $display("[SCHED (%d)] NON HOST PKT = %d", i, non_host_pkt_reg[i]);
        endrule
    end

/*------------------------------------------------------------------------------*/
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(64))) received_pkt_reg<-replicateM(mkReg(0));
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) fire_received_pkt<-replicateM(mkReg(0));

    for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
    begin
        rule received_pkt_rule;
            let res <- scheduler[i].received_pkt_response.get;
            received_pkt_reg[i] <= res;
            fire_received_pkt[i] <= 1;
        endrule

        rule received_pkt (fire_received_pkt[i] == 1);
            fire_received_pkt[i] <= 0;
            //indication2.display_received_pkt_count(received_pkt_reg);
            $display("[SCHED (%d)] RECEIVED PKT = %d", i, received_pkt_reg[i]);
        endrule
    end

/*------------------------------------------------------------------------------*/
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(64))) rxWrite_pkt_reg <-replicateM(mkReg(0));
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) fire_rxWrite_pkt <-replicateM(mkReg(0));

    for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
    begin
        rule rxWrite_pkt_rule;
            let res <- scheduler[i].rxWrite_pkt_response.get;
            rxWrite_pkt_reg[i] <= res;
            fire_rxWrite_pkt[i] <= 1;
        endrule

        rule rxWrite_pkt (fire_rxWrite_pkt[i] == 1);
            fire_rxWrite_pkt[i] <= 0;
            //indication2.display_rxWrite_pkt_count(rxWrite_pkt_reg);
            $display("[SCHED (%d)] PKT WRITTEN TO Rx = %d", i, rxWrite_pkt_reg[i]);
        endrule
    end

/*------------------------------------------------------------------------------*/
	Vector#(NUM_OF_SERVERS, Reg#(DMAStatsT))
              dma_stats_reg <- replicateM(mkReg(defaultValue));
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) fire_dma_stats <- replicateM(mkReg(0));

    for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
    begin
        rule dma_stats_rule;
            let res <- dma_sim[i].dma_stats_response.get;
            dma_stats_reg[i] <= res;
            fire_dma_stats[i] <= 1;
        endrule

        rule dma_stats (fire_dma_stats[i] == 1);
            fire_dma_stats[i] <= 0;
            //indication2.display_dma_stats(dma_stats_reg.pkt_count);
            $display("[SCHED (%d)] DMA PKT = %d", i, dma_stats_reg[i].pkt_count);
        endrule
    end

///*-----------------------------------------------------------------------------*/
//	FIFO#(ServerIndex) debug_dma_res_fifo <- mkSizedFIFO(8);
//	//Reg#(Bit#(1)) fire_debug_dma_res <- mkReg(0);
//	rule debug_dma_res_rule (debug_flag == 1);
//		let res <- dma_sim.debug_sending_pkt.get;
//		debug_dma_res_fifo.enq(res);
//	endrule
//
//	rule debug_dma_res (debug_flag == 1);
//		let res <-toGet(debug_dma_res_fifo).get;
//		indication2.debug_dma(zeroExtend(res));
//	endrule
//
///*-----------------------------------------------------------------------------*/
//	FIFO#(RingBufferDataT) debug_sched_res_fifo <- mkSizedFIFO(16);
//	//Reg#(Bit#(1)) fire_debug_sched_res <- mkReg(0);
//	rule debug_sched_res_rule (debug_flag == 1);
//		let res <- scheduler.debug_consuming_pkt.get;
//		debug_sched_res_fifo.enq(res);
//	endrule
//
//	rule debug_sched_res (debug_flag == 1);
//		let res <- toGet(debug_sched_res_fifo).get;
//		indication2.debug_sched(zeroExtend(res.sop),
//		                       zeroExtend(res.eop),
//	                           res.payload[127:64],
//							   res.payload[63:0]);
//	endrule
//
///*-----------------------------------------------------------------------------*/
//	FIFO#(PacketDataT#(64)) debug_mac_tx_res_fifo <- mkSizedFIFO(16);
//	//Reg#(Bit#(1)) fire_debug_mac_tx_res <- mkReg(0);
//	rule debug_mac_tx_res_rule (debug_flag == 1);
//		let res <- mac.debug_sending_to_phy.get;
//		debug_mac_tx_res_fifo.enq(res);
//	endrule
//
//	rule debug_mac_tx_res (debug_flag == 1);
//		let res <- toGet(debug_mac_tx_res_fifo).get;
//		indication2.debug_mac_tx(zeroExtend(res.sop),
//		                        zeroExtend(res.eop),
//		                        res.data);
//	endrule
//
///*-----------------------------------------------------------------------------*/
//	FIFO#(PacketDataT#(64)) debug_mac_rx_res_fifo <- mkSizedFIFO(16);
//	//Reg#(Bit#(1)) fire_debug_mac_rx_res <- mkReg(0);
//	rule debug_mac_rx_res_rule (debug_flag == 1);
//		let res <- mac.debug_received_from_phy.get;
//		debug_mac_rx_res_fifo.enq(res);
//	endrule
//
//	rule debug_mac_rx_res (debug_flag == 1);
//		let res <- toGet(debug_mac_rx_res_fifo).get;
//		indication2.debug_mac_rx(zeroExtend(res.sop),
//		                        zeroExtend(res.eop),
//		                        res.data);
//	endrule
/*-----------------------------------------------------------------------------*/
	Vector#(NUM_OF_SERVERS,Reg#(Bit#(64)))mac_send_count_reg<-replicateM(mkReg(0));
	Vector#(NUM_OF_SERVERS,Reg#(Bit#(1)))fire_mac_send_counter_res<-replicateM(mkReg(0));

    for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
    begin
        rule mac_send_counter_rule (debug_flag == 1);
            let res <- mac[i].mac_send_count_port_0.get;
            mac_send_count_reg[i] <= res;
            fire_mac_send_counter_res[i] <= 1;
        endrule

        rule mac_send_counter_res (debug_flag == 1
                                   && fire_mac_send_counter_res[i] == 1);
            fire_mac_send_counter_res[i] <= 0;
            //indication2.display_mac_send_count(mac_send_count_reg);
            $display("[SCHED (%d)] MAC send = %d", i, mac_send_count_reg[i]);
        endrule
    end

/*-----------------------------------------------------------------------------*/
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(64))) sop_count_reg <- replicateM(mkReg(0));
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) fire_sop_counter_res <- replicateM(mkReg(0));

    for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
    begin
        rule sop_counter_rule (debug_flag == 1);
            let res <- mac[i].sop_count_port_0.get;
            sop_count_reg[i] <= res;
            fire_sop_counter_res[i] <= 1;
        endrule

        rule sop_counter_res (debug_flag == 1 && fire_sop_counter_res[i] == 1);
            fire_sop_counter_res[i] <= 0;
            //indication2.display_sop_count_from_mac_rx(sop_count_reg);
            $display("[SCHED (%d)] sop = %d", i, sop_count_reg[i]);
        endrule
    end

/*-----------------------------------------------------------------------------*/
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(64))) eop_count_reg <- replicateM(mkReg(0));
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) fire_eop_counter_res <- replicateM(mkReg(0));

    for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
    begin
        rule eop_counter_rule (debug_flag == 1);
            let res <- mac[i].eop_count_port_0.get;
            eop_count_reg[i] <= res;
            fire_eop_counter_res[i] <= 1;
        endrule

        rule eop_counter_res (debug_flag == 1 && fire_eop_counter_res[i] == 1);
            fire_eop_counter_res[i] <= 0;
            //indication2.display_eop_count_from_mac_rx(eop_count_reg);
            $display("[SCHED (%d)] eop = %d", i, eop_count_reg[i]);
        endrule
    end

/*------------------------------------------------------------------------------*/
	Vector#(NUM_OF_SERVERS,
            Vector#(NUM_OF_SERVERS, Vector#(RING_BUFFER_SIZE, Reg#(Bit#(64)))))
            fwd_queue_len_reg <- replicateM(replicateM(replicateM(mkReg(0))));
	Vector#(NUM_OF_SERVERS, Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))))
            fire_fwd_queue_len <- replicateM(replicateM(mkReg(0)));
	Vector#(NUM_OF_SERVERS, Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))))
            start_sending <- replicateM(replicateM(mkReg(0)));

    Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) rdy;
    for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
    begin
        if (i == 0)
            rdy[i] <- mkReg(1);
        else
            rdy[i] <- mkReg(0);
    end

    for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
    begin
        for (Integer j = 0; j < valueOf(NUM_OF_SERVERS); j = j + 1)
        begin
            rule fwd_queue_len_rule (rdy[i] == 1);
                let res <- scheduler[i].fwd_queue_len[j].get;
                for (Integer k = 0; k < valueOf(RING_BUFFER_SIZE); k = k + 1)
                    fwd_queue_len_reg[i][j][k] <= res[k];
                fire_fwd_queue_len[i][j] <= 1;
                if (j == 0)
                    start_sending[i][j] <= 1;
            endrule

            rule send_fwd_queue_len (fire_fwd_queue_len[i][j] == 1
                                     && start_sending[i][j] == 1);
                fire_fwd_queue_len[i][j] <= 0;
                start_sending[i][j] <= 0;
                $display("[SCHED (%d)] FWD QUEUE %d", i, j);
                Vector#(RING_BUFFER_SIZE, Bit#(64)) temp = replicate(0);
                for (Integer k = 0; k < valueof(RING_BUFFER_SIZE); k = k + 1)
                begin
                    temp[k] = fwd_queue_len_reg[i][j][k];
                    $display("%d", temp[k]);
                end

                if (j < (valueof(NUM_OF_SERVERS)-1))
                    start_sending[i][j+1] <= 1;

                else if (j == (valueof(NUM_OF_SERVERS)-1)
                         && i < (valueof(NUM_OF_SERVERS)-1))
                begin
                    rdy[i+1] <= 1;
                    rdy[i] <= 0;
                end
            endrule
        end
    end

/* ------------------------------------------------------------------------------
*                               INTERFACE METHODS
* ------------------------------------------------------------------------------*/
	Reg#(ServerIndex) host_index_reg <- mkReg(0);
	Reg#(Bit#(32)) dma_transmission_rate_reg <- mkReg(0);
	Reg#(Bit#(64)) cycles_reg <- mkReg(0);
	Reg#(ServerIndex) num_of_servers_reg <- mkReg(0);

    Reg#(Bit#(1)) fire_start_scheduler_and_dma_req <- mkReg(0);

	rule start_scheduler_and_dma_req (fire_start_scheduler_and_dma_req == 1);
		fire_start_scheduler_and_dma_req <= 0;
		dma_transmission_rate_fifo.enq(dma_transmission_rate_reg);
		num_of_cycles_to_run_dma_for_fifo.enq(cycles_reg);
		host_index_fifo.enq(host_index_reg);
		num_of_servers_fifo.enq(num_of_servers_reg);
	endrule

    interface SchedulerTopSimRequest request2;
        method Action start_scheduler_and_dma(Bit#(32) idx,
			                                  Bit#(32) dma_transmission_rate,
											  Bit#(64) cycles);
			host_index_reg <= truncate(idx);
			cycles_reg <= cycles;
			if (dma_transmission_rate <= 10)
			begin
				num_of_servers_reg <= 0;
				dma_transmission_rate_reg <= dma_transmission_rate;
			end
			else
			begin
				num_of_servers_reg <= truncate(dma_transmission_rate - 10);
				dma_transmission_rate_reg <= 10;
			end
            fire_start_scheduler_and_dma_req <= 1;
        endmethod

		method Action debug();
			debug_flag <= 1;
		endmethod
    endinterface

endmodule
