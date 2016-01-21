import Vector::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import BRAM::*;
import GetPut::*;
import DefaultValue::*;
import Clocks::*;

import SchedulerTypes::*;
import ScheduleTable::*;
import RingBufferTypes::*;
import RingBuffer::*;
import MachineToPortMapping::*;
import GlobalClock::*;

typedef 18 RING_BUFFER_SIZE_PLUS_TWO;

typedef struct {
	Vector#(RING_BUFFER_SIZE_PLUS_TWO, Bit#(32)) count;
} QueueStats deriving(Bits, Eq);

instance DefaultValue#(QueueStats);
	defaultValue = QueueStats {
						count : replicate(0)
	               };
endinstance

typedef struct {
	ReadResType data;
	PortIndex tx_port;
} DataToPutInTx deriving(Bits, Eq);

instance DefaultValue#(DataToPutInTx);
	defaultValue = DataToPutInTx {
					data : defaultValue,
					tx_port : fromInteger(valueof(NUM_OF_PORTS))
				};
endinstance

interface Scheduler#(type reqType, type resType,
                     type readReqType, type readResType,
                     type writeReqType, type writeResType);
    /* Controller interface */
    interface Put#(reqType) request;
    interface Get#(resType) settime_response;
    interface Get#(resType) gettime_response;
    interface Get#(resType) setinterval_response;
    interface Get#(resType) getinterval_response;
    interface Get#(resType) insert_response;
    interface Get#(resType) delete_response;
    interface Get#(resType) display_response;

    /* MAC interfaces */
    interface Put#(readReqType) mac_read_request_port_1;
    interface Put#(writeReqType) mac_write_request_port_1;
    interface Get#(readResType) mac_read_response_port_1;
    interface Get#(writeResType) mac_write_response_port_1;

    interface Put#(readReqType) mac_read_request_port_2;
    interface Put#(writeReqType) mac_write_request_port_2;
    interface Get#(readResType) mac_read_response_port_2;
    interface Get#(writeResType) mac_write_response_port_2;

    interface Put#(readReqType) mac_read_request_port_3;
    interface Put#(writeReqType) mac_write_request_port_3;
    interface Get#(readResType) mac_read_response_port_3;
    interface Get#(writeResType) mac_write_response_port_3;

    interface Put#(readReqType) mac_read_request_port_4;
    interface Put#(writeReqType) mac_write_request_port_4;
    interface Get#(readResType) mac_read_response_port_4;
    interface Get#(writeResType) mac_write_response_port_4;

    /* DMA simulator interface */
    interface Put#(readReqType) dma_read_request;
    interface Put#(writeReqType) dma_write_request;
    interface Get#(readResType) dma_read_response;
    interface Get#(writeResType) dma_write_response;

    method Action print_stats();
	method Action print_queue_stats();
endinterface

module mkScheduler#(Integer host_index,
                    Clock txClock, Reset txReset,
                    Clock rxClock, Reset rxReset) (Scheduler#(SchedReqResType,
                                                    SchedReqResType,
                                                    ReadReqType, ReadResType,
                                                    WriteReqType, WriteResType));
    Reg#(Bool) verbose <- mkReg(False);

    GlobalClock clk <- mkGlobalClock;

    Clock defaultClock <- exposeCurrentClock();
    Reset defaultReset <- exposeCurrentReset();

    FIFOF#(SchedReqResType) request_fifo <- mkSizedFIFOF(10);
    FIFOF#(SchedReqResType) settime_response_fifo <- mkFIFOF;
    FIFOF#(SchedReqResType) gettime_response_fifo <- mkFIFOF;
    FIFOF#(SchedReqResType) setinterval_response_fifo <- mkFIFOF;
    FIFOF#(SchedReqResType) getinterval_response_fifo <- mkFIFOF;
    FIFOF#(SchedReqResType) insert_response_fifo <- mkFIFOF;
    FIFOF#(SchedReqResType) delete_response_fifo <- mkFIFOF;
    FIFOF#(SchedReqResType) display_response_fifo <- mkFIFOF;

    Vector#(NUM_OF_PORTS, FIFO#(ReadReqType)) mac_read_request_fifo
                                             <- replicateM(mkSizedFIFO(2));
    Vector#(NUM_OF_PORTS, FIFO#(ReadResType)) mac_read_response_fifo
                                             <- replicateM(mkSizedFIFO(4));
    Vector#(NUM_OF_PORTS, SyncFIFOIfc#(WriteReqType)) mac_write_request_fifo
                    <- replicateM(mkSyncFIFO(2, rxClock, rxReset, defaultClock));
    Vector#(NUM_OF_PORTS, SyncFIFOIfc#(WriteResType)) mac_write_response_fifo
               <- replicateM(mkSyncFIFO(2, defaultClock, defaultReset, rxClock));

    FIFOF#(ReadReqType) dma_read_request_fifo <- mkFIFOF;
    FIFOF#(ReadResType) dma_read_response_fifo <- mkFIFOF;
    FIFOF#(WriteReqType) dma_write_request_fifo <- mkPipelineFIFOF;
    FIFOF#(WriteResType) dma_write_response_fifo <- mkFIFOF;

    Reg#(Bit#(64)) start_time <- mkReg(0);
    Reg#(Bit#(64)) interval <- mkReg(0);

    Server#(TableReqResType, TableReqResType) sched_table <- mksched_table;

    Reg#(SchedulerOp) curr_op <- mkReg(NONE);
    Reg#(State) curr_state <- mkReg(CONFIG);

    Reg#(Bit#(1)) table_op_in_progress <- mkReg(0);

    FIFOF#(SchedReqResType) sched_req_fifo <- mkFIFOF;

