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

import EthMac::*;
import AlteraEthPhy::*;
import DE5Pins::*;

interface SchedulerTopIndication;
    method Action set_interval_outcome(Bit#(8) op_outcome);
    method Action get_interval_outcome(Bit#(64) interval, Bit#(8) op_outcome);
	method Action insert_outcome(Bit#(8) op_outcome);
    method Action display_outcome(Bit#(32) server_ip, Bit#(64) server_mac,
		                                                 Bit#(8) op_outcome);
	method Action display_scheduler_stats(Bit#(64) num_of_time_slots_used,
	                                      Bit#(64) host_pkt_transmitted,
									      Bit#(64) non_host_pkt_transmitted);
	method Action display_dma_stats(Bit#(64) num_of_pkt_generated);
	method Action debug_dma(Bit#(32) dst_index);
	method Action debug_sched(Bit#(8) sop, Bit#(8) eop, Bit#(64) data_high,
	                          Bit#(64) data_low);
	method Action debug_mac_tx(Bit#(8) sop, Bit#(8) eop, Bit#(64) data);
	method Action debug_mac_rx(Bit#(8) sop, Bit#(8) eop, Bit#(64) data);
endinterface

interface SchedulerTopRequest;
    method Action set_interval(Bit#(64) interval);
    method Action get_interval();
    method Action insert(Bit#(32) serverIdx);
    method Action display(Bit#(32) serverIdx);
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
    EthPhyIfc phys <- mkAlteraEthPhy(defaultClock, phyClock, txClock, defaultReset);
    Clock rxClock = phys.rx_clkout;
    Reset rxReset <- mkSyncReset(2, defaultReset, rxClock);

/*-------------------------------------------------------------------------------*/
    Scheduler#(SchedReqResType, SchedReqResType,
            ReadReqType, ReadResType, WriteReqType, WriteResType)
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
	Reg#(Bit#(1)) get_stats_flag <- mkReg(0, clocked_by txClock, reset_by txReset);
    Reg#(Bit#(64)) counter <- mkReg(0, clocked_by txClock, reset_by txReset);

    /* This rule is to configure when to stop the DMA and collect stats */
    rule count_cycles (start_counting == 1);
        counter <= counter + 1;
        if (counter == num_of_cycles_to_run_dma_for)
        begin
			dma_sim.stop();
			scheduler.stop();
			start_counting <= 0;
			get_stats_flag <= 1;
        end
    endrule

	rule get_statistics (get_stats_flag == 1);
		dma_sim.getDMAStats();
		scheduler.getSchedulerStats();
		get_stats_flag <= 0;
	endrule

/*------------------------------------------------------------------------------*/
	// Start DMA

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

	Reg#(Bit#(1)) fire_once <- mkReg(0, clocked_by txClock, reset_by txReset);
	rule start_dma (fire_once == 0
		            && host_index_ready == 1 && dma_trans_rate_ready == 1);
		dma_sim.start(host_index, dma_trans_rate);
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
	Reg#(SchedReqResType) set_interval_res_reg <- mkReg(defaultValue);
	Reg#(Bit#(1)) fire_set_interval_res <- mkReg(0);
	rule set_interval_res_rule;
        let res <- scheduler.setinterval_response.get;
		set_interval_res_reg <= res;
		fire_set_interval_res <= 1;
	endrule

    rule set_interval_res (fire_set_interval_res == 1);
		fire_set_interval_res <= 0;
        if (set_interval_res_reg.op_outcome == SUCCESS)
            indication.set_interval_outcome(1);
        else
            indication.set_interval_outcome(0);
    endrule

/*------------------------------------------------------------------------------*/
	Reg#(SchedReqResType) get_interval_res_reg <- mkReg(defaultValue);
	Reg#(Bit#(1)) fire_get_interval_res <- mkReg(0);
	rule get_interval_res_rule;
        let res <- scheduler.getinterval_response.get;
		get_interval_res_reg <= res;
		fire_get_interval_res <= 1;
	endrule

    rule get_interval_res (fire_get_interval_res == 1);
		fire_get_interval_res <= 0;
        if (get_interval_res_reg.op_outcome == SUCCESS)
            indication.get_interval_outcome(get_interval_res_reg.interval, 1);
        else
            indication.get_interval_outcome(0, 0);
    endrule

/*------------------------------------------------------------------------------*/
	Reg#(SchedReqResType) insert_res_reg <- mkReg(defaultValue);
	Reg#(Bit#(1)) fire_insert_res <- mkReg(0);
	rule insert_res_rule;
        let res <- scheduler.insert_response.get;
		insert_res_reg <= res;
		fire_insert_res <= 1;
	endrule

    rule insert_res (fire_insert_res == 1);
		fire_insert_res <= 0;
        if (insert_res_reg.op_outcome == SUCCESS)
            indication.insert_outcome(1);
        else
            indication.insert_outcome(0);
    endrule

/*------------------------------------------------------------------------------*/
	Reg#(SchedReqResType) display_res_reg <- mkReg(defaultValue);
	Reg#(Bit#(1)) fire_display_res <- mkReg(0);
	rule display_res_rule;
        let res <- scheduler.display_response.get;
		display_res_reg <= res;
		fire_display_res <= 1;
	endrule

    rule display_res (fire_display_res == 1);
		fire_display_res <= 0;
        if (display_res_reg.op_outcome == SUCCESS)
            indication.display_outcome(zeroExtend(display_res_reg.server_ip),
                                      zeroExtend(display_res_reg.server_mac), 1);
        else
            indication.display_outcome(0, 0, 0);
    endrule

/*------------------------------------------------------------------------------*/
	Reg#(SchedulerStatsT) sched_stats_reg <- mkReg(defaultValue);
	Reg#(Bit#(1)) fire_sched_stats <- mkReg(0);
	rule sched_stats_rule;
		let res <- scheduler.scheduler_stats_response.get;
		sched_stats_reg <= res;
		fire_sched_stats <= 1;
	endrule

	rule sched_stats (fire_sched_stats == 1);
		fire_sched_stats <= 0;
		indication.display_scheduler_stats(sched_stats_reg.num_of_time_slots_used,
	                                    sched_stats_reg.host_pkt_transmitted,
									    sched_stats_reg.non_host_pkt_transmitted);
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

/*------------------------------------------------------------------------------*/
	FIFO#(ServerIndex) debug_dma_res_fifo <- mkSizedFIFO(8);
	//Reg#(Bit#(1)) fire_debug_dma_res <- mkReg(0);
	rule debug_dma_res_rule (debug_flag == 1);
		let res <- dma_sim.debug_sending_pkt.get;
		debug_dma_res_fifo.enq(res);
	endrule

	rule debug_dma_res (debug_flag == 1);
		let res <-toGet(debug_dma_res_fifo).get;
		indication.debug_dma(zeroExtend(res));
	endrule

/*------------------------------------------------------------------------------*/
	FIFO#(RingBufferDataT) debug_sched_res_fifo <- mkSizedFIFO(16);
	//Reg#(Bit#(1)) fire_debug_sched_res <- mkReg(0);
	rule debug_sched_res_rule (debug_flag == 1);
		let res <- scheduler.debug_consuming_pkt.get;
		debug_sched_res_fifo.enq(res);
	endrule

	rule debug_sched_res (debug_flag == 1);
		let res <- toGet(debug_sched_res_fifo).get;
		indication.debug_sched(zeroExtend(res.sop),
		                       zeroExtend(res.eop),
	                           res.payload[127:64],
							   res.payload[63:0]);
	endrule

/*------------------------------------------------------------------------------*/
	FIFO#(PacketDataT#(64)) debug_mac_tx_res_fifo <- mkSizedFIFO(16);
	//Reg#(Bit#(1)) fire_debug_mac_tx_res <- mkReg(0);
	rule debug_mac_tx_res_rule (debug_flag == 1);
		let res <- mac.debug_sending_to_phy.get;
		debug_mac_tx_res_fifo.enq(res);
	endrule

	rule debug_mac_tx_res (debug_flag == 1);
		let res <- toGet(debug_mac_tx_res_fifo).get;
		indication.debug_mac_tx(zeroExtend(res.sop),
		                        zeroExtend(res.eop),
		                        res.data);
	endrule

/*------------------------------------------------------------------------------*/
	FIFO#(PacketDataT#(64)) debug_mac_rx_res_fifo <- mkSizedFIFO(16);
	//Reg#(Bit#(1)) fire_debug_mac_rx_res <- mkReg(0);
	rule debug_mac_rx_res_rule (debug_flag == 1);
		let res <- mac.debug_received_from_phy.get;
		debug_mac_rx_res_fifo.enq(res);
	endrule

	rule debug_mac_rx_res (debug_flag == 1);
		let res <- toGet(debug_mac_rx_res_fifo).get;
		indication.debug_mac_tx(zeroExtend(res.sop),
		                        zeroExtend(res.eop),
		                        res.data);
	endrule


/* ------------------------------------------------------------------------------
*                               INTERFACE METHODS
* ------------------------------------------------------------------------------*/
	Reg#(Bit#(64)) interval_reg <- mkReg(0);
	Reg#(ServerIndex) insert_server_idx_reg <- mkReg(0);
	Reg#(ServerIndex) display_server_idx_reg <- mkReg(0);
	Reg#(ServerIndex) host_index_reg <- mkReg(0);
	Reg#(Bit#(32)) dma_transmission_rate_reg <- mkReg(0);
	Reg#(Bit#(64)) cycles_reg <- mkReg(0);

	Reg#(Bit#(1)) fire_set_interval_req <- mkReg(0);
	Reg#(Bit#(1)) fire_get_interval_req <- mkReg(0);
	Reg#(Bit#(1)) fire_insert_req <- mkReg(0);
	Reg#(Bit#(1)) fire_display_req <- mkReg(0);
	Reg#(Bit#(1)) fire_start_scheduler_and_dma_req <- mkReg(0);
	Reg#(Bit#(1)) fire_stop_scheduler_req <- mkReg(0);

	rule set_interval_req (fire_set_interval_req == 1);
		fire_set_interval_req <= 0;
		scheduler.request.put(makeSchedReqRes(0, 0, 0, interval_reg, 0,
											   SETINTERVAL, SUCCESS));
    endrule

	rule get_interval_req (fire_get_interval_req == 1);
		fire_get_interval_req <= 0;
		scheduler.request.put
				(makeSchedReqRes(0, 0, 0, 0, 0, GETINTERVAL, SUCCESS));
	endrule

	rule insert_req (fire_insert_req == 1);
		fire_insert_req <= 0;
		scheduler.request.put(makeSchedReqRes(ip_address(insert_server_idx_reg),
											  mac_address(insert_server_idx_reg),
											  0, 0, 0, INSERT, SUCCESS));

	endrule

	rule display_req (fire_display_req == 1);
		fire_display_req <= 0;
		scheduler.request.put(makeSchedReqRes(0, 0, 0, 0, display_server_idx_reg,
														   DISPLAY, SUCCESS));
	endrule

	rule start_scheduler_and_dma_req (fire_start_scheduler_and_dma_req == 1);
		fire_start_scheduler_and_dma_req <= 0;
		scheduler.request.put(makeSchedReqRes(0, 0, 0, 0, host_index_reg,
		                                             STARTSCHED, SUCCESS));
		dma_transmission_rate_fifo.enq(dma_transmission_rate_reg);
		num_of_cycles_to_run_dma_for_fifo.enq(cycles_reg);
		host_index_fifo.enq(host_index_reg);
	endrule


    interface SchedulerTopRequest request;
        method Action set_interval(Bit#(64) interval);
			fire_set_interval_req <= 1;
			interval_reg <= interval;
        endmethod

        method Action get_interval();
			fire_get_interval_req <= 1;
        endmethod

        method Action insert(Bit#(32) serverIdx);
			fire_insert_req <= 1;
			insert_server_idx_reg <= truncate(serverIdx);
        endmethod

        method Action display(Bit#(32) serverIdx);
			fire_display_req <= 1;
			display_server_idx_reg <= truncate(serverIdx);
        endmethod

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
        method serial_tx_data = phys.serial_tx;
        method serial_rx = phys.serial_rx;
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
