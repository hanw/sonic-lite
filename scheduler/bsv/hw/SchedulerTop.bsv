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

import AlteraMacWrap::*;
import EthMac::*;
import EthPhy::*;
import AlteraEthPhy::*;
import DE5Pins::*;

interface SchedulerTopIndication;
	method Action display_time_slots_count(Bit#(64) num_of_time_slots);
	method Action display_host_pkt_count(Bit#(64) num_of_host_pkt);
	method Action display_non_host_pkt_count(Bit#(64) num_of_non_host_pkt);
	method Action display_received_pkt_count(Bit#(64) num_of_received_pkt);
	method Action display_unknown_pkt_count(Bit#(64) num_of_unknown_pkt);
	method Action display_dma_stats(Bit#(64) num_of_pkt_generated);
    method Action display_sop_count_from_mac_rx(Bit#(64) count);
    method Action display_eop_count_from_mac_rx(Bit#(64) count);
//	method Action debug_dma(Bit#(32) dst_index);
//	method Action debug_sched(Bit#(8) sop, Bit#(8) eop, Bit#(64) data_high,
//	                          Bit#(64) data_low);
//	method Action debug_mac_tx(Bit#(8) sop, Bit#(8) eop, Bit#(64) data);
//	method Action debug_mac_rx(Bit#(8) sop, Bit#(8) eop, Bit#(64) data);
endinterface

interface SchedulerTopRequest;
    method Action start_scheduler_and_dma(Bit#(32) idx,
		                                  Bit#(32) dma_transmission_rate,
		                                  Bit#(64) cycles);
	method Action debug();
endinterface

interface SchedulerTop;
    interface SchedulerTopRequest request;
    interface `PinType pins;
endinterface

module mkSchedulerTop#(SchedulerTopIndication indication)(SchedulerTop);
    // Clocks
    Clock defaultClock <- exposeCurrentClock();
    Reset defaultReset <- exposeCurrentReset();

//    Clock txClock <- mkAbsoluteClock(0, 64);
//    Reset txReset <- mkSyncReset(2, defaultReset, txClock);
//    Clock rxClock <- mkAbsoluteClock(0, 64);
//    Reset rxReset <- mkSyncReset(2, defaultReset, rxClock);

    Wire#(Bit#(1)) clk_644_wire <- mkDWire(0);
    Wire#(Bit#(1)) clk_50_wire <- mkDWire(0);
    De5Clocks clocks <- mkDe5Clocks(clk_50_wire, clk_644_wire);

    Clock txClock = clocks.clock_156_25;
    Clock phyClock = clocks.clock_644_53;
    Clock mgmtClock = clocks.clock_50;
    Reset txReset <- mkSyncReset(2, defaultReset, txClock);
    Reset phyReset <- mkSyncReset(2, defaultReset, phyClock);
    Reset mgmtReset <- mkSyncReset(2, defaultReset, mgmtClock);

    //DE5 Pins
    De5Leds leds <- mkDe5Leds(defaultClock, txClock, mgmtClock, phyClock);
    De5SfpCtrl#(4) sfpctrl <- mkDe5SfpCtrl();
    De5Buttons#(4) buttons <- mkDe5Buttons(clocked_by mgmtClock, reset_by mgmtReset);

    // Phy
    //EthPhyIfc phys <- mkAlteraEthPhy(defaultClock, phyClock, txClock, defaultReset);
    EthPhyIfc phys <- mkAlteraEthPhy(mgmtClock, phyClock, txClock, defaultReset, clocked_by mgmtClock, reset_by mgmtReset);
    DtpPhyIfc#(1) dtpPhy <- mkEthPhy(mgmtClock, txClock, phyClock, clocked_by mgmtClock, reset_by mgmtReset);

    Clock rxClock = phys.rx_clkout;
    Reset rxReset <- mkSyncReset(2, defaultReset, rxClock);

/*-------------------------------------------------------------------------------*/
    Scheduler#(ReadReqType, ReadResType, WriteReqType, WriteResType)
    scheduler <- mkScheduler(defaultClock, defaultReset,
	                         txClock, txReset, rxClock, rxReset,
                             clocked_by txClock, reset_by txReset);

    DMASimulator dma_sim <- mkDMASimulator(scheduler, defaultClock, defaultReset,
                            clocked_by txClock, reset_by txReset);

    Mac mac <- mkMac(scheduler, txClock, txReset, rxClock, rxReset);

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
	Reg#(Bit#(1)) get_unknown_pkt_flag
	                    <- mkReg(0, clocked_by txClock, reset_by txReset);
	Reg#(Bit#(1)) get_sop_count_flag
	                    <- mkReg(0, clocked_by rxClock, reset_by rxReset);
	Reg#(Bit#(1)) get_eop_count_flag
	                    <- mkReg(0, clocked_by rxClock, reset_by rxReset);
    SyncFIFOIfc#(Bit#(1)) mac_rx_debug_fifo
                        <- mkSyncFIFO(1, txClock, txReset, rxClock);
    /* This rule is to configure when to stop the DMA and collect stats */
    rule count_cycles (start_counting == 1);
        counter <= counter + 1;
        if (counter == num_of_cycles_to_run_dma_for)
        begin
			dma_sim.stop();
			scheduler.stop();
			start_counting <= 0;
			get_dma_stats_flag <= 1;
        end
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
		get_unknown_pkt_flag <= 1;
	endrule

	rule get_unknown_pkt_statistics (get_unknown_pkt_flag == 1);
		scheduler.unknownPktCount();
		get_unknown_pkt_flag <= 0;
        mac_rx_debug_fifo.enq(1);
	endrule

    rule deq_from_mac_rx_debug_fifo;
        let res <- toGet(mac_rx_debug_fifo).get;
        get_sop_count_flag <= 1;
    endrule

    rule get_sop_count (get_sop_count_flag == 1);
        mac.getSOPCount();
        get_sop_count_flag <= 0;
        get_eop_count_flag <= 1;
    endrule

    rule get_eop_count (get_eop_count_flag == 1);
        mac.getEOPCount();
        get_eop_count_flag <= 0;
    endrule

/*------------------------------------------------------------------------------*/
	// Start MAC rx

//	SyncFIFOIfc#(ServerIndex) host_index_fifo_mac
//	         <- mkSyncFIFO(1, defaultClock, defaultReset, rxClock);
//
//	Reg#(Bit#(1)) fire_once_1 <- mkReg(0, clocked_by rxClock, reset_by rxReset);
//	rule deq_from_host_index_fifo_mac (fire_once_1 == 0);
//		let x <- toGet(host_index_fifo_mac).get;
//		mac.start_mac_rx(x);
//		fire_once_1 <= 1;
//	endrule

/*------------------------------------------------------------------------------*/
	// Start DMA and Scheduler

	SyncFIFOIfc#(Bit#(32)) dma_transmission_rate_fifo
	         <- mkSyncFIFO(1, defaultClock, defaultReset, txClock);

	SyncFIFOIfc#(ServerIndex) host_index_fifo
	         <- mkSyncFIFO(1, defaultClock, defaultReset, txClock);

	Reg#(ServerIndex) host_index <- mkReg(0, clocked_by txClock, reset_by txReset);
	Reg#(Bit#(32)) dma_trans_rate <- mkReg(0, clocked_by txClock, reset_by txReset);

	Reg#(Bit#(1)) host_index_ready <- mkReg(0,
	                                       clocked_by txClock, reset_by txReset);
	Reg#(Bit#(1)) dma_trans_rate_ready <- mkReg(0,
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

	Reg#(Bit#(1)) fire_once <- mkReg(0, clocked_by txClock, reset_by txReset);
	rule start_dma (fire_once == 0 && done_populating_table == 1
		            && host_index_ready == 1 && dma_trans_rate_ready == 1);
        if (dma_trans_rate != 0)
		    dma_sim.start(host_index, dma_trans_rate);
		scheduler.start(host_index);
		start_counting <= 1;
		fire_once <= 1;
	endrule

/*------------------------------------------------------------------------------*/
    // PHY port to MAC port mapping

    for (Integer i = 0; i < fromInteger(valueof(NUM_OF_PORTS)); i = i + 1)
    begin
        rule mac_phy_tx;
            phys.tx[i].put(mac.tx(i));
        endrule

        rule mac_phy_rx;
            let v <- phys.rx[i].get;
            mac.rx(i, v);
        endrule
    end

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
		indication.display_time_slots_count(time_slots_reg);
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
		indication.display_host_pkt_count(host_pkt_reg);
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
		indication.display_non_host_pkt_count(non_host_pkt_reg);
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
		indication.display_received_pkt_count(received_pkt_reg);
	endrule

/*------------------------------------------------------------------------------*/
	Reg#(Bit#(64)) unknown_pkt_reg <- mkReg(0);
	Reg#(Bit#(1)) fire_unknown_pkt <- mkReg(0);
	rule unknown_pkt_rule;
		let res <- scheduler.unknown_pkt_response.get;
		unknown_pkt_reg <= res;
		fire_unknown_pkt <= 1;
	endrule

	rule unknown_pkt (fire_unknown_pkt == 1);
		fire_unknown_pkt <= 0;
		indication.display_unknown_pkt_count(unknown_pkt_reg);
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
		indication.display_dma_stats(dma_stats_reg.pkt_count);
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
//		indication.debug_dma(zeroExtend(res));
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
//		indication.debug_sched(zeroExtend(res.sop),
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
//		indication.debug_mac_tx(zeroExtend(res.sop),
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
//		indication.debug_mac_rx(zeroExtend(res.sop),
//		                        zeroExtend(res.eop),
//		                        res.data);
//	endrule
/*-----------------------------------------------------------------------------*/
	Reg#(Bit#(64)) sop_count_reg <- mkReg(0);
	Reg#(Bit#(1)) fire_sop_counter_res <- mkReg(0);
	rule sop_counter_rule (debug_flag == 1);
		let res <- mac.sop_count.get;
		sop_count_reg <= res;
        fire_sop_counter_res <= 1;
	endrule

	rule sop_counter_res (debug_flag == 1 && fire_sop_counter_res == 1);
		fire_sop_counter_res <= 0;
		indication.display_sop_count_from_mac_rx(sop_count_reg);
	endrule

/*-----------------------------------------------------------------------------*/
	Reg#(Bit#(64)) eop_count_reg <- mkReg(0);
	Reg#(Bit#(1)) fire_eop_counter_res <- mkReg(0);
	rule eop_counter_rule (debug_flag == 1);
		let res <- mac.eop_count.get;
		eop_count_reg <= res;
        fire_eop_counter_res <= 1;
	endrule

	rule eop_counter_res (debug_flag == 1 && fire_eop_counter_res == 1);
		fire_eop_counter_res <= 0;
		indication.display_eop_count_from_mac_rx(eop_count_reg);
	endrule

/* ------------------------------------------------------------------------------
*                               INTERFACE METHODS
* ------------------------------------------------------------------------------*/
	Reg#(ServerIndex) host_index_reg <- mkReg(0);
	Reg#(Bit#(32)) dma_transmission_rate_reg <- mkReg(0);
	Reg#(Bit#(64)) cycles_reg <- mkReg(0);

	Reg#(Bit#(1)) fire_start_scheduler_and_dma_req <- mkReg(0);

	rule start_scheduler_and_dma_req (fire_start_scheduler_and_dma_req == 1);
		fire_start_scheduler_and_dma_req <= 0;
		dma_transmission_rate_fifo.enq(dma_transmission_rate_reg);
		num_of_cycles_to_run_dma_for_fifo.enq(cycles_reg);
		host_index_fifo.enq(host_index_reg);
		//host_index_fifo_mac.enq(host_index_reg);
	endrule


    interface SchedulerTopRequest request;
        method Action start_scheduler_and_dma(Bit#(32) idx,
			                    Bit#(32) dma_transmission_rate,	Bit#(64) cycles);
			fire_start_scheduler_and_dma_req <= 1;
			host_index_reg <= truncate(idx);
			dma_transmission_rate_reg <= dma_transmission_rate;
			cycles_reg <= cycles;
        endmethod

		method Action debug();
			debug_flag <= 1;
		endmethod
    endinterface

    interface `PinType pins;
        method Action osc_50 (Bit#(1) b3d, Bit#(1) b4a, Bit#(1) b4d, Bit#(1) b7a,
                              Bit#(1) b7d, Bit#(1) b8a, Bit#(1) b8d);
			clk_50_wire <= b4a;
        endmethod
        method Vector#(4, Bit#(1)) serial_tx_data;
            let v = append(dtpPhy.serial_tx, phys.serial_tx);
            return v;
        endmethod
        method Action serial_rx (Vector#(4, Bit#(1)) v);
            phys.serial_rx(takeAt(0, v));
            dtpPhy.serial_rx(takeAt(3, v));
        endmethod
//        method serial_tx_data = phys.serial_tx;
//        method serial_rx = phys.serial_rx;
        method Action sfp(Bit#(1) refclk);
			clk_644_wire <= refclk;
        endmethod
		interface i2c = clocks.i2c;
        interface led = leds.led_out;
        interface led_bracket = leds.led_out;
        interface sfpctrl = sfpctrl;
        interface buttons = buttons.pins;
        interface deleteme_unused_clock = defaultClock;
        interface deleteme_unused_clock2 = clocks.clock_50;
        interface deleteme_unused_clock3 = defaultClock;
        interface deleteme_unused_reset = defaultReset;
    endinterface
endmodule
