import Vector::*;
import FIFO::*;
import FIFOF::*;
import ClientServer::*;
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

typedef struct {
	ReadResType data;
	PortIndex tx_port;
} DataToPutInTx deriving(Bits, Eq);

instance DefaultValue#(DataToPutInTx);
	defaultValue = DataToPutInTx {
					data    : defaultValue,
					tx_port : fromInteger(valueof(NUM_OF_ALTERA_PORTS))
				};
endinstance

typedef struct {
    Bit#(THROTTLE_BITS) throttle_value;
    Bit#(1) schedulable;
} HostFlowT deriving(Bits, Eq);

instance DefaultValue#(HostFlowT);
    defaultValue = HostFlowT {
                    throttle_value : 0,
                    schedulable    : 1
                };
endinstance

typedef struct {
    ServerIndex host_flow_index;
    Bit#(64) time_to_send;
} HostFlowTokenT deriving(Bits, Eq);

instance DefaultValue#(HostFlowTokenT);
    defaultValue = HostFlowTokenT {
                    host_flow_index : fromInteger(valueof(NUM_OF_SERVERS)),
                    time_to_send    : maxBound
                };
endinstance

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

    /* Stats interface */
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
    rx_port_buffer <- replicateM(mkRingBuffer(valueof(RING_BUFFER_SIZE)));

    Vector#(NUM_OF_ALTERA_PORTS,
            RingBuffer#(ReadReqType, ReadResType, WriteReqType, WriteResType))
    tx_port_buffer <- replicateM(mkRingBuffer(valueof(RING_BUFFER_SIZE)));

    Vector#(3, Vector#(NUM_OF_SERVERS,
            RingBuffer#(ReadReqType, ReadResType, WriteReqType, WriteResType)))
    ring_buffer;

    //host flow pkt buffer
    ring_buffer[0] <- replicateM(mkRingBuffer(valueof(RING_BUFFER_SIZE)));
    //fwd pkt buffer
    ring_buffer[1] <- replicateM(mkRingBuffer(valueof(RING_BUFFER_SIZE)));
    //dummy pkt buffer
    ring_buffer[2] <- replicateM(mkRingBuffer(valueof(1)));

    RingBuffer#(ReadReqType, ReadResType, WriteReqType, WriteResType)
        src_rx_buffer <- mkRingBuffer(valueof(RING_BUFFER_SIZE));

	Vector#(NUM_OF_SERVERS, Reg#(TableData))
        schedule_table <- replicateM(mkReg(defaultValue));

    Vector#(NUM_OF_SERVERS, FIFO#(IP))
        last_pkt_sent_to <- replicateM(mkSizedFIFO(valueof(DEFAULT_FIFO_LEN)));
    Vector#(NUM_OF_SERVERS, FIFO#(IP))
        last_pkt_recvd_from <- replicateM(mkSizedFIFO(valueof(DEFAULT_FIFO_LEN)));

    Vector#(NUM_OF_SERVERS, Reg#(Bit#(THROTTLE_BITS)))
        num_of_host_pkt_allocated <- replicateM(mkReg(0));

    Vector#(NUM_OF_SERVERS, Vector#(NUM_OF_SERVERS, FIFOF#(Bit#(THROTTLE_BITS))))
        new_throttle_value
            <- replicateM(replicateM(mkSizedFIFOF(valueof(DEFAULT_FIFO_LEN))));

    Vector#(NUM_OF_SERVERS, Vector#(NUM_OF_SERVERS, Reg#(HostFlowT)))
        host_flow_sched_list <- replicateM(replicateM(mkReg(defaultValue)));

    Vector#(NUM_OF_SERVERS, FIFOF#(HostFlowTokenT))
      host_flow_token_queue <- replicateM(mkSizedFIFOF(valueof(DEFAULT_FIFO_LEN)));

    Vector#(NUM_OF_SERVERS, Reg#(Bit#(64))) flow_size <- replicateM(mkReg(0));

    Vector#(NUM_OF_SERVERS, Reg#(Bit#(64))) pkt_scheduled <- replicateM(mkReg(0));

    Vector#(NUM_OF_SERVERS, Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))))
        schedule_host_flow_flag <- replicateM(replicateM(mkReg(0)));

    /* Flags */
    Reg#(Bit#(1)) start_scheduling_flag <- mkReg(0);
    Reg#(Bit#(1)) start_polling_rx_buffer <- mkReg(0);
	Reg#(Bit#(1)) start_tx_scheduling <- mkReg(0);
    Reg#(Bit#(1)) init_fifos <- mkReg(0);

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

    rule start_scheduling (curr_state == RUN && start_scheduling_flag == 1);
        start_scheduling_flag <= 0;
        start_polling_rx_buffer <= 1;
		start_tx_scheduling <= 1;
    endrule

    for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
    begin
        rule initialize_last_pkt_sent_recvd_fifos (curr_state == RUN
                                                    && init_fifos == 1);
            init_fifos <= 0;
            last_pkt_recvd_from[i].enq('h00000000);
            last_pkt_sent_to[i].enq('h00000000);
        endrule
    end

/*-------------------------------------------------------------------------------*/
                                  // Rx Path
/*-------------------------------------------------------------------------------*/
	// should be atleast as large as buffer_depth + max num of data blocks
    Vector#(NUM_OF_ALTERA_PORTS, FIFOF#(RingBufferDataT))
        buffer_fifo <- replicateM(mkSizedFIFOF(valueof(DEFAULT_FIFO_LEN)));

    Vector#(NUM_OF_ALTERA_PORTS, FIFOF#(ServerIndex))
        ring_buffer_index_fifo
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

    Vector#(NUM_OF_ALTERA_PORTS, Reg#(Bit#(384)))
        buffered_data <- replicateM(mkReg(0));

    Vector#(NUM_OF_ALTERA_PORTS, Reg#(Bit#(1)))
        stop_polling <- replicateM(mkReg(0));

    Vector#(NUM_OF_ALTERA_PORTS, Reg#(ServerIndex))
        curr_ring_buffer_index
            <- replicateM(mkReg(fromInteger(valueof(NUM_OF_SERVERS))));

    Vector#(NUM_OF_SERVERS, FIFOF#(PortIndex))
        token_queue <- replicateM(mkSizedFIFOF(valueof(NUM_OF_SERVERS)));

    for (Integer i = 0; i < valueof(NUM_OF_ALTERA_PORTS); i = i + 1)
    begin

        rule start_polling_rx (curr_state == RUN && start_polling_rx_buffer == 1
                               && stop_polling[i] == 0);
            let ring_buf_empty <- rx_port_buffer[i].empty;

            if (!ring_buf_empty)
            begin
				num_of_pkt_received_reg[i] <= num_of_pkt_received_reg[i] + 1;
                rx_port_buffer[i].read_request.put(makeReadReq(READ));
				stop_polling[i] <= 1;
            end
        endrule


// Buf Reg 383    336 335   288              175   144 143    112         0
//          ---------------------------------------------------------------
//         | dst MAC | src MAC | .....|..... | src IP | dst | IP | Payload |
//          ---------------------------------------------------------------
// Memory  0                       127  128              255  256        383

        rule buffer_and_parse_incoming_data (curr_state == RUN);
            let d <- rx_port_buffer[i].read_response.get;

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
                        buffer_depth[i] <= 3;  //num of data blocks to buffer
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
                    MAC src_mac = (buffered_data[i])[335:288];
                    IP dst_ip = (buffered_data[i])[143:112];

                    //Update the throttle value based on feedback
                    Bit#(THROTTLE_BITS) queue_len = (buffered_data[i])[223:208];
                    let flow_dst_ip_addr
                        <- toGet(last_pkt_sent_to[mac_to_host_id(src_mac)]).get;

                    //sanity check
                    if (queue_len == maxBound && flow_dst_ip_addr != 0)
                        $display("******** PROBLEM *********");

                    if (flow_dst_ip_addr != 0)
                    begin
                        ServerIndex idx = ip_to_host_id(flow_dst_ip_addr);
                        new_throttle_value[mac_to_host_id(src_mac)][idx]
                            .enq(queue_len);
                    end

                    if (dst_ip == ip_address(host_index))
                    begin
                        last_pkt_recvd_from[mac_to_host_id(src_mac)]
                            .enq('h00000000);
                        ring_buffer_index_fifo[i].enq(0);
                    end

                    else
                    begin
                        ServerIndex index = ipToIndexMapping(dst_ip);
						if (index >= fromInteger(valueof(NUM_OF_SERVERS)))
                        begin
                            last_pkt_recvd_from[mac_to_host_id(src_mac)]
                                .enq('h00000000);
                            ring_buffer_index_fifo[i].enq(0);
                        end
                        else
                        begin
                            last_pkt_recvd_from[mac_to_host_id(src_mac)]
                                .enq(dst_ip);
                            ring_buffer_index_fifo[i].enq(index);
                        end

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
                    $display("[SCHED (%d)] token_queue[%d].enq(%d)",
                        host_index, j, i);
                curr_ring_buffer_index[i] <= fromInteger(valueof(NUM_OF_SERVERS));
            endrule
        end
    end

    Vector#(NUM_OF_SERVERS, Reg#(PortIndex))
         port_idx <- replicateM(mkReg(fromInteger(valueof(NUM_OF_ALTERA_PORTS))));

	Vector#(NUM_OF_SERVERS, Reg#(Bit#(1)))
        wait_for_completion <- replicateM(mkReg(0));

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
                    if (d.payload[0] == 1)
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
                        src_rx_buffer.write_request.put
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

    Reg#(Bit#(64)) curr_epoch <- mkReg(0);

    Reg#(ServerIndex) host_flow_to_send
        <- mkReg(fromInteger(valueof(NUM_OF_SERVERS)));
    Vector#(NUM_OF_SERVERS, Reg#(ServerIndex)) counter
        <- replicateM(mkReg(fromInteger(valueof(NUM_OF_SERVERS))));
    Vector#(NUM_OF_SERVERS, Reg#(Bit#(64))) start_epoch <- replicateM(mkReg(0));
    Vector#(NUM_OF_SERVERS, Reg#(Bit#(64))) fwd_ring_buffer_len
        <- replicateM(mkReg(0));

    Reg#(ServerIndex) fwd_ring_buffer_index
        <- mkReg(fromInteger(valueof(NUM_OF_SERVERS)));

    for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
    begin //i represents the intermediate node
        for (Integer j = 0; j < valueof(NUM_OF_SERVERS); j = j + 1)
        begin //j represents the host flow index via i
            rule update_with_new_throttle_value;
                let throttle_value <- toGet(new_throttle_value[i][j]).get;
                HostFlowT h = HostFlowT {
                    throttle_value : throttle_value,
                    schedulable    : 1
                };
                host_flow_sched_list[i][j] <= h;
                schedule_host_flow_flag[i][j] <= 1;
            endrule

            rule schedule_host_flow (counter[i] == fromInteger(j)
                                    || schedule_host_flow_flag[i][j] == 1);
                if (schedule_host_flow_flag[i][j] == 1)
                    schedule_host_flow_flag[i][j] <= 0;

                if (counter[i] == fromInteger(j))
                    counter[i] <= counter[i] + 1;

                //schedule host flow
                Bit#(THROTTLE_BITS) queue_len = truncate(fwd_ring_buffer_len[i])
                                            + num_of_host_pkt_allocated[i];

                Bit#(1) schedulable = 1;
                if (host_flow_sched_list[i][j].schedulable == 1
                    && pkt_scheduled[j] < flow_size[j]
                    && queue_len >= host_flow_sched_list[i][j].throttle_value)
                begin
                    HostFlowTokenT tok = HostFlowTokenT {
                        host_flow_index : fromInteger(j),
                        time_to_send    : start_epoch[i] + extend(queue_len)
                    };
                    host_flow_token_queue[i].enq(tok);
                    schedulable = 0;
                    num_of_host_pkt_allocated[i]
                        <= num_of_host_pkt_allocated[i] + 1;
                    pkt_scheduled[j] <= pkt_scheduled[j] + 1;
                end

                //update the host flow schedule list
                HostFlowT h = HostFlowT {
                    throttle_value :
                        (host_flow_sched_list[i][j].throttle_value == 0)
                        ? host_flow_sched_list[i][j].throttle_value
                        : host_flow_sched_list[i][j].throttle_value - 1,
                    schedulable    : schedulable
                };
                host_flow_sched_list[i][j] <= h;
            endrule
        end
    end

    rule get_dst_addr (curr_state == RUN && start_tx_scheduling == 1);
		Bit#(64) curr_time = clk.currTime();

        //3 bits because each timeslot is 8 cycles long
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

            num_of_time_slots_used_reg <= num_of_time_slots_used_reg + 1;

			/* Get the dst mac and ip addr */
			dst_mac_addr <= schedule_table[curr_slot+1].server_mac;
			IP dst_ip_addr = schedule_table[curr_slot+1].server_ip;

			/* Get the index of the fwd buffer to extract from */
            fwd_ring_buffer_index <= ipToIndexMapping(dst_ip_addr);
            Bit#(64) num_of_fwd_pkt
                <- ring_buffer[1][ipToIndexMapping(dst_ip_addr)].elements;

            if (host_flow_token_queue[ip_to_host_id(dst_ip_addr)].notEmpty)
            begin
                let x = host_flow_token_queue[ip_to_host_id(dst_ip_addr)].first;
                ServerIndex host_flow_index = x.host_flow_index;
                Bit#(64) time_to_send = x.time_to_send;

                if (time_to_send <= curr_epoch)
                begin
                    host_flow_token_queue[ip_to_host_id(dst_ip_addr)].deq;

                    num_of_host_pkt_allocated[ip_to_host_id(dst_ip_addr)]
                      <= num_of_host_pkt_allocated[ip_to_host_id(dst_ip_addr)] - 1;

                    last_pkt_sent_to[ip_to_host_id(dst_ip_addr)]
                        .enq(ip_address(host_flow_index));

                    host_flow_to_send <= host_flow_index;

                    fwd_ring_buffer_len[ip_to_host_id(dst_ip_addr)]
                        <= num_of_fwd_pkt;
                end
                else
                begin
                    last_pkt_sent_to[ip_to_host_id(dst_ip_addr)].enq('h00000000);
                    host_flow_to_send <= fromInteger(valueof(NUM_OF_SERVERS));
                    fwd_ring_buffer_len[ip_to_host_id(dst_ip_addr)]
                        <= (num_of_fwd_pkt == 0) ? 0 : (num_of_fwd_pkt - 1);
                end
            end
            else
            begin
                last_pkt_sent_to[ip_to_host_id(dst_ip_addr)].enq('h00000000);
                host_flow_to_send <= fromInteger(valueof(NUM_OF_SERVERS));
                fwd_ring_buffer_len[ip_to_host_id(dst_ip_addr)]
                    <= (num_of_fwd_pkt == 0) ? 0 : (num_of_fwd_pkt - 1);
            end

			measure <= ipToIndexMapping(dst_ip_addr);

            counter[ip_to_host_id(dst_ip_addr)] <= 0;
            start_epoch[ip_to_host_id(dst_ip_addr)] <= curr_epoch;

			if (verbose)
                $display("[SCHED (%d)] CLK = %d fwd buffer index = %d (size = %d)",
                    host_index, clk.currTime(), ipToIndexMapping(dst_ip_addr),
                    ring_buffer[1][ipToIndexMapping(dst_ip_addr)].elements);
        end
    endrule

    for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
    begin
        rule extract_from_correct_ring_buffer
            (fwd_ring_buffer_index == fromInteger(i));

            fwd_ring_buffer_index <= fromInteger(valueof(NUM_OF_SERVERS));

            if (host_flow_to_send == fromInteger(valueof(NUM_OF_SERVERS)))
            begin
                Bool is_empty <- ring_buffer[1][i].empty;
                if (!is_empty)
                begin
                    if (host_index == 0)
                        $display("Forwarding from index = %d", i);
                    ring_buffer[1][i].read_request.put(makeReadReq(READ));
                end
                else
                begin
                    if (host_index == 0)
                        $display("Sending dummy packet");
                    ring_buffer[2][i].read_request.put(makeReadReq(PEEK));
                end
            end

            else
            begin
                Bool is_empty <- ring_buffer[0][host_flow_to_send].empty;
                if (!is_empty)
                begin
                    if (host_index == 0)
                        $display("Sending host pkt from index = %d",
                            host_flow_to_send);
                    ring_buffer[0][host_flow_to_send]
                        .read_request.put(makeReadReq(READ));
                end
                else
                begin
                    if (host_index == 0)
                        $display("Sending dummy packet");
                    ring_buffer[2][host_flow_to_send]
                        .read_request.put(makeReadReq(PEEK));
                end
            end
        endrule
    end

    Vector#(3, Vector#(NUM_OF_SERVERS, FIFO#(DataToPutInTx))) data_to_put
        <- replicateM(replicateM(mkSizedFIFO(valueof(DEFAULT_FIFO_LEN))));

	Vector#(3, Vector#(NUM_OF_SERVERS, Reg#(PortIndex))) tx_port_index
        <- replicateM(replicateM(mkReg(fromInteger(valueof(NUM_OF_ALTERA_PORTS)))));

    Vector#(3, Vector#(NUM_OF_SERVERS, FIFO#(ReadResType)))
        data_fifo <- replicateM(replicateM(mkBypassFIFO));

	Vector#(3, Vector#(NUM_OF_SERVERS, Wire#(PortIndex))) correct_tx_index
        <- replicateM(replicateM(mkDWire(fromInteger(valueof(NUM_OF_ALTERA_PORTS)))));

    Vector#(3, Vector#(NUM_OF_SERVERS, Reg#(Bit#(2))))
        block_count <- replicateM(replicateM(mkReg(0)));

    for (Integer k = 0; k < 3; k = k + 1)
    begin
        for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
        begin
            rule update_mac_header (curr_state == RUN);
                let d <- ring_buffer[k][i].read_response.get;

                block_count[k][i] <= block_count[k][i] + 1;

                //piggyback remote queue len
                if (block_count[k][i] == 1)
                begin
                    let flow_dst_ip_addr
                        <- toGet(last_pkt_recvd_from[mac_to_host_id(dst_mac_addr)])
                          .get;
                    Bit#(THROTTLE_BITS) queue_len = maxBound;
                    if (flow_dst_ip_addr != 0)
                    begin
                        ServerIndex fwd_buffer_index
                            = ipToIndexMapping(flow_dst_ip_addr);
                        Bit#(64) fwd_buffer_len
                            <- ring_buffer[1][fwd_buffer_index].elements;
                        queue_len = truncate(fwd_buffer_len)
                            + num_of_host_pkt_allocated
                                [ip_to_host_id(flow_dst_ip_addr)];
                    end

                    Bit#(BUS_WIDTH) mask1 = {32'hffffffff, 16'h0000, '1};
                    Bit#(BUS_WIDTH) mask2 = {32'h00000000, queue_len, '0};
                    d.data.payload = (d.data.payload & mask1) | mask2;
                end

                if (block_count[k][i] == 0)
                begin
                    Bit#(96) new_addr = {dst_mac_addr, mac_address(host_index)};
                    Bit#(96) zero = 0;
                    Bit#(BUS_WIDTH) temp = {zero, '1};
                    Bit#(BUS_WIDTH) new_addr_temp = {new_addr, '0};
                    d.data.payload = (d.data.payload & temp) | new_addr_temp;

                    PortIndex index =
                        machineToPortMapping(host_index, dst_mac_addr);

                    tx_port_index[k][i] <= index;

                    DataToPutInTx x = DataToPutInTx {
                                        data : d,
                                        tx_port : index
                                    };
                    data_to_put[k][i].enq(x);

                    if (k == 0 || k == 2)
                        host_pkt_transmitted_reg <= host_pkt_transmitted_reg + 1;
                    else
                        non_host_pkt_transmitted_reg
                            <= non_host_pkt_transmitted_reg + 1;
                end
                else
                begin
                    DataToPutInTx x = DataToPutInTx {
                                        data : d,
                                        tx_port : tx_port_index[k][i]
                                    };
                    data_to_put[k][i].enq(x);
                end

                if (verbose)
                    $display("[SCHED (%d)] CLK = %d", host_index, clk.currTime());
            endrule

            rule set_correct_tx_index (curr_state == RUN);
                let res <- toGet(data_to_put[k][i]).get;
                ReadResType d = res.data;
                PortIndex idx = res.tx_port;
                data_fifo[k][i].enq(d);
                correct_tx_index[k][i] <= idx;
                //if (verbose)
                    $display("[SCHED (%d)] CLK = %d data %d %d %x writen to tx %d",
                        host_index, clk.currTime(), idx,
                        d.data.sop, d.data.eop, d.data.payload);
            endrule

            for (Integer j = 0; j < valueof(NUM_OF_ALTERA_PORTS); j = j + 1)
            begin
                rule add_to_correct_tx (correct_tx_index[k][i] == fromInteger(j));
                    let d <- toGet(data_fifo[k][i]).get;
                    tx_port_buffer[j].write_request.put
                        (makeWriteReq(d.data.sop, d.data.eop, d.data.payload));
                endrule
            end
        end
    end

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
			rx_port_buffer[i].write_request.put
					  (makeWriteReq(req.data.sop, req.data.eop, req.data.payload));
        endrule

        rule handle_tx_buffer_read_req_from_mac;
            let req <- toGet(mac_read_request_fifo[i]).get;
            tx_port_buffer[i].read_request.put(makeReadReq(req.op));
        endrule

        rule send_tx_buffer_read_res_to_mac;
            let d <- tx_port_buffer[i].read_response.get;
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

            if (req.data.sop == 0 && req.data.eop == 1)
                flow_size[i] <= flow_size[i] + 1;

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
        src_rx_buffer.read_request.put(makeReadReq(READ));
    endrule

    rule consume_pkt_in_response_to_dma_simulator_read_req;
        let d <- src_rx_buffer.read_response.get;
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
		schedule_table[index] <= d;
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
        start_scheduling_flag <= 1;
        start_polling_rx_buffer <= 0;
        start_tx_scheduling <= 0;
        init_fifos <= 1;
		host_index <= serverIdx;
	endmethod

	method Action stop();
		curr_state <= CONFIG;
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

    /* Stats interface */
	interface Get time_slots_response = toGet(time_slots_fifo);
	interface Get host_pkt_response = toGet(host_pkt_fifo);
	interface Get non_host_pkt_response = toGet(non_host_pkt_fifo);
	interface Get received_pkt_response = toGet(received_pkt_fifo);
	interface Get rxWrite_pkt_response = toGet(rxWrite_pkt_fifo);
	interface fwd_queue_len = temp;
//	interface Get debug_consuming_pkt = toGet(debug_consuming_pkt_fifo);

endmodule
