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
import EthMac::*;

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
    MakeResetIfc tx_reset_ifc <- mkResetSync(0, False, defaultClock);
    Reset tx_rst_sig <- mkAsyncReset(0, tx_reset_ifc.new_rst, txClock);
    Reset tx_rst <- mkResetEither(txReset, tx_rst_sig, clocked_by txClock);

    Vector#(NUM_OF_ALTERA_PORTS, MakeResetIfc) rx_reset_ifc;
    Vector#(NUM_OF_ALTERA_PORTS, Reset) rx_rst_sig;
    Vector#(NUM_OF_ALTERA_PORTS, Reset) rx_rst;

    for (Integer i = 0; i < valueof(NUM_OF_ALTERA_PORTS); i = i + 1)
    begin
        rx_reset_ifc[i] <- mkResetSync(0, False, defaultClock);
        rx_rst_sig[i] <- mkAsyncReset(0, rx_reset_ifc[i].new_rst, rxClock[i]);
        rx_rst[i] <- mkResetEither(rxReset[i], rx_rst_sig[i], clocked_by rxClock[i]);
    end

    Scheduler#(ReadReqType, ReadResType, WriteReqType, WriteResType)
    scheduler <- mkScheduler(defaultClock, defaultReset,
	                         txClock, txReset, rxClock, rxReset,
                             clocked_by txClock, reset_by tx_rst);

    DMASimulator dma_sim <- mkDMASimulator(scheduler, defaultClock, defaultReset,
								     clocked_by txClock, reset_by tx_rst);

    Mac mac <- mkMac(scheduler, txClock, txReset, tx_rst, rxClock, rxReset, rx_rst);

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

	Reg#(Bit#(1)) get_dma_stats_flag
	                    <- mkReg(0, clocked_by txClock, reset_by txReset);
	Reg#(Bit#(1)) get_time_slots_flag
	                    <- mkReg(0, clocked_by txClock, reset_by txReset);
	Reg#(Bit#(1)) get_host_pkt_flag
	                    <- mkReg(0, clocked_by txClock, reset_by txReset);
	Reg#(Bit#(1)) get_non_host_pkt_flag
	                    <- mkReg(0, clocked_by txClock, reset_by txReset);
	Reg#(Bit#(1)) get_received_pkt_flag
	                    <- mkReg(0, clocked_by txClock, reset_by txReset);
	Reg#(Bit#(1)) get_rxWrite_pkt_flag
	                    <- mkReg(0, clocked_by txClock, reset_by txReset);
	Reg#(Bit#(1)) get_fwd_queue_stats_flag
	                    <- mkReg(0, clocked_by txClock, reset_by txReset);
	Reg#(Bit#(1)) get_mac_send_count_flag
	                    <- mkReg(0, clocked_by txClock, reset_by txReset);
	Reg#(Bit#(1)) get_sop_count_flag
	                    <- mkReg(0, clocked_by rxClock[0], reset_by rxReset[0]);
	Reg#(Bit#(1)) get_eop_count_flag
	                    <- mkReg(0, clocked_by rxClock[0], reset_by rxReset[0]);
    SyncFIFOIfc#(Bit#(1)) mac_rx_debug_fifo
                        <- mkSyncFIFO(1, txClock, txReset, rxClock[0]);

    /* This rule is to configure when to stop the DMA and collect stats */
    rule count_cycles (start_counting == 1);
        if (counter == num_of_cycles_to_run_dma_for)
        begin
			dma_sim.stop();
			scheduler.stop();
			get_dma_stats_flag <= 1;

			/* reset state */
			counter <= 0;
			start_counting <= 0;
        end
		else
			counter <= counter + 1;
    endrule

	rule get_dma_statistics (get_dma_stats_flag == 1);
		dma_sim.getDMAStats();
		get_dma_stats_flag <= 0;
		get_time_slots_flag <= 1;
	endrule

	rule get_time_slot_statistics (get_time_slots_flag == 1);
		scheduler.timeSlotsCount();
		get_time_slots_flag <= 0;
		get_host_pkt_flag <= 1;
	endrule

	rule get_host_pkt_statistics (get_host_pkt_flag == 1);
		scheduler.hostPktCount();
		get_host_pkt_flag <= 0;
		get_non_host_pkt_flag <= 1;
	endrule

	rule get_non_host_pkt_statistics (get_non_host_pkt_flag == 1);
		scheduler.nonHostPktCount();
		get_non_host_pkt_flag <= 0;
		get_received_pkt_flag <= 1;
	endrule

	rule get_received_pkt_statistics (get_received_pkt_flag == 1);
		scheduler.receivedPktCount();
		get_received_pkt_flag <= 0;
		get_rxWrite_pkt_flag <= 1;
	endrule

	rule get_rxWrite_pkt_statistics (get_rxWrite_pkt_flag == 1);
		scheduler.rxWritePktCount();
		get_rxWrite_pkt_flag <= 0;
        get_mac_send_count_flag <= 1;
	endrule

	rule get_mac_send_count (get_mac_send_count_flag == 1);
		get_mac_send_count_flag <= 0;
		mac.getMacSendCountForPort0();
		get_fwd_queue_stats_flag <= 1;
	endrule

	rule get_fwd_queue_statistics (get_fwd_queue_stats_flag == 1);
		scheduler.fwdQueueLen();
		get_fwd_queue_stats_flag <= 0;
		mac_rx_debug_fifo.enq(1);
	endrule

    rule deq_from_mac_rx_debug_fifo;
        let res <- toGet(mac_rx_debug_fifo).get;
        get_sop_count_flag <= 1;
    endrule

    rule get_sop_count (get_sop_count_flag == 1);
        mac.getSOPCountForPort0();
        get_sop_count_flag <= 0;
        get_eop_count_flag <= 1;
    endrule

    rule get_eop_count (get_eop_count_flag == 1);
        mac.getEOPCountForPort0();
        get_eop_count_flag <= 0;
    endrule