/*-------------------------------------------------------------------------------*/
    rule set_time (curr_op == SETTIME);
        let req <- toGet(sched_req_fifo).get;
        if (curr_state == CONFIG)
        begin
            start_time <= req.start_time;
            settime_response_fifo.enq
                        (makeSchedReqRes(0, 0, 0, 0, 0, SETTIME, SUCCESS));
        end
        else
            settime_response_fifo.enq
                        (makeSchedReqRes(0, 0, 0, 0, 0, SETTIME, FAILURE));
    endrule

    rule get_time (curr_op == GETTIME);
        let req <- toGet(sched_req_fifo).get;
        gettime_response_fifo.enq
                (makeSchedReqRes(0, 0, start_time, 0, 0, GETTIME, SUCCESS));
    endrule

/*-------------------------------------------------------------------------------*/
    rule set_interval (curr_op == SETINTERVAL);
        let req <- toGet(sched_req_fifo).get;
        if (curr_state == CONFIG)
        begin
            interval <= req.interval;
            setinterval_response_fifo.enq
                   (makeSchedReqRes(0, 0, 0, 0, 0, SETINTERVAL, SUCCESS));
        end
        else
            setinterval_response_fifo.enq
                 (makeSchedReqRes(0, 0, 0, 0, 0, SETINTERVAL, FAILURE));
    endrule

    rule get_interval (curr_op == GETINTERVAL);
        let req <- toGet(sched_req_fifo).get;
        getinterval_response_fifo.enq(makeSchedReqRes(0, 0, 0, interval,
                                               0, GETINTERVAL,SUCCESS));
    endrule

/*-------------------------------------------------------------------------------*/
    rule insert_req (curr_op == INSERT);
        let req <- toGet(sched_req_fifo).get;
        if (curr_state == CONFIG)
            sched_table.request.put(makeTableReqRes(req.server_ip, req.server_mac,
                                    0, PUT, SUCCESS));
        else
        begin
            table_op_in_progress <= 0;
            insert_response_fifo.enq
                           (makeSchedReqRes(0, 0, 0, 0, 0, INSERT, FAILURE));
        end
    endrule

    rule insert_res (curr_op == INSERT);
        let res <- sched_table.response.get;
        if (res.op_outcome == SUCCESS)
            insert_response_fifo.enq
                            (makeSchedReqRes(0, 0, 0, 0, 0, INSERT, SUCCESS));
        else
            insert_response_fifo.enq
                            (makeSchedReqRes(0 ,0, 0, 0, 0, INSERT, FAILURE));

        table_op_in_progress <= 0;
    endrule

/*-------------------------------------------------------------------------------*/
    rule delete_req (curr_op == DELETE);
        let req <- toGet(sched_req_fifo).get;
        if (curr_state == CONFIG)
            sched_table.request.put(makeTableReqRes(req.server_ip, req.server_mac,
                                    0, REMOVE, SUCCESS));
        else
        begin
            table_op_in_progress <= 0;
            delete_response_fifo.enq
                          (makeSchedReqRes(0, 0, 0, 0, 0, DELETE, FAILURE));
        end
    endrule

    rule delete_res (curr_op == DELETE);
        let res <- sched_table.response.get;
        if (res.op_outcome == SUCCESS)
            delete_response_fifo.enq
                          (makeSchedReqRes(0, 0, 0, 0, 0, DELETE, SUCCESS));
        else
            delete_response_fifo.enq
                          (makeSchedReqRes(0 ,0, 0, 0, 0, DELETE, FAILURE));

        table_op_in_progress <= 0;
    endrule

/*-------------------------------------------------------------------------------*/
    rule display_req (curr_op == DISPLAY);
        let req <- toGet(sched_req_fifo).get;
        sched_table.request.put(makeTableReqRes(0, 0, req.serverIdx, GET, SUCCESS));
    endrule

    rule display_res (curr_op == DISPLAY);
        let res <- sched_table.response.get;
        if (res.op_outcome == SUCCESS)
            display_response_fifo.enq
                           (makeSchedReqRes(res.server_ip, res.server_mac, 0, 0,
                                                            0, DISPLAY, SUCCESS));
        else
            display_response_fifo.enq
                      (makeSchedReqRes(0 ,0, 0, 0, 0, DISPLAY, FAILURE));

        table_op_in_progress <= 0;
    endrule

