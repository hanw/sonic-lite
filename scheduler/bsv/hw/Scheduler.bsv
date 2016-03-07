import Vector::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import BRAM::*;
import GetPut::*;
import DefaultValue::*;
import Clocks::*;

import SchedulerTypes::*;
import RingBufferTypes::*;
import RingBuffer::*;
`ifdef SIM
import MachineToPortMappingSim::*;
`else
import MachineToPortMapping::*;
`endif
import GlobalClock::*;
import Addresses::*;
import MaxMinFairness::*;
import MinPriorityQueue::*;

typedef struct {
	ReadResType data;
	PortIndex tx_port;
} DataToPutInTx deriving(Bits, Eq);

instance DefaultValue#(DataToPutInTx);
	defaultValue = DataToPutInTx {
					data : defaultValue,
					tx_port : fromInteger(valueof(NUM_OF_ALTERA_PORTS))
				};
endinstance

typedef struct {
    ServerIndex src;
    ServerIndex dst;
    Bit#(16) flow_id;
    Bit#(16) seq_num;
    Bit#(1) op;
} FlowUpdateT deriving(Bits, Eq);

typedef struct {
    ServerIndex src;
    ServerIndex dst;
    ServerIndex mid;
} BottleneckCountParams deriving(Bits, Eq);

interface Scheduler#(type readReqType, type readResType,
                     type writeReqType, type writeResType);

    /* MAC interface */
	interface Vector#(NUM_OF_ALTERA_PORTS, Put#(readReqType)) mac_read_request;
	interface Vector#(NUM_OF_ALTERA_PORTS, Get#(readResType)) mac_read_response;
	interface Vector#(NUM_OF_ALTERA_PORTS, Put#(writeReqType)) mac_write_request;
	interface Vector#(NUM_OF_ALTERA_PORTS, Get#(writeResType)) mac_write_response;

    /* DMA simulator interface */
    interface Put#(readReqType) dma_read_request;
    interface Vector#(NUM_OF_SERVERS, Put#(writeReqType)) dma_write_request;
    interface Get#(readResType) dma_read_response;

    interface Vector#(NUM_OF_SERVERS, Put#(writeReqType)) special_buf_write_req;

    interface Put#(FlowStartEndT) flow_notification_req;

	interface Get#(Bit#(64)) time_slots_response;
	interface Get#(Bit#(64)) host_pkt_response;
	interface Get#(Bit#(64)) non_host_pkt_response;
	interface Get#(Bit#(64)) received_pkt_response;
	interface Get#(Bit#(64)) rxWrite_pkt_response;
	interface Vector#(NUM_OF_SERVERS, Get#(Vector#(RING_BUFFER_SIZE, Bit#(64))))
					                                               fwd_queue_len;
//	interface Get#(RingBufferDataT) debug_consuming_pkt;

	method Action start(ServerIndex serverIdx);
	method Action stop();
	method Action insertToSchedTable(ServerIndex index, IP ip_addr, MAC mac_addr);
    method Action timeSlotsCount();
	method Action hostPktCount();
	method Action nonHostPktCount();
	method Action receivedPktCount();
	method Action rxWritePktCount();
	method Action fwdQueueLen();
endinterface

(* synthesize *)
module mkScheduler#(Clock pcieClock, Reset pcieReset,
                    Clock txClock, Reset txReset,
                    Vector#(NUM_OF_ALTERA_PORTS, Clock) rxClock,
					Vector#(NUM_OF_ALTERA_PORTS, Reset) rxReset)
				(Scheduler#(ReadReqType, ReadResType, WriteReqType, WriteResType));

    Reg#(Bool) verbose <- mkReg(False);

    GlobalClock clk <- mkGlobalClock;

	Reg#(ServerIndex) host_index <- mkReg(0);

    Clock defaultClock <- exposeCurrentClock();
    Reset defaultReset <- exposeCurrentReset();

    Vector#(NUM_OF_ALTERA_PORTS, FIFO#(ReadReqType)) mac_read_request_fifo
            <- replicateM(mkSizedFIFO(valueof(DEFAULT_FIFO_LEN)));
    Vector#(NUM_OF_ALTERA_PORTS, FIFO#(ReadResType)) mac_read_response_fifo
            <- replicateM(mkSizedFIFO(valueof(DEFAULT_FIFO_LEN)));
    Vector#(NUM_OF_ALTERA_PORTS, SyncFIFOIfc#(WriteReqType)) mac_write_request_fifo;
    Vector#(NUM_OF_ALTERA_PORTS, SyncFIFOIfc#(WriteResType)) mac_write_response_fifo;

	for (Integer i = 0; i < valueof(NUM_OF_ALTERA_PORTS); i = i + 1)
	begin
		mac_write_request_fifo[i] <- mkSyncFIFO(valueof(DEFAULT_FIFO_LEN),
	                                      rxClock[i], rxReset[i], defaultClock);
		mac_write_response_fifo[i] <- mkSyncFIFO(valueof(DEFAULT_FIFO_LEN),
	                                    defaultClock, defaultReset, rxClock[i]);
	end

    FIFO#(ReadReqType) dma_read_request_fifo
	                 <- mkSizedFIFO(valueof(DEFAULT_FIFO_LEN));
    FIFO#(ReadResType) dma_read_response_fifo
	                 <- mkSizedFIFO(valueof(DEFAULT_FIFO_LEN));
    Vector#(NUM_OF_SERVERS, FIFO#(WriteReqType)) dma_write_request_fifo
	                 <- replicateM(mkSizedFIFO(valueof(DEFAULT_FIFO_LEN)));

    Vector#(NUM_OF_SERVERS, FIFO#(WriteReqType)) special_buf_write_req_fifo
	                 <- replicateM(mkSizedFIFO(valueof(DEFAULT_FIFO_LEN)));

    Reg#(State) curr_state <- mkReg(CONFIG);

/*-------------------------------------------------------------------------------*/
                        // Ring buffers and Schedule table
/*-------------------------------------------------------------------------------*/
    Vector#(NUM_OF_ALTERA_PORTS,
            RingBuffer#(ReadReqType, ReadResType, WriteReqType, WriteResType))
    rx_ring_buffer <- replicateM(mkRingBuffer(valueof(RING_BUFFER_SIZE)));

    Vector#(NUM_OF_ALTERA_PORTS,
            RingBuffer#(ReadReqType, ReadResType, WriteReqType, WriteResType))
    tx_ring_buffer <- replicateM(mkRingBuffer(valueof(RING_BUFFER_SIZE)));

    Vector#(3, Vector#(NUM_OF_SERVERS,
    RingBuffer#(ReadReqType, ReadResType, WriteReqType, WriteResType))) ring_buffer;

    ring_buffer[0] <- replicateM(mkRingBuffer(valueof(RING_BUFFER_SIZE)));
    ring_buffer[1] <- replicateM(mkRingBuffer(valueof(RING_BUFFER_SIZE)));
    ring_buffer[2] <- replicateM(mkRingBuffer(valueof(1)));

    RingBuffer#(ReadReqType, ReadResType, WriteReqType, WriteResType)
        src_rx_ring_buffer <- mkRingBuffer(valueof(RING_BUFFER_SIZE));

	Vector#(NUM_OF_SERVERS, Reg#(TableData)) sched_table
	                                    <- replicateM(mkReg(defaultValue));

    Vector#(NUM_OF_SERVERS, Reg#(ServerIndex)) schedule_list <- replicateM(mkReg(0));

    MaxMinFairness mmf <- mkMaxMinFairness;

    /* Flags */
    Reg#(Bit#(1)) configure <- mkReg(0);
    Reg#(Bit#(1)) start_scheduling_flag <- mkReg(0);
    Reg#(Bit#(1)) start_polling_rx_buffer <- mkReg(0);
	Reg#(Bit#(1)) start_tx_scheduling <- mkReg(0);

   Vector#(NUM_OF_SERVERS, MinPriorityQueue#(Bit#(16), Bit#(16)))
                             min_priority_queue <- replicateM(mkMinPriorityQueue);

/*-------------------------------------------------------------------------------*/
                                 // Statistics
/*-------------------------------------------------------------------------------*/
	SyncFIFOIfc#(Bit#(64)) time_slots_fifo
	        <- mkSyncFIFO(1, defaultClock, defaultReset, pcieClock);
	SyncFIFOIfc#(Bit#(64)) host_pkt_fifo
	        <- mkSyncFIFO(1, defaultClock, defaultReset, pcieClock);
	SyncFIFOIfc#(Bit#(64)) non_host_pkt_fifo
	        <- mkSyncFIFO(1, defaultClock, defaultReset, pcieClock);
	SyncFIFOIfc#(Bit#(64)) received_pkt_fifo
	        <- mkSyncFIFO(1, defaultClock, defaultReset, pcieClock);
	SyncFIFOIfc#(Bit#(64)) rxWrite_pkt_fifo
	        <- mkSyncFIFO(1, defaultClock, defaultReset, pcieClock);
	Reg#(Bit#(64)) num_of_time_slots_used_reg <- mkReg(0);
	Reg#(Bit#(64)) host_pkt_transmitted_reg <- mkReg(0);
	Reg#(Bit#(64)) non_host_pkt_transmitted_reg <- mkReg(0);
	Vector#(NUM_OF_ALTERA_PORTS, Reg#(Bit#(64))) num_of_pkt_received_reg
	                                     <- replicateM(mkReg(0));
	Vector#(NUM_OF_ALTERA_PORTS, Reg#(Bit#(64))) num_of_rxWrite_pkt_reg
	                                     <- replicateM(mkReg(0));

	Vector#(NUM_OF_SERVERS, SyncFIFOIfc#(Vector#(RING_BUFFER_SIZE, Bit#(64))))
		    fwd_queue_len_fifo <- replicateM(mkSyncFIFO(valueof(NUM_OF_SERVERS),
								        defaultClock, defaultReset, pcieClock));

	Vector#(NUM_OF_SERVERS, Vector#(RING_BUFFER_SIZE, Reg#(Bit#(64))))
						fwd_queue_len_reg <- replicateM(replicateM(mkReg(0)));

	Reg#(ServerIndex) measure <- mkReg(fromInteger(valueof(NUM_OF_SERVERS)));
    Vector#(NUM_OF_SERVERS, Reg#(Bit#(5))) len_index
                <- replicateM(mkReg(fromInteger(valueof(RING_BUFFER_SIZE))));

	for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
	begin
		rule monitor_ring_buffers (curr_state == RUN && measure == fromInteger(i));
			let len <- ring_buffer[1][i].elements;
            len_index[i] <= truncate(len);
            measure <= fromInteger(valueof(NUM_OF_SERVERS));
		endrule

        for (Integer j = 0; j < valueof(RING_BUFFER_SIZE); j = j + 1)
        begin
            rule update_counter (curr_state == RUN
                                 && len_index[i] == fromInteger(j));
                fwd_queue_len_reg[i][j] <= fwd_queue_len_reg[i][j] + 1;
                len_index[i] <= fromInteger(valueof(RING_BUFFER_SIZE));
            endrule
        end
	end

	Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) enq_queue_length <- replicateM(mkReg(0));
	for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
	begin
		rule enq_queue_length_rule (enq_queue_length[i] == 1);
			enq_queue_length[i] <= 0;
			Vector#(RING_BUFFER_SIZE, Bit#(64)) temp = replicate(0);
			for (Integer j = 0; j < valueof(RING_BUFFER_SIZE); j = j + 1)
				temp[j] = fwd_queue_len_reg[i][j];
			fwd_queue_len_fifo[i].enq(temp);
		endrule
	end

//	SyncFIFOIfc#(RingBufferDataT) debug_consuming_pkt_fifo
//	        <- mkSyncFIFO(16, defaultClock, defaultReset, pcieClock);

/*-------------------------------------------------------------------------------*/

    // Here the assumption is that since it is our own
    // network, so we assign the IP addresses to the
    // machines in such a way that the mapping IP -> index
    // is trivial. For eg. currently I am assuming that the
    // IP addresses have been assigned such as the mapping
    // is index = least significant byte of IP address - 1.
    // So the IP addrs may be like 192.168.0.1, 192.168.0.2,
    // 192.168.0.3 etc. Note that this is just to make processing
    // faster and saving memory resources. If this approach is not
    // viable in a particular setting, then we can rely back on
    // storing the mapping in a table in BRAM memory, and traversing
    // the table every time we need to know the index of a ring
    // buffer.

    function ServerIndex ipToIndexMapping (IP ip_addr);
		ServerIndex index = 0;
		Bit#(24) msb = ip_addr[31:8];

        if (ip_addr == ip_address(host_index))
            index = 0;

		else if (msb == 'hc0a800 && ip_addr != 'hc0a80000)
		begin
			index = truncate(ip_addr[7:0]) - 1;
			if (index < truncate((ip_address(host_index))[7:0]))
				index = index + 1;
		end

        else
			index = fromInteger(valueof(NUM_OF_SERVERS));

        return index;
    endfunction

    // 0th entry in the schedule table will always contain the info of the
    // host server. Entries 1 to NUM_OF_SERVERS-1 will contain info of the
    // remaining servers. As there will be a total of NUM_OF_SERVERS-1 time
    // slots, so the size of schedule_list is NUM_OF_SERVERS-1.
    //
    // schedule_list[i] = j means in time slot i, send pkt to server at index
    // j in the schedule table.

    rule configure_scheduling (curr_state == RUN && configure == 1);
        configure <= 0;
        for (Integer i = 0; i < valueof(NUM_OF_SERVERS)-1; i = i + 1)
        begin
            schedule_list[i] <= fromInteger(i) + 1;
            if (verbose)
            $display("[SCHED (%d)] schedule_list[%d] = %d", host_index, i, i+1);
        end
        start_scheduling_flag <= 1;
    endrule

    rule start_scheduling (curr_state == RUN && start_scheduling_flag == 1);
        start_scheduling_flag <= 0;
        start_polling_rx_buffer <= 1;
		start_tx_scheduling <= 1;
    endrule

/*-------------------------------------------------------------------------------*/
                                  // Rx Path
/*-------------------------------------------------------------------------------*/
    Vector#(NUM_OF_ALTERA_PORTS, Reg#(IP)) recvd_pkt_src_ip <- replicateM(mkReg(0));
    Vector#(NUM_OF_ALTERA_PORTS, Reg#(IP)) recvd_pkt_dst_ip <- replicateM(mkReg(0));
    Vector#(NUM_OF_ALTERA_PORTS, Reg#(Bit#(1)))
                                        recvd_pkt_ctrl_bits <- replicateM(mkReg(0));
    Vector#(NUM_OF_ALTERA_PORTS, Reg#(Bit#(16)))
                                        recvd_pkt_flow_id <- replicateM(mkReg(0));
    Vector#(NUM_OF_ALTERA_PORTS, Reg#(Bit#(16)))
                                        recvd_pkt_seq_num <- replicateM(mkReg(0));
    Vector#(NUM_OF_ALTERA_PORTS, Reg#(Bit#(1)))
                              check_flow_add_remove_rx_flag <- replicateM(mkReg(0));

    Vector#(NUM_OF_ALTERA_PORTS, FIFO#(FlowUpdateT))
          flow_update_fifo_rx <- replicateM(mkSizedFIFO(valueof(DEFAULT_FIFO_LEN)));

	// should be atleast as large as buffer_depth + max num of data blocks
    Vector#(NUM_OF_ALTERA_PORTS, FIFOF#(RingBufferDataT)) buffer_fifo
	                    <- replicateM(mkSizedFIFOF(valueof(DEFAULT_FIFO_LEN)));
    Vector#(NUM_OF_ALTERA_PORTS, FIFOF#(ServerIndex)) ring_buffer_index_fifo
                 <- replicateM(mkSizedFIFOF((valueof(NUM_OF_ALTERA_PORTS)+1)));
    Vector#(NUM_OF_ALTERA_PORTS, Reg#(Bit#(1)))
                 ready_to_deq_from_index_buffer <- replicateM(mkReg(1));
    Vector#(NUM_OF_ALTERA_PORTS, Reg#(Bit#(1)))
                  ready_to_deq_from_ring_buffer <- replicateM(mkReg(0));

    /* Stores the number of data blocks to buffer */
    Vector#(NUM_OF_ALTERA_PORTS, Reg#(int)) buffer_depth <- replicateM(mkReg(3));

    //
    // Have to buffer first 3 data blocks to get to dst IP addr
    //
    // Assumption here is that the MAC Frame structure is as shown
    // ------------------------------------------------------
    // | dst MAC | src MAC | ether type | IP header | Payload |
    // ------------------------------------------------------
    // So, no VLAN tags etc.
    //

    Vector#(NUM_OF_ALTERA_PORTS, Reg#(Bit#(384))) buffered_data <- replicateM(mkReg(0));

    Vector#(NUM_OF_ALTERA_PORTS, Reg#(Bit#(1))) stop_polling <- replicateM(mkReg(0));

    Vector#(NUM_OF_ALTERA_PORTS, Reg#(ServerIndex)) curr_ring_buffer_index
                        <- replicateM(mkReg(fromInteger(valueof(NUM_OF_SERVERS))));

    Vector#(NUM_OF_SERVERS, FIFOF#(PortIndex))
    token_queue <- replicateM(mkSizedFIFOF(valueof(NUM_OF_SERVERS)));

    for (Integer i = 0; i < valueof(NUM_OF_ALTERA_PORTS); i = i + 1)
    begin
        rule check_flow_add_remove_rx (check_flow_add_remove_rx_flag[i] == 1);
            check_flow_add_remove_rx_flag[i] <= 0;

            /* Check if the flow already exits */
            ServerIndex src = host_id(recvd_pkt_src_ip[i]);
            ServerIndex dst = host_id(recvd_pkt_dst_ip[i]);

            if (src < fromInteger(valueof(NUM_OF_SERVERS))
                && dst < fromInteger(valueof(NUM_OF_SERVERS)))
            begin
                if (recvd_pkt_ctrl_bits[i] == 'b1)
                begin
                    let d = FlowUpdateT {
                                src : src,
                                dst : dst,
                                flow_id : recvd_pkt_flow_id[i],
                                seq_num : recvd_pkt_seq_num[i],
                                op  : 0
                            };
                    flow_update_fifo_rx[i].enq(d);
                end

                else
                begin
                    let d = FlowUpdateT {
                                src : src,
                                dst : dst,
                                flow_id : recvd_pkt_flow_id[i],
                                seq_num : recvd_pkt_seq_num[i],
                                op  : 1
                            };
                    flow_update_fifo_rx[i].enq(d);
                end
            end
        endrule

        rule start_polling_rx (curr_state == RUN && start_polling_rx_buffer == 1
                               && stop_polling[i] == 0);
            let ring_buf_empty <- rx_ring_buffer[i].empty;

            if (!ring_buf_empty)
            begin
				num_of_pkt_received_reg[i] <= num_of_pkt_received_reg[i] + 1;
                rx_ring_buffer[i].read_request.put(makeReadReq(READ));
				stop_polling[i] <= 1;
            end
        endrule


// Buf Reg 383    336 337   289              175   144 143    112         0
//          ---------------------------------------------------------------
//         | dst MAC | src MAC | .....|..... | src IP | dst | IP | Payload |
//          ---------------------------------------------------------------
// Memory  0                       127  128              255  256        383

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
                    if (d.data.sop == 0 && d.data.eop == 1)
                    begin
                        /* reset state */
                        buffer_depth[i] <= 3;  //no of data blocks to buffer
                        buffered_data[i] <= 0;
						ring_buffer_index_fifo[i].enq(0);
                    end
					else
					begin
						buffer_depth[i] <= buffer_depth[i] - 1;
						Bit#(384) pload = zeroExtend(d.data.payload);
						buffered_data[i] <= buffered_data[i] | (pload
									<< (fromInteger(valueof(BUS_WIDTH))
											   * (buffer_depth[i]-1)));
					end
                end

                else if (buffer_depth[i] == 0) /* already buffered 3 data blocks */
                begin
                    if (d.data.sop == 0 && d.data.eop == 1)
                    begin
                        /* reset state */
                        buffer_depth[i] <= 3;  //num of data blocks to buffer
                        buffered_data[i] <= 0;
                    end
                    else
                        buffer_depth[i] <= buffer_depth[i] - 1;

                    /* Find the index of the ring buffer to insert to. */
                    IP dst_ip = (buffered_data[i])[143:112];
                    IP src_ip = (buffered_data[i])[175:144];
                    Bit#(1) ctrl_bits = (buffered_data[i])[258];

                    /* Check if a flow is to be added or removed */
                    recvd_pkt_src_ip[i] <= src_ip;
                    recvd_pkt_dst_ip[i] <= dst_ip;
                    recvd_pkt_ctrl_bits[i] <= ctrl_bits;
                    recvd_pkt_flow_id[i] <= (buffered_data[i])[255:240];
                    recvd_pkt_seq_num[i] <= (buffered_data[i])[239:224];
                    check_flow_add_remove_rx_flag[i] <= 1;

                    if (dst_ip == ip_address(host_index))
                        ring_buffer_index_fifo[i].enq(0);
                    else
                    begin
                        ServerIndex index = ipToIndexMapping(dst_ip);
						if (index >= fromInteger(valueof(NUM_OF_SERVERS)))
                        begin
                            ring_buffer_index_fifo[i].enq(0);
                        end
                        else
                            ring_buffer_index_fifo[i].enq(index);

                        if (verbose)
                            $display("[SCHED (%d)] Adding idx = %d to idx fifo %d",
                                     host_index, index, i);
                    end
                end

                else if (d.data.sop == 0 && d.data.eop == 1)
                begin
                    /* reset state */
                    buffer_depth[i] <= 3;  //num of data blocks to buffer
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

        for (Integer j = 0; j < valueof(NUM_OF_SERVERS); j = j + 1)
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
         port_idx <- replicateM(mkReg(fromInteger(valueof(NUM_OF_ALTERA_PORTS))));

	Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) wait_for_completion
	                                            <- replicateM(mkReg(0));

    Vector#(NUM_OF_ALTERA_PORTS, Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))))
            dont_add_to_buffer <- replicateM(replicateM(mkReg(0)));

    for (Integer j = 0; j < valueof(NUM_OF_SERVERS); j = j + 1)
    begin
        rule deq_from_token_queue (curr_state == RUN
			                       && wait_for_completion[j] == 0);
            let port_index <- toGet(token_queue[j]).get;
            port_idx[j] <= port_index;
            if (verbose)
                $display("[SCHED (%d)] port_idx[%d] = %d",host_index,j,port_index);
			wait_for_completion[j] <= 1;
        endrule

        for (Integer i = 0; i < valueof(NUM_OF_ALTERA_PORTS); i = i + 1)
        begin
            rule add_to_correct_ring_buffer (curr_state == RUN
                                        && port_idx[j] == fromInteger(i)
                                        && ready_to_deq_from_ring_buffer[i] == 1);
                let d <- toGet(buffer_fifo[i]).get;
				if (d.sop == 1 && d.eop == 0)
                begin
					stop_polling[i] <= 0;
                    if (d.payload[2] == 1)
                        dont_add_to_buffer[i][j] <= 1;
                end

                else if (d.sop == 0 && d.eop == 1)
                begin
                    ready_to_deq_from_index_buffer[i] <= 1;
                    ready_to_deq_from_ring_buffer[i] <= 0;
					wait_for_completion[j] <= 0;
                    port_idx[j] <= fromInteger(valueof(NUM_OF_ALTERA_PORTS));
                    dont_add_to_buffer[i][j] <= 0;
                end

                if (dont_add_to_buffer[i][j] == 0)
                begin
                    if (j != 0)
                        ring_buffer[1][j].write_request.put
                                        (makeWriteReq(d.sop, d.eop, d.payload));
                    else
                        src_rx_ring_buffer.write_request.put
                                        (makeWriteReq(d.sop, d.eop, d.payload));
                    if (verbose)
                        $display("[SCHED (%d)] CLK = %d buffer index to put data = %d data = %d %d %x", host_index, clk.currTime(), j, d.sop, d.eop, d.payload);
                end
            endrule
        end
    end

/*------------------------------------------------------------------------------*/
                                  // Tx Path
/*------------------------------------------------------------------------------*/
    Reg#(ServerIndex) curr_slot <- mkReg(0);
    Reg#(MAC) dst_mac_addr <- mkReg(0);

    FIFO#(FlowUpdateT) flow_update_fifo_tx <- mkSizedFIFO(valueof(DEFAULT_FIFO_LEN));

    Reg#(Bit#(16)) curr_epoch <- mkReg(0);
    Vector#(NUM_OF_SERVERS, Reg#(Bit#(1)))
                        get_host_flow_for_next_slot <- replicateM(mkReg(0));
    Reg#(Bit#(1)) wait_for_insert_to_complete <- mkReg(0);
    Reg#(ServerIndex) flow_to_send_next <- mkReg(fromInteger(valueof(NUM_OF_SERVERS)));

    FIFO#(FlowStartEndT) flows <- mkSizedFIFO(2*valueof(NUM_OF_SERVERS));
    Reg#(Bit#(1)) new_flow_blast_phase <- mkReg(0);
    Reg#(ServerIndex) new_flow_blast_count <- mkReg(0);
    Reg#(ServerIndex) new_flow_dst <- mkReg(fromInteger(valueof(NUM_OF_SERVERS)));

    Reg#(Bit#(1)) flow_end_blast_phase <- mkReg(0);
    Reg#(ServerIndex) flow_end_blast_count <- mkReg(0);
    Reg#(Bool) special_buffer <- mkReg(False);

    rule check_for_flow_start_end (new_flow_blast_phase == 0
                                  && flow_end_blast_phase == 0);
        let x <- toGet(flows).get;
        new_flow_dst <= x.dst;
        if (x.flow_start == 1)
            new_flow_blast_phase <= 1;
        else
            flow_end_blast_phase <= 1;

        let d = FlowUpdateT {
                    src : host_index,
                    dst : x.dst,
                    flow_id : 0,
                    seq_num : 0,
                    op  : x.flow_start
                };
        flow_update_fifo_tx.enq(d);
    endrule

    FIFO#(BottleneckCountParams) bottleneck_count_req_fifo <- mkBypassFIFO;
    FIFO#(ServerIndex) bottleneck_count_res_fifo <- mkBypassFIFO;
    Reg#(ServerIndex) node_value <- mkReg(0);

    rule get_bottleneck_count;
        let x <- toGet(bottleneck_count_req_fifo).get;
        bottleneck_count_res_fifo.enq(mmf.getBottleneckCount(x.src, x.dst, x.mid));
    endrule

    for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
    begin
        rule get_next_flow (get_host_flow_for_next_slot[i] == 1
                            && wait_for_insert_to_complete == 0);
            ServerIndex table_index = schedule_list[curr_slot];
            IP dst_ip_addr = sched_table[table_index].server_ip;

            get_host_flow_for_next_slot[i] <= 0;

            if (new_flow_blast_phase == 0 && flow_end_blast_phase == 0)
            begin
                let x <- min_priority_queue[i].first;
                min_priority_queue[i].deq;
                if (x.p <= curr_epoch+1)
                begin
                    let d = BottleneckCountParams {
                                src : host_index,
                                dst : truncate(x.v),
                                mid : host_id(dst_ip_addr)
                            };
                    bottleneck_count_req_fifo.enq(d);
                    node_value <= truncate(x.v);
                    flow_to_send_next <= truncate(x.v);
                end
                else
                    flow_to_send_next <= fromInteger(valueof(NUM_OF_SERVERS));

                special_buffer <= False;
            end

            else if (new_flow_blast_phase == 1 && flow_end_blast_phase == 0)
            begin
                flow_to_send_next <= new_flow_dst;
                special_buffer <= False;
                let d = BottleneckCountParams {
                            src : host_index,
                            dst : truncate(new_flow_dst),
                            mid : host_id(dst_ip_addr)
                        };
                bottleneck_count_req_fifo.enq(d);
                node_value <= new_flow_dst;
                if (new_flow_blast_count == fromInteger(valueof(NUM_OF_SERVERS))-2)
                begin
                    new_flow_blast_count <= 0;
                    new_flow_blast_phase <= 0;
                end
                else
                    new_flow_blast_count <= new_flow_blast_count + 1;
            end

            else if (new_flow_blast_phase == 0 && flow_end_blast_phase == 1)
            begin
                flow_to_send_next <= new_flow_dst;
                special_buffer <= True;
                // TODO remove the flow from PriQ
                if (flow_end_blast_count == fromInteger(valueof(NUM_OF_SERVERS))-2)
                begin
                    flow_end_blast_count <= 0;
                    flow_end_blast_phase <= 0;
                end
                else
                    flow_end_blast_count <= flow_end_blast_count + 1;
            end
        endrule

        rule update_and_insert;
            let x <- toGet(bottleneck_count_res_fifo).get;
            Node#(Bit#(16), Bit#(16)) n = Node {
                        v : zeroExtend(node_value),
                        p : curr_epoch + 1 + zeroExtend(x)
                     };
            min_priority_queue[i].insert_req.put(n);
            wait_for_insert_to_complete <= 1;
        endrule

        rule insert_res;
            let x <- toGet(min_priority_queue[i].insert_res).get;
            wait_for_insert_to_complete <= 0;
        endrule
    end

    rule get_dst_addr (curr_state == RUN && start_tx_scheduling == 1);
		Bit#(64) curr_time = clk.currTime();

		Bit#(3) clock_lsb_three_bits = curr_time[2:0];
		if (clock_lsb_three_bits == 0)
		begin
            if (curr_slot == (fromInteger(valueof(NUM_OF_SERVERS))-2))
            begin
                curr_slot <= 0;
                curr_epoch <= curr_epoch + 1;
            end
            else
                curr_slot <= curr_slot + 1;

            /* Gather info about next slot */
            ServerIndex next_slot =
                (curr_slot == (fromInteger(valueof(NUM_OF_SERVERS))-2))
                ? 0 : (curr_slot + 1);
			ServerIndex next_table_index = schedule_list[curr_slot];
			IP next_dst_ip_addr = sched_table[next_table_index].server_ip;
            get_host_flow_for_next_slot[ipToIndexMapping(next_dst_ip_addr)] <= 1;

			if (verbose)
            $display("[SCHED (%d)] CLK = %d  schedule_list[%d] = %d", host_index,
                            curr_time, curr_slot, schedule_list[curr_slot]);

            num_of_time_slots_used_reg <= num_of_time_slots_used_reg + 1;

			/* Get the dst mac and ip addr */
			ServerIndex table_index = schedule_list[curr_slot];
			dst_mac_addr <= sched_table[table_index].server_mac;
			IP dst_ip_addr = sched_table[table_index].server_ip;

			if (verbose)
				$display("[SCHED (%d)] CLK = %d MAC = %x IP = %x", host_index,
				clk.currTime(), sched_table[table_index].server_mac,
			    dst_ip_addr);

			/* Get the index of the ring buffer to extract from */
			ServerIndex index = ipToIndexMapping(dst_ip_addr);

			measure <= index;

			if (verbose)
			$display("[SCHED (%d)] CLK = %d  buffer index to extract from = %d %d",
				host_index, clk.currTime(), index, ring_buffer[1][index].elements);

			Bool is_empty <- ring_buffer[1][index].empty;
            if (flow_to_send_next == fromInteger(valueof(NUM_OF_SERVERS)) && !is_empty)
				ring_buffer[1][index].read_request.put(makeReadReq(READ));
			else
			begin
                if (special_buffer)
                    ring_buffer[2][flow_to_send_next]
                                     .read_request.put(makeReadReq(PEEK));
                else
                    ring_buffer[0][flow_to_send_next]
                                     .read_request.put(makeReadReq(READ));
			end
		end
    endrule


    Vector#(3, Vector#(NUM_OF_SERVERS, FIFO#(DataToPutInTx)))
        data_to_put <- replicateM(replicateM(mkSizedFIFO(valueof(DEFAULT_FIFO_LEN))));
	Vector#(3, Vector#(NUM_OF_SERVERS, Reg#(PortIndex)))
        tx_port_index <- replicateM(replicateM(mkReg(fromInteger(valueof(NUM_OF_ALTERA_PORTS)))));

    Vector#(3, Vector#(NUM_OF_SERVERS, FIFO#(ReadResType)))
                data_fifo <- replicateM(replicateM(mkBypassFIFO));
	Vector#(3, Vector#(NUM_OF_SERVERS, Wire#(PortIndex)))
        correct_tx_index <- replicateM(replicateM(mkDWire(fromInteger(valueof(NUM_OF_ALTERA_PORTS)))));

    for (Integer k = 0; k < 3; k = k + 1)
    begin
    for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
    begin
        rule update_mac_header (curr_state == RUN);
            let d <- ring_buffer[k][i].read_response.get;
            if (d.data.sop == 1 && d.data.eop == 0)
            begin
                Bit#(96) new_addr = {dst_mac_addr, mac_address(host_index)};
                Bit#(96) zero = 0;
                Bit#(BUS_WIDTH) temp = {zero, '1};
                Bit#(BUS_WIDTH) new_addr_temp = {new_addr, '0};
                d.data.payload = (d.data.payload & temp) | new_addr_temp;

                PortIndex index = machineToPortMapping(host_index, dst_mac_addr);
                tx_port_index[k][i] <= index;

                DataToPutInTx x = DataToPutInTx {
                                    data : d,
                                    tx_port : index
                                };
                data_to_put[k][i].enq(x);
            end
            else
            begin
                DataToPutInTx x = DataToPutInTx {
                                    data : d,
                                    tx_port : tx_port_index[k][i]
                                };
                data_to_put[k][i].enq(x);
            end

            if (k == 0)
                host_pkt_transmitted_reg <= host_pkt_transmitted_reg + 1;
            else
                non_host_pkt_transmitted_reg <= non_host_pkt_transmitted_reg + 1;

            if (verbose)
                $display("[SCHED (%d)] CLK = %d", host_index, clk.currTime());
        endrule

		rule set_correct_tx_index (curr_state == RUN);
			let res <- toGet(data_to_put[k][i]).get;
			ReadResType d = res.data;
			PortIndex idx = res.tx_port;
			data_fifo[k][i].enq(d);
			correct_tx_index[k][i] <= idx;
		if (verbose)
		$display("[SCHED (%d)] CLK = %d data written to tx %d data %d %d %x",
		host_index, clk.currTime(), idx, d.data.sop, d.data.eop, d.data.payload);
		endrule

		for (Integer j = 0; j < valueof(NUM_OF_ALTERA_PORTS); j = j + 1)
		begin
			rule add_to_correct_tx (correct_tx_index[k][i] == fromInteger(j));
				let d <- toGet(data_fifo[k][i]).get;
				tx_ring_buffer[j].write_request.put
					(makeWriteReq(d.data.sop, d.data.eop, d.data.payload));
			endrule
		end
    end
    end

/*-------------------------------------------------------------------------------*/
                        // Manage Flow update requests
/*-------------------------------------------------------------------------------*/
    FIFO#(FlowUpdateT) flow_update_fifo <- mkSizedFIFO(valueof(DEFAULT_FIFO_LEN));

    for (Integer i = 0; i < valueof(NUM_OF_ALTERA_PORTS); i = i + 1)
    begin
        rule enq_to_flow_update_fifo_rx;
            let d <- toGet(flow_update_fifo_rx[i]).get;
            flow_update_fifo.enq(d);
        endrule
    end

    rule enq_to_flow_update_fifo_tx;
        let d <- toGet(flow_update_fifo_tx).get;
        flow_update_fifo.enq(d);
    endrule

    rule update_flow_matrix;
        let d <- toGet(flow_update_fifo).get;

        if (d.op == 0) // remove flow
        begin
            mmf.removeFlow(d.src, d.dst, d.flow_id, d.seq_num);
            mmf.remFromFlowCountMatrix(d.src, d.dst);
        end

        else if (d.op == 1) // add flow
        begin
            mmf.addFlow(d.src, d.dst, d.flow_id, d.seq_num);
            mmf.addToFlowCountMatrix(d.src, d.dst, d.flow_id, d.seq_num);
        end
    endrule

/*-------------------------------------------------------------------------------*/
                            // MAC and DMA Req handlers
/*-------------------------------------------------------------------------------*/
    for (Integer i = 0; i < valueof(NUM_OF_ALTERA_PORTS); i = i + 1)
    begin
        rule handle_rx_buffer_write_req_from_mac;
            let req <- toGet(mac_write_request_fifo[i]).get;
			if (req.data.sop == 1 && req.data.eop == 0)
				num_of_rxWrite_pkt_reg[i] <= num_of_rxWrite_pkt_reg[i] + 1;
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

    for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
    begin
        rule handle_dma_simulator_write_req;
            let req <- toGet(dma_write_request_fifo[i]).get;

            if (verbose)
                $display("[SCHED (%d)] Putting data into host tx buffer %d %d %x",
                        host_index, req.data.sop, req.data.eop, req.data.payload);

            ring_buffer[0][i].write_request.put
                (makeWriteReq(req.data.sop, req.data.eop, req.data.payload));
        endrule

        rule handle_special_buffer_write_req;
            let req <- toGet(special_buf_write_req_fifo[i]).get;
            ring_buffer[2][i].write_request.put
                (makeWriteReq(req.data.sop, req.data.eop, req.data.payload));
        endrule
    end

    rule handle_dma_simulator_read_req;
        let req <- toGet(dma_read_request_fifo).get;
        src_rx_ring_buffer.read_request.put(makeReadReq(READ));
    endrule

    rule consume_pkt_in_response_to_dma_simulator_read_req;
        let d <- src_rx_ring_buffer.read_response.get;
		//debug_consuming_pkt_fifo.enq(d.data);
    endrule

/*-------------------------------------------------------------------------------*/
                      // Interface and Method definitions
/*-------------------------------------------------------------------------------*/
	Vector#(NUM_OF_ALTERA_PORTS, Put#(ReadReqType)) temp1;
	Vector#(NUM_OF_ALTERA_PORTS, Get#(ReadResType)) temp2;
	Vector#(NUM_OF_ALTERA_PORTS, Put#(WriteReqType)) temp3;
	Vector#(NUM_OF_ALTERA_PORTS, Get#(WriteResType)) temp4;
	for (Integer i = 0; i < valueof(NUM_OF_ALTERA_PORTS); i = i + 1)
	begin
		temp1[i] = toPut(mac_read_request_fifo[i]);
		temp2[i] = toGet(mac_read_response_fifo[i]);
		temp3[i] = toPut(mac_write_request_fifo[i]);
		temp4[i] = toGet(mac_write_response_fifo[i]);
	end

    Vector#(NUM_OF_SERVERS, Put#(WriteReqType)) temp5;
    Vector#(NUM_OF_SERVERS, Put#(WriteReqType)) temp6;
    for(Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
    begin
        temp5[i] = toPut(dma_write_request_fifo[i]);
        temp6[i] = toPut(special_buf_write_req_fifo[i]);
    end

	Vector#(NUM_OF_SERVERS, Get#(Vector#(RING_BUFFER_SIZE, Bit#(64)))) temp;
	for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
		temp[i] = toGet(fwd_queue_len_fifo[i]);

	method Action insertToSchedTable(ServerIndex index, IP ip_addr, MAC mac_addr);
		TableData d = TableData {
						server_ip : ip_addr,
						server_mac : mac_addr
		              };
		sched_table[index] <= d;
	endmethod

    method Action timeSlotsCount();
		time_slots_fifo.enq(num_of_time_slots_used_reg);
    endmethod

	method Action hostPktCount();
		host_pkt_fifo.enq(host_pkt_transmitted_reg);
	endmethod

	method Action nonHostPktCount();
		non_host_pkt_fifo.enq(non_host_pkt_transmitted_reg);
	endmethod

	method Action receivedPktCount();
		Bit#(64) pkt_received = 0;
		for (Integer i = 0; i < valueof(NUM_OF_ALTERA_PORTS); i = i + 1)
			pkt_received = pkt_received + num_of_pkt_received_reg[i];
		received_pkt_fifo.enq(pkt_received);
	endmethod

	method Action rxWritePktCount();
		Bit#(64) rxWrite_pkt = 0;
		for (Integer i = 0; i < valueof(NUM_OF_ALTERA_PORTS); i = i + 1)
			rxWrite_pkt = rxWrite_pkt + num_of_rxWrite_pkt_reg[i];
		rxWrite_pkt_fifo.enq(rxWrite_pkt);
	endmethod

	method Action fwdQueueLen();
		for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
			enq_queue_length[i] <= 1;
	endmethod

	method Action start(ServerIndex serverIdx);
		curr_state <= RUN;
	    configure <= 1;
        start_scheduling_flag <= 0;
        start_polling_rx_buffer <= 0;
        start_tx_scheduling <= 0;
		host_index <= serverIdx;
	endmethod

	method Action stop();
		curr_state <= CONFIG;
        mmf.printMatrix(host_index);
	endmethod

    /* MAC interfaces */
    interface mac_read_request = temp1;
    interface mac_read_response = temp2;
    interface mac_write_request = temp3;
    interface mac_write_response = temp4;

    /* DMA simulator interface */
    interface Put dma_read_request = toPut(dma_read_request_fifo);
    interface Put dma_write_request = temp5;
    interface Get dma_read_response = toGet(dma_read_response_fifo);

    interface Put special_buf_write_req = temp6;

    interface Put flow_notification_req = toPut(flows);

	interface Get time_slots_response = toGet(time_slots_fifo);
	interface Get host_pkt_response = toGet(host_pkt_fifo);
	interface Get non_host_pkt_response = toGet(non_host_pkt_fifo);
	interface Get received_pkt_response = toGet(received_pkt_fifo);
	interface Get rxWrite_pkt_response = toGet(rxWrite_pkt_fifo);
	interface fwd_queue_len = temp;
//	interface Get debug_consuming_pkt = toGet(debug_consuming_pkt_fifo);

endmodule