/*------------------------------------------------------------------------------*/
	// Start DMA and Scheduler

	SyncFIFOIfc#(Bit#(32)) dma_transmission_rate_fifo
	         <- mkSyncFIFO(1, defaultClock, defaultReset, txClock);

	SyncFIFOIfc#(ServerIndex) num_of_servers_fifo
	         <- mkSyncFIFO(1, defaultClock, defaultReset, txClock);

	SyncFIFOIfc#(ServerIndex) host_index_fifo
	         <- mkSyncFIFO(1, defaultClock, defaultReset, txClock);

	Reg#(ServerIndex) host_index <- mkReg(0, clocked_by txClock, reset_by txReset);
	Reg#(Bit#(32)) dma_trans_rate <- mkReg(0, clocked_by txClock, reset_by txReset);
	Reg#(ServerIndex) num_of_servers <- mkReg(0, clocked_by txClock, reset_by txReset);

	Reg#(Bit#(1)) host_index_ready <- mkReg(0,
	                                       clocked_by txClock, reset_by txReset);
	Reg#(Bit#(1)) dma_trans_rate_ready <- mkReg(0,
                                           clocked_by txClock, reset_by txReset);
	Reg#(Bit#(1)) num_of_servers_ready <- mkReg(0,
                                           clocked_by txClock, reset_by txReset);

	rule deq_from_host_index_fifo;
		let x <- toGet(host_index_fifo).get;
		host_index <= x;
		host_index_ready <= 1;
	endrule

	rule deq_from_dma_transmission_rate_fifo;
		let x <- toGet(dma_transmission_rate_fifo).get;
		dma_trans_rate <= x;
		dma_trans_rate_ready <= 1;
	endrule

	rule deq_from_num_of_servers_fifo;
		let x <- toGet(num_of_servers_fifo).get;
		num_of_servers <= x;
		num_of_servers_ready <= 1;
	endrule

	Reg#(ServerIndex) count <- mkReg(fromInteger(valueof(NUM_OF_SERVERS)),
                                    clocked_by txClock, reset_by txReset);
	Reg#(ServerIndex) table_idx <- mkReg(0, clocked_by txClock, reset_by txReset);
	Reg#(Bit#(1)) done_populating_table <- mkReg(0, clocked_by txClock,
                                                        reset_by txReset);

	rule populate_sched_table (count > 0 && host_index_ready == 1);
		ServerIndex idx = (count + host_index) %
		                           fromInteger(valueof(NUM_OF_SERVERS));
		scheduler.insertToSchedTable(table_idx, ip_address(idx), mac_address(idx));
		table_idx <= table_idx + 1;
		count <= count - 1;
		if (count == 1)
			done_populating_table <= 1;
	endrule

	rule start_dma (done_populating_table == 1
		            && host_index_ready == 1 && dma_trans_rate_ready == 1
					&& num_of_servers_ready == 1);
        if (dma_trans_rate != 0)
		    dma_sim.start(host_index, dma_trans_rate, num_of_servers);
		scheduler.start(host_index);
		start_counting <= 1;

		/* reset the state */
		host_index_ready <= 0;
		dma_trans_rate_ready <= 0;
		count <= fromInteger(valueof(NUM_OF_SERVERS));
		table_idx <= 0;
		done_populating_table <= 0;
	endrule