/*------------------------------------------------------------------------------*/
    Vector#(NUM_OF_PORTS,
            RingBuffer#(ReadReqType, ReadResType, WriteReqType, WriteResType))
    rx_ring_buffer <- replicateM
                      (mkRingBuffer(fromInteger(valueof(RING_BUFFER_SIZE))));

	Vector#(NUM_OF_PORTS, Reg#(QueueStats)) rx_ring_buffer_queue_stats
	                                       <- replicateM(mkReg(defaultValue));

    Vector#(NUM_OF_PORTS,
            RingBuffer#(ReadReqType, ReadResType, WriteReqType, WriteResType))
    tx_ring_buffer <- replicateM
                      (mkRingBuffer(fromInteger(valueof(RING_BUFFER_SIZE))));

	Vector#(NUM_OF_PORTS, Reg#(QueueStats)) tx_ring_buffer_queue_stats
	                                       <- replicateM(mkReg(defaultValue));

    Vector#(NUM_OF_SERVERS,
            RingBuffer#(ReadReqType, ReadResType, WriteReqType, WriteResType))
    ring_buffer <- replicateM
                   (mkRingBuffer(fromInteger(valueof(RING_BUFFER_SIZE))));

	Vector#(NUM_OF_SERVERS, Reg#(QueueStats)) ring_buffer_queue_stats
	                                       <- replicateM(mkReg(defaultValue));

    RingBuffer#(ReadReqType, ReadResType, WriteReqType, WriteResType)
        src_rx_ring_buffer <- mkRingBuffer(fromInteger(valueof(RING_BUFFER_SIZE)));

	Reg#(Bit#(32)) src_tx_ring_buffer_drop_count <- mkReg(0);

	Reg#(Bit#(1)) measure1 <- mkReg(0);
	Reg#(Bit#(1)) measure2 <- mkReg(0);
	Reg#(ServerIndex) measure3 <- mkReg(fromInteger(valueof(NUM_OF_SERVERS)));

/*-------------------------------------------------------------------------------*/
	rule monitor_rx_ring_buffers (curr_state == RUN && measure1 == 1);
		for (Integer i = 0; i < fromInteger(valueof(NUM_OF_PORTS)); i = i + 1)
		begin
			let len <- rx_ring_buffer[i].elements;
			if (len <= fromInteger(valueof(RING_BUFFER_SIZE)))
				(rx_ring_buffer_queue_stats[i]).count[len] <=
				             (rx_ring_buffer_queue_stats[i]).count[len] + 1;
			else
				(rx_ring_buffer_queue_stats[i]).count[fromInteger(valueof(RING_BUFFER_SIZE))+1] <=
						(rx_ring_buffer_queue_stats[i]).count[fromInteger(valueof(RING_BUFFER_SIZE))+1] + 1;
		end
		measure1 <= 0;
	endrule

	rule monitor_tx_ring_buffers (curr_state == RUN && measure2 == 1);
		for (Integer i = 0; i < fromInteger(valueof(NUM_OF_PORTS)); i = i + 1)
		begin
			let len <- tx_ring_buffer[i].elements;
			if (len <= fromInteger(valueof(RING_BUFFER_SIZE)))
				(tx_ring_buffer_queue_stats[i]).count[len] <=
				             (tx_ring_buffer_queue_stats[i]).count[len] + 1;
			else
				(tx_ring_buffer_queue_stats[i]).count[fromInteger(valueof(RING_BUFFER_SIZE))+1] <=
						(tx_ring_buffer_queue_stats[i]).count[fromInteger(valueof(RING_BUFFER_SIZE))+1] + 1;
		end
		measure2 <= 0;
	endrule

    for (Integer i = 0; i < fromInteger(valueof(NUM_OF_SERVERS)); i = i + 1)
    begin
        rule monitor_ring_buffers (curr_state == RUN && measure3 == fromInteger(i));
            let len <- ring_buffer[i].elements;
            //if (i != 0 && len == 2)
            //begin
            //    found = True;
            //    $display("[SCHED (%d)] ring_buffer[%d].elements = 2", host_index, i);
            //end
            if (len <= fromInteger(valueof(RING_BUFFER_SIZE)))
                (ring_buffer_queue_stats[i]).count[len] <=
                             (ring_buffer_queue_stats[i]).count[len] + 1;
            else
                (ring_buffer_queue_stats[i]).count[fromInteger(valueof(RING_BUFFER_SIZE))+1] <=
                        (ring_buffer_queue_stats[i]).count[fromInteger(valueof(RING_BUFFER_SIZE))+1] + 1;
            //if (found == True)
            //    curr_state <= CONFIG;
            measure3 <= fromInteger(valueof(NUM_OF_SERVERS));
        endrule
    end
/*-------------------------------------------------------------------------------*/

    Vector#(NUM_OF_SERVERS, Reg#(ServerIndex)) schedule_list <- replicateM(mkReg(0));
    Reg#(MAC) host_mac_addr <- mkReg(0);
    Reg#(IP) host_ip_addr <- mkReg(0);

    /* Flags */
    Reg#(Bit#(1)) configure <- mkReg(0);
    Reg#(Bit#(1)) get_host_mac <- mkReg(0);
    Reg#(Bit#(1)) wait_for_host_mac <- mkReg(0);
    Reg#(Bit#(1)) start_polling_rx_buffer <- mkReg(0);
    Reg#(Bit#(1)) start_scheduling_tx_buffers <- mkReg(0);

    /* Stats */
    Reg#(Bit#(64)) host_pkt_transmitted <- mkReg(0);
    Reg#(Bit#(64)) non_host_pkt_transmitted <- mkReg(0);
    Reg#(Bit#(64)) num_of_time_slots_used <- mkReg(0);

    /*
    * Here the assumption is that since it is our own
    * network, so we assign the IP addresses to the
    * machines in such a way that the mapping IP -> index
    * is trivial. For eg. currently I am assuming that the
    * IP addresses have been assigned such as the mapping
    * is index = least significant byte of IP address - 1.
    * So the IP addrs may be like 192.168.0.1, 192.168.0.2,
    * 192.168.0.3 etc. Note that this is just to make processing
    * faster and saving memory resources. If this approach is not
    * viable in a particular setting, then we can rely back on
    * storing the mapping in a table in BRAM memory, and traversing
    * the table every time we need to know the index of a ring
    * buffer.
    */
    function ServerIndex ipToIndexMapping (IP ip_addr);
        ServerIndex index = truncate(ip_addr[7:0]) - 1;
        if (index < truncate(host_ip_addr[7:0]))
            index = index + 1;
        return index;
    endfunction

    rule start_scheduler (curr_state == RUN);
        let req <- toGet(sched_req_fifo).get;
        if (verbose) $display("[SCHED (%d)] Scheduler started..", host_index);
    endrule

    /*
    * 0th entry in the schedule table will always contain the info of the
    * host server. Entries 1 to NUM_OF_SERVERS-1 will contain info of the
    * remaining servers. As there will be a total of NUM_OF_SERVERS-1 time
    * slots, so the size of schedule_list is NUM_OF_SERVERS-1.
    *
    * schedule_list[i] = j means in time slot i, send pkt to server at index
    * j in the schedule table.
    */
    rule configure_scheduling (curr_state == RUN && configure == 1);
        configure <= 0;
        for (Integer i = 0; i < fromInteger(valueof(NUM_OF_SERVERS))-1; i = i + 1)
        begin
            schedule_list[i] <= fromInteger(i) + 1;
            if (verbose)
            $display("[SCHED (%d)] schedule_list[%d] = %d", host_index, i, i+1);
        end
    endrule

    rule get_host_mac_addr (curr_state == RUN && get_host_mac == 1);
        sched_table.request.put(makeTableReqRes(0, 0, 0, GET, SUCCESS));
        get_host_mac <= 0;
        wait_for_host_mac <= 1;
    endrule

    rule set_host_mac_addr (curr_state == RUN && wait_for_host_mac == 1);
        let d <- sched_table.response.get;
        wait_for_host_mac <= 0;
        host_mac_addr <= d.server_mac;
        host_ip_addr <= d.server_ip;
        start_polling_rx_buffer <= 1;
		start_scheduling_tx_buffers <= 1;
    endrule