/*------------------------------------------------------------------------------*/

/* ------------------------------------------------------------------------------
*                               INDICATION RULES
* ------------------------------------------------------------------------------*/
	Reg#(Bit#(64)) time_slots_reg <- mkReg(0);
	Reg#(Bit#(1)) fire_time_slots <- mkReg(0);
	rule time_slots_rule;
		let res <- scheduler.time_slots_response.get;
		time_slots_reg <= res;
		fire_time_slots <= 1;
	endrule

	rule time_slots (fire_time_slots == 1);
		fire_time_slots <= 0;
		indication2.display_time_slots_count(time_slots_reg);
	endrule

/*------------------------------------------------------------------------------*/
	Reg#(Bit#(64)) host_pkt_reg <- mkReg(0);
	Reg#(Bit#(1)) fire_host_pkt <- mkReg(0);
	rule host_pkt_rule;
		let res <- scheduler.host_pkt_response.get;
		host_pkt_reg <= res;
		fire_host_pkt <= 1;
	endrule

	rule host_pkt (fire_host_pkt == 1);
		fire_host_pkt <= 0;
		indication2.display_host_pkt_count(host_pkt_reg);
	endrule

/*------------------------------------------------------------------------------*/
	Reg#(Bit#(64)) non_host_pkt_reg <- mkReg(0);
	Reg#(Bit#(1)) fire_non_host_pkt <- mkReg(0);
	rule non_host_pkt_rule;
		let res <- scheduler.non_host_pkt_response.get;
		non_host_pkt_reg <= res;
		fire_non_host_pkt <= 1;
	endrule

	rule non_host_pkt (fire_non_host_pkt == 1);
		fire_non_host_pkt <= 0;
		indication2.display_non_host_pkt_count(non_host_pkt_reg);
	endrule

/*------------------------------------------------------------------------------*/
	Reg#(Bit#(64)) received_pkt_reg <- mkReg(0);
	Reg#(Bit#(1)) fire_received_pkt <- mkReg(0);
	rule received_pkt_rule;
		let res <- scheduler.received_pkt_response.get;
		received_pkt_reg <= res;
		fire_received_pkt <= 1;
	endrule

	rule received_pkt (fire_received_pkt == 1);
		fire_received_pkt <= 0;
		indication2.display_received_pkt_count(received_pkt_reg);
	endrule

/*------------------------------------------------------------------------------*/
	Reg#(Bit#(64)) rxWrite_pkt_reg <- mkReg(0);
	Reg#(Bit#(1)) fire_rxWrite_pkt <- mkReg(0);
	rule rxWrite_pkt_rule;
		let res <- scheduler.rxWrite_pkt_response.get;
		rxWrite_pkt_reg <= res;
		fire_rxWrite_pkt <= 1;
	endrule

	rule rxWrite_pkt (fire_rxWrite_pkt == 1);
		fire_rxWrite_pkt <= 0;
		indication2.display_rxWrite_pkt_count(rxWrite_pkt_reg);
	endrule

/*------------------------------------------------------------------------------*/
	Reg#(DMAStatsT) dma_stats_reg <- mkReg(defaultValue);
	Reg#(Bit#(1)) fire_dma_stats <- mkReg(0);
	rule dma_stats_rule;
		let res <- dma_sim.dma_stats_response.get;
		dma_stats_reg <= res;
		fire_dma_stats <= 1;
	endrule

	rule dma_stats (fire_dma_stats == 1);
		fire_dma_stats <= 0;
		indication2.display_dma_stats(dma_stats_reg.pkt_count);
	endrule

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
	Reg#(Bit#(64)) mac_send_count_reg <- mkReg(0);
	Reg#(Bit#(1)) fire_mac_send_counter_res <- mkReg(0);
	rule mac_send_counter_rule (debug_flag == 1);
		let res <- mac.mac_send_count_port_0.get;
		mac_send_count_reg <= res;
        fire_mac_send_counter_res <= 1;
	endrule

	rule mac_send_counter_res (debug_flag == 1 && fire_mac_send_counter_res == 1);
		fire_mac_send_counter_res <= 0;
		indication2.display_mac_send_count(mac_send_count_reg);
	endrule

/*-----------------------------------------------------------------------------*/
	Reg#(Bit#(64)) sop_count_reg <- mkReg(0);
	Reg#(Bit#(1)) fire_sop_counter_res <- mkReg(0);
	rule sop_counter_rule (debug_flag == 1);
		let res <- mac.sop_count_port_0.get;
		sop_count_reg <= res;
        fire_sop_counter_res <= 1;
	endrule

	rule sop_counter_res (debug_flag == 1 && fire_sop_counter_res == 1);
		fire_sop_counter_res <= 0;
		indication2.display_sop_count_from_mac_rx(sop_count_reg);
	endrule

/*-----------------------------------------------------------------------------*/
	Reg#(Bit#(64)) eop_count_reg <- mkReg(0);
	Reg#(Bit#(1)) fire_eop_counter_res <- mkReg(0);
	rule eop_counter_rule (debug_flag == 1);
		let res <- mac.eop_count_port_0.get;
		eop_count_reg <= res;
        fire_eop_counter_res <= 1;
	endrule

	rule eop_counter_res (debug_flag == 1 && fire_eop_counter_res == 1);
		fire_eop_counter_res <= 0;
		indication2.display_eop_count_from_mac_rx(eop_count_reg);
	endrule
/*------------------------------------------------------------------------------*/
	Vector#(NUM_OF_SERVERS, Vector#(RING_BUFFER_SIZE, Reg#(Bit#(64))))
		                   fwd_queue_len_reg <- replicateM(replicateM(mkReg(0)));
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) fire_fwd_queue_len
	                                                     <- replicateM(mkReg(0));
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) start_sending <- replicateM(mkReg(0));

	for (Integer i = 0; i < valueOf(NUM_OF_SERVERS); i = i + 1)
	begin
		rule fwd_queue_len_rule;
			let res <- scheduler.fwd_queue_len[i].get;
			for (Integer j = 0; j < valueOf(RING_BUFFER_SIZE); j = j + 1)
				fwd_queue_len_reg[i][j] <= res[j];
			fire_fwd_queue_len[i] <= 1;
			if (i == 0)
				start_sending[i] <= 1;
		endrule

		rule send_fwd_queue_len (fire_fwd_queue_len[i] == 1
			                     && start_sending[i] == 1);
			fire_fwd_queue_len[i] <= 0;
			start_sending[i] <= 0;
			Vector#(RING_BUFFER_SIZE, Bit#(64)) temp = replicate(0);
			for (Integer j = 0; j < valueof(RING_BUFFER_SIZE); j = j + 1)
				temp[j] = fwd_queue_len_reg[i][j];

			if (i == 0)
				indication2.display_queue_0_stats(temp);
			else if (i == 1)
				indication2.display_queue_1_stats(temp);
			else if (i == 2)
				indication2.display_queue_2_stats(temp);
			else if (i == 3)
				indication2.display_queue_3_stats(temp);

			if (i < (valueof(NUM_OF_SERVERS)-1))
				start_sending[i+1] <= 1;
		endrule
	end

/* ------------------------------------------------------------------------------
*                               INTERFACE METHODS
* ------------------------------------------------------------------------------*/
	Reg#(ServerIndex) host_index_reg <- mkReg(0);
	Reg#(Bit#(32)) dma_transmission_rate_reg <- mkReg(0);
	Reg#(Bit#(64)) cycles_reg <- mkReg(0);
	Reg#(ServerIndex) num_of_servers_reg <- mkReg(0);

	Reg#(Bit#(1)) fire_reset_state <- mkReg(0);
	Reg#(Bit#(1)) fire_start_scheduler_and_dma_req <- mkReg(0);

	Reg#(Bit#(64)) reset_len_count <- mkReg(0);
	rule reset_state (fire_reset_state == 1);
		tx_reset_ifc.assertReset;
        for (Integer i = 0; i < valueof(NUM_OF_ALTERA_PORTS); i = i + 1)
            rx_reset_ifc[i].assertReset;
		reset_len_count <= reset_len_count + 1;
		if (reset_len_count == 1000)
		begin
			fire_reset_state <= 0;
			fire_start_scheduler_and_dma_req <= 1;
		end
	endrule

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
			fire_reset_state <= 1;
			reset_len_count <= 0;
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
        endmethod

		method Action debug();
			debug_flag <= 1;
		endmethod
    endinterface

endmodule