/*------------------------------------------------------------------------------*/
    Vector#(NUM_OF_PORTS, FIFOF#(RingBufferDataT))
                              buffer_fifo <- replicateM(mkSizedFIFOF(8));
    Vector#(NUM_OF_PORTS, FIFOF#(ServerIndex))
          ring_buffer_index_fifo <- replicateM
                    (mkSizedFIFOF(fromInteger(valueof(NUM_OF_PORTS))+1));
    Vector#(NUM_OF_PORTS, Reg#(Bit#(1)))
                 ready_to_deq_from_index_buffer <- replicateM(mkReg(1));
    Vector#(NUM_OF_PORTS, Reg#(Bit#(1)))
                  ready_to_deq_from_ring_buffer <- replicateM(mkReg(0));

    /* Stores the number of data blocks to buffer */
    Vector#(NUM_OF_PORTS, Reg#(Bit#(10))) buffer_depth <- replicateM(mkReg(3));

    /* Have to buffer first 3 data blocks to get to dst IP addr
    *
    * Assumption here is that the MAC Frame structure is as shown
    *  ------------------------------------------------------
    * | dst MAC | src MAC | ether type | IP header | Payload |
    *  ------------------------------------------------------
    * So, no VLAN tags etc.
    */
    Vector#(NUM_OF_PORTS, Reg#(Bit#(384))) buffered_data <- replicateM(mkReg(0));

    Vector#(NUM_OF_PORTS, Reg#(Bit#(1))) stop_polling <- replicateM(mkReg(0));

    Vector#(NUM_OF_PORTS, Reg#(ServerIndex)) curr_ring_buffer_index
                        <- replicateM(mkReg(fromInteger(valueof(NUM_OF_SERVERS))));

    Vector#(NUM_OF_SERVERS, FIFOF#(PortIndex))
    token_queue <- replicateM(mkSizedFIFOF(fromInteger(valueof(NUM_OF_SERVERS))));

    for (Integer i = 0; i < fromInteger(valueof(NUM_OF_PORTS)); i = i + 1)
    begin
        rule start_polling_rx (curr_state == RUN && start_polling_rx_buffer == 1
                               && stop_polling[i] == 0);
            let ring_buf_empty <- rx_ring_buffer[i].empty;

            if (!ring_buf_empty)
            begin
                rx_ring_buffer[i].read_request.put(makeReadReq(READ));
				stop_polling[i] <= 1;
            end
        endrule

        rule buffer_and_parse_incoming_data (curr_state == RUN);
            let d <- rx_ring_buffer[i].read_response.get;

            if (d.data.sop == 1 && d.data.eop == 0)
            begin
                Bit#(384) pload = zeroExtend(d.data.payload);
				buffered_data[i] <= buffered_data[i] |
				(pload << (fromInteger(valueof(BUS_WIDTH)) * (buffer_depth[i]-1)));
                buffer_depth[i] <= buffer_depth[i] - 1;
                buffer_fifo[i].enq(d.data);
            end

            else
            begin
                if (buffer_depth[i] > 0)
                begin
                    buffer_depth[i] <= buffer_depth[i] - 1;
                    Bit#(384) pload = zeroExtend(d.data.payload);
                    buffered_data[i] <= buffered_data[i] |
                    (pload << (fromInteger(valueof(BUS_WIDTH)) * (buffer_depth[i]-1)));
                end

                else if (buffer_depth[i] == 0) /* already buffered 3 data blocks */
                begin
                    if (d.data.sop == 0 && d.data.eop == 1)
                    begin
                        /* reset state */
                        buffer_depth[i] <= 3;
                        buffered_data[i] <= 0;
                    end
                    else
                        buffer_depth[i] <= buffer_depth[i] - 1;

                    /* Find the index of the ring buffer to insert to. */
                    Bit#(32) dst_ip = (buffered_data[i])[143:112]; /* dst IP */
                    if (dst_ip == host_ip_addr)
					begin
                        ring_buffer_index_fifo[i].enq(0);
						if (verbose)
							$display("[SCHED (%d)] HOST PKT", host_index);
					end
                    else
                    begin
                        ServerIndex index = ipToIndexMapping(dst_ip);
                        ring_buffer_index_fifo[i].enq(index);
                        if (verbose)
                            $display("[SCHED (%d)] Adding idx = %d to idx fifo %d",
                                     host_index, index, i);
                    end
                end

                else if (d.data.sop == 0 && d.data.eop == 1)
                begin
                    /* reset state */
                    buffer_depth[i] <= 3;
                    buffered_data[i] <= 0;
                end

                buffer_fifo[i].enq(d.data);
            end
        endrule

        rule extract_ring_buffer_index_to_add_to
                    (curr_state == RUN && ready_to_deq_from_index_buffer[i] == 1);
            let index <- toGet(ring_buffer_index_fifo[i]).get;
            curr_ring_buffer_index[i] <= index;
            ready_to_deq_from_index_buffer[i] <= 0;
            ready_to_deq_from_ring_buffer[i] <= 1;
        endrule

        for (Integer j = 0; j < fromInteger(valueof(NUM_OF_SERVERS)); j = j + 1)
        begin
            rule enq_to_token_queue (curr_state == RUN
                                  && curr_ring_buffer_index[i] == fromInteger(j));
                token_queue[j].enq(fromInteger(i));
                if (verbose)
                $display("[SCHED (%d)] token_queue[%d].enq(%d)", host_index, j, i);
                curr_ring_buffer_index[i] <= fromInteger(valueof(NUM_OF_SERVERS));
            endrule
        end
    end

    Vector#(NUM_OF_SERVERS, Reg#(PortIndex))
         port_idx <- replicateM(mkReg(fromInteger(valueof(NUM_OF_PORTS))));

	Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) wait_for_completion
	                                         <- replicateM(mkReg(0));
    for (Integer j = 0; j < fromInteger(valueof(NUM_OF_SERVERS)); j = j + 1)
    begin
        rule deq_from_token_queue (curr_state == RUN && wait_for_completion[j] == 0);
            let port_index <- toGet(token_queue[j]).get;
            port_idx[j] <= port_index;
            if (verbose)
                $display("[SCHED (%d)] port_idx[%d] = %d",host_index,j,port_index);
            stop_polling[port_index] <= 0;
			wait_for_completion[j] <= 1;
        endrule

        for (Integer i = 0; i < fromInteger(valueof(NUM_OF_PORTS)); i = i + 1)
        begin
            rule add_to_correct_ring_buffer (curr_state == RUN
                                        && port_idx[j] == fromInteger(i)
                                        && ready_to_deq_from_ring_buffer[i] == 1);
                let d <- toGet(buffer_fifo[i]).get;

                if (d.sop == 0 && d.eop == 1)
                begin
                    ready_to_deq_from_index_buffer[i] <= 1;
                    ready_to_deq_from_ring_buffer[i] <= 0;
					wait_for_completion[j] <= 0;
                    port_idx[j] <= fromInteger(valueof(NUM_OF_PORTS));
                end

                if (j != 0)
                    ring_buffer[j].write_request.put
                                    (makeWriteReq(d.sop, d.eop, d.payload));
                else
                    src_rx_ring_buffer.write_request.put
                                    (makeWriteReq(d.sop, d.eop, d.payload));
                if (verbose)
                    $display("[SCHED (%d)] CLK = %d buffer index to put data = %d data = %d %d %x", host_index, clk.currTime(), j, d.sop, d.eop, d.payload);
            endrule
        end
    end

/*-------------------------------------------------------------------------------*/
	Reg#(ServerIndex) curr_slot <- mkReg(0);
	Reg#(MAC) dst_mac_addr <- mkReg(0);

    rule get_dst_addr (curr_state == RUN && clk.currTime() == start_time
		               && start_scheduling_tx_buffers == 1);
        start_time <= start_time + interval;

		if (curr_slot == (fromInteger(valueof(NUM_OF_SERVERS))-2))
			curr_slot <= 0;
		else
			curr_slot <= curr_slot + 1;

        num_of_time_slots_used <= num_of_time_slots_used + 1;

		measure1 <= 1;
		measure2 <= 1;

        if (verbose)
            $display("[SCHED (%d)] CLK = %d  schedule_list[%d] = %d", host_index,
                            clk.currTime(), curr_slot, schedule_list[curr_slot]);
        /* Get the dst mac and ip addr */
        sched_table.request.put
            (makeTableReqRes(0, 0, schedule_list[curr_slot], GET, SUCCESS));

//		Bit#(64) curr_time = clk.currTime();

//		Bit#(4) clock_lsb_four_bits = curr_time[3:0];
//		if (clock_lsb_four_bits == 0)
//		begin
//			ServerIndex slot = 0;
//			//TODO Assumes NUM_OF_SERVERS < 16
//			//ServerIndex slot = curr_time[7:4] %
//			//                   (fromInteger(valueof(NUM_OF_PORTS))-1);
//			if (verbose)
//            $display("[SCHED (%d)] CLK = %d  schedule_list[%d] = %d", host_index,
//                            curr_time, slot, schedule_list[slot]);
//			/* Get the dst mac and ip addr */
//			sched_table.request.put
//				(makeTableReqRes(0, 0, schedule_list[slot], GET, SUCCESS));
//		end
//
//        num_of_time_slots_used <= num_of_time_slots_used + 1;

    endrule

    rule extract_from_correct_ring_buffer (curr_state == RUN);
        let d <- sched_table.response.get;

        dst_mac_addr <= d.server_mac;

        if (verbose)
            $display("[SCHED (%d)] CLK = %d MAC = %x IP = %x", host_index,
                                      clk.currTime(), d.server_mac, d.server_ip);
        /* Get the index of the ring buffer to extract from */
        ServerIndex index = ipToIndexMapping(d.server_ip);

        if (verbose)
            $display("[SCHED (%d)] CLK = %d buffer index to extract from = %d %d",
            host_index, clk.currTime(), index, ring_buffer[index].elements);

        Bool is_empty <- ring_buffer[index].empty;

		measure3 <= index;
        /*
         * Only if the forwarding ring buffer is empty, extract packet from
         * the host tx buffer.
         */
        if (!is_empty)
            ring_buffer[index].read_request.put(makeReadReq(READ));
        else
        begin
            if (verbose)
                $display("[SCHED (%d)] CLK = %d Empty ring; extract from host tx %d",
                            host_index, clk.currTime(), ring_buffer[0].elements);
                ring_buffer[0].read_request.put(makeReadReq(READ));
        end

    endrule

    Vector#(NUM_OF_SERVERS, FIFO#(DataToPutInTx)) data_to_put
	                              <- replicateM(mkSizedFIFO(8));
	Vector#(NUM_OF_SERVERS, Reg#(PortIndex)) tx_port_index <- replicateM(mkReg(0));

    Vector#(NUM_OF_SERVERS, FIFO#(ReadResType)) data_fifo
	                              <- replicateM(mkBypassFIFO);
	Vector#(NUM_OF_SERVERS, Wire#(PortIndex)) correct_tx_index <- replicateM(mkDWire(0));

    for (Integer i = 0; i < fromInteger(valueof(NUM_OF_SERVERS)); i = i + 1)
    begin
        rule modify_mac_headers_and_put_to_tx (curr_state == RUN);
            let d <- ring_buffer[i].read_response.get;

            if (d.data.sop == 1 && d.data.eop == 0)
            begin
                /* Update MAC header */
                Bit#(96) new_addr = {dst_mac_addr, host_mac_addr};
                Bit#(96) zero = 0;
                Bit#(BUS_WIDTH) temp = {zero, '1};
				Bit#(BUS_WIDTH) new_addr_temp = {new_addr, '0};
                d.data.payload = (d.data.payload & temp) | new_addr_temp;
                PortIndex index = machineToPortMapping(host_index, dst_mac_addr);
				tx_port_index[i] <= index;
                if (i == 0)
                    host_pkt_transmitted <= host_pkt_transmitted + 1;
                else
                    non_host_pkt_transmitted <= non_host_pkt_transmitted + 1;
				DataToPutInTx x = DataToPutInTx {
									data : d,
									tx_port : index
								};
				data_to_put[i].enq(x);
            end

			else
			begin
				DataToPutInTx x = DataToPutInTx {
									data : d,
									tx_port : tx_port_index[i]
								};
				data_to_put[i].enq(x);
			end

            if (verbose)
                $display("[SCHED (%d)] CLK = %d", host_index, clk.currTime());
        endrule

		rule set_correct_tx_index (curr_state == RUN);
			let res <- toGet(data_to_put[i]).get;
			ReadResType d = res.data;
			PortIndex idx = res.tx_port;
			data_fifo[i].enq(d);
			correct_tx_index[i] <= idx;
		if (verbose)
		$display("[SCHED (%d)] CLK = %d data written to tx %d data %d %d %x",
		host_index, clk.currTime(), idx, d.data.sop, d.data.eop, d.data.payload);
		endrule

		for (Integer j = 0; j < fromInteger(valueof(NUM_OF_PORTS)); j = j + 1)
		begin
			rule add_to_correct_tx (correct_tx_index[i] == fromInteger(j));
				let d <- toGet(data_fifo[i]).get;
				tx_ring_buffer[j].write_request.put
					(makeWriteReq(d.data.sop, d.data.eop, d.data.payload));
			endrule
		end
    end

/*-------------------------------------------------------------------------------*/
    rule handle_controller_req (table_op_in_progress == 0);
        let req <- toGet(request_fifo).get;
        sched_req_fifo.enq(req);
        case (req.op)
            SETTIME     : curr_op <= SETTIME;
            GETTIME     : curr_op <= GETTIME;
            SETINTERVAL : curr_op <= SETINTERVAL;
            GETINTERVAL : curr_op <= GETINTERVAL;
            INSERT      : begin
                          curr_op <= INSERT;
                          table_op_in_progress <= 1;
                          end
            DELETE      : begin
                          curr_op <= DELETE;
                          table_op_in_progress <= 1;
                          end
            DISPLAY     : begin
                          curr_op <= DISPLAY;
                          table_op_in_progress <= 1;
                          end
            STARTSCHED  : begin
                          curr_state <= RUN;
                          configure <= 1;
                          get_host_mac <= 1;
                          start_polling_rx_buffer <= 0;
                          end
            STOPSCHED   : curr_state <= CONFIG;
        endcase
    endrule

    for (Integer i = 0; i < fromInteger(valueof(NUM_OF_PORTS)); i = i + 1)
    begin
        rule handle_rx_buffer_write_req_from_mac;
            let req <- toGet(mac_write_request_fifo[i]).get;

            if (verbose)
                $display("[SCHED (%d)] CLK = %d Putting data into rx port buffer %d %d %x i = %d",
                host_index, clk.currTime(), req.data.sop, req.data.eop, req.data.payload, i);

            rx_ring_buffer[i].write_request.put
                  (makeWriteReq(req.data.sop, req.data.eop, req.data.payload));
        endrule

        rule handle_tx_buffer_read_req_from_mac;
            let req <- toGet(mac_read_request_fifo[i]).get;
            tx_ring_buffer[i].read_request.put(makeReadReq(req.op));
        endrule

        rule send_tx_buffer_read_res_to_mac;
            let d <- tx_ring_buffer[i].read_response.get;
            mac_read_response_fifo[i].enq(makeReadRes(d.data));
        endrule
    end

    rule handle_dma_simulator_write_req;
        let req <- toGet(dma_write_request_fifo).get;

        if (verbose)
            $display("[SCHED (%d)] Putting data into host tx buffer %d %d %x",
                        host_index, req.data.sop, req.data.eop, req.data.payload);

		let is_full <- ring_buffer[0].full;
		if (is_full)
			src_tx_ring_buffer_drop_count <= src_tx_ring_buffer_drop_count + 1;

        ring_buffer[0].write_request.put
            (makeWriteReq(req.data.sop, req.data.eop, req.data.payload));
    endrule

    rule handle_dma_simulator_read_req;
        let req <- toGet(dma_read_request_fifo).get;
        src_rx_ring_buffer.read_request.put(makeReadReq(READ));
    endrule

    rule consume_pkt_in_response_to_dma_simulator_read_req;
        let d <- src_rx_ring_buffer.read_response.get;

        if (verbose)
            $display("[SCHED (%d)] CONSUMING from host rx buffer %d %d %x",
                            host_index, d.data.sop, d.data.eop, d.data.payload);
    endrule

    method Action print_stats();
        $display("[SCHED (%d)] TIME SLOTS = %d  HOST PKT = %d  NON-HOST PKT = %d",
            host_index, num_of_time_slots_used, host_pkt_transmitted,
            non_host_pkt_transmitted);
    endmethod

	method Action print_queue_stats();
		for (Integer i = 0; i < fromInteger(valueof(NUM_OF_PORTS)); i = i + 1)
		begin
			for (Integer j = 0; j < fromInteger(valueof(RING_BUFFER_SIZE_PLUS_TWO)); j = j + 1)
				$display("[SCHED (%d)] PORT RX %d LEN %d COUNT %d", host_index, i, j, (rx_ring_buffer_queue_stats[i]).count[j]);
		end

		for (Integer i = 0; i < fromInteger(valueof(NUM_OF_PORTS)); i = i + 1)
		begin
			for (Integer j = 0; j < fromInteger(valueof(RING_BUFFER_SIZE_PLUS_TWO)); j = j + 1)
				$display("[SCHED (%d)] PORT TX %d LEN %d COUNT %d", host_index, i, j, (tx_ring_buffer_queue_stats[i]).count[j]);
		end

		for (Integer i = 0; i < fromInteger(valueof(NUM_OF_SERVERS)); i = i + 1)
		begin
			for (Integer j = 0; j < fromInteger(valueof(RING_BUFFER_SIZE_PLUS_TWO)); j = j + 1)
				$display("[SCHED (%d)] FORWARDING RX %d LEN %d COUNT %d", host_index, i, j, (ring_buffer_queue_stats[i]).count[j]);
		end

		$display("[SCHED (%d)] SOURCE DROP = %d", host_index, (src_tx_ring_buffer_drop_count >> 2));
	endmethod

    /* Controller interface */
    interface Put request = toPut(request_fifo);
    interface Get settime_response = toGet(settime_response_fifo);
    interface Get gettime_response = toGet(gettime_response_fifo);
    interface Get setinterval_response = toGet(setinterval_response_fifo);
    interface Get getinterval_response = toGet(getinterval_response_fifo);
    interface Get insert_response = toGet(insert_response_fifo);
    interface Get delete_response = toGet(delete_response_fifo);
    interface Get display_response = toGet(display_response_fifo);

    /* MAC interfaces */
    interface Put mac_read_request_port_1 = toPut(mac_read_request_fifo[0]);
    interface Put mac_write_request_port_1 = toPut(mac_write_request_fifo[0]);
    interface Get mac_read_response_port_1 = toGet(mac_read_response_fifo[0]);
    interface Get mac_write_response_port_1 = toGet(mac_write_response_fifo[0]);

    interface Put mac_read_request_port_2 = toPut(mac_read_request_fifo[1]);
    interface Put mac_write_request_port_2 = toPut(mac_write_request_fifo[1]);
    interface Get mac_read_response_port_2 = toGet(mac_read_response_fifo[1]);
    interface Get mac_write_response_port_2 = toGet(mac_write_response_fifo[1]);

    interface Put mac_read_request_port_3 = toPut(mac_read_request_fifo[2]);
    interface Put mac_write_request_port_3 = toPut(mac_write_request_fifo[2]);
    interface Get mac_read_response_port_3 = toGet(mac_read_response_fifo[2]);
    interface Get mac_write_response_port_3 = toGet(mac_write_response_fifo[2]);

    interface Put mac_read_request_port_4 = toPut(mac_read_request_fifo[3]);
    interface Put mac_write_request_port_4 = toPut(mac_write_request_fifo[3]);
    interface Get mac_read_response_port_4 = toGet(mac_read_response_fifo[3]);
    interface Get mac_write_response_port_4 = toGet(mac_write_response_fifo[3]);

    /* DMA simulator interface */
    interface Put dma_read_request = toPut(dma_read_request_fifo);
    interface Put dma_write_request = toPut(dma_write_request_fifo);
    interface Get dma_read_response = toGet(dma_read_response_fifo);
    interface Get dma_write_response = toGet(dma_write_response_fifo);
endmodule
