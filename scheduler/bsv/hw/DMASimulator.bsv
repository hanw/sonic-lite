import FIFO::*;
import FIFOF::*;
import Vector::*;
import DefaultValue::*;
import GetPut::*;
import Clocks::*;

import Scheduler::*;
import SchedulerTypes::*;
import RingBufferTypes::*;
import Addresses::*;
import GlobalClock::*;

typedef struct {
    MAC dst_mac;
    MAC src_mac;
    Bit#(16) ether_type;
    Bit#(4) version;
    Bit#(4) ihl;
    Bit#(8) diffserv;
    Bit#(16) total_len;
    Bit#(16) identification;
    Bit#(3) flags;
    Bit#(13) frag_offset;
    Bit#(8) ttl;
    Bit#(8) protocol;
    Bit#(16) header_checksum;
    IP src_ip;
    IP dst_ip;
    Bit#(112) payload;
} Header deriving(Bits, Eq);

instance DefaultValue#(Header);
    defaultValue = Header {
                            dst_mac         : 0,
                            src_mac         : 0,
                            ether_type      : 'h0800,
                            version         : 4,
                            ihl             : 12,
                            diffserv        : 0,
                            total_len       : 1500,
                            identification  : 0,
                            flags           : 0,
                            frag_offset     : 0,
                            ttl             : 3,
                            protocol        : 'h06,
                            header_checksum : 'h43ab,
                            src_ip          : 0,
                            dst_ip          : 0,
                            payload         : 'h1475920bacccfe5463488baccef4
                          };
endinstance

typedef struct {
	Bit#(64) pkt_count;
} DMAStatsT deriving(Bits, Eq);

instance DefaultValue#(DMAStatsT);
	defaultValue = DMAStatsT {
						pkt_count : 0
				   };
endinstance

interface DMASimulator;
	interface Get#(DMAStatsT) dma_stats_response;
//	interface Get#(ServerIndex) debug_sending_pkt;
    method Action start(ServerIndex idx, Bit#(32) rate,
		                ServerIndex num_of_servers_transmitting);
    method Action stop();
	method Action getDMAStats();
endinterface

module mkDMASimulator#(Scheduler#(ReadReqType, ReadResType,
                                  WriteReqType, WriteResType) scheduler,
	Clock pcieClock, Reset pcieReset) (DMASimulator);

    Clock defaultClock <- exposeCurrentClock();
    Reset defaultReset <- exposeCurrentReset();

    Reg#(Bool) verbose <- mkReg(False);

    GlobalClock clk <- mkGlobalClock;

	Reg#(ServerIndex) host_index <- mkReg(0);
	Reg#(ServerIndex) num_of_servers_transmitting
						<- mkReg(fromInteger(valueof(NUM_OF_SERVERS)));

	SyncFIFOIfc#(DMAStatsT) dma_stats_fifo
	         <- mkSyncFIFO(1, defaultClock, defaultReset, pcieClock);
    Vector#(NUM_OF_SERVERS, Reg#(Bit#(64))) flow_pkt_count <- replicateM(mkReg(0));

//	SyncFIFOIfc#(ServerIndex) debug_sending_pkt_fifo
//	         <- mkSyncFIFO(10, defaultClock, defaultReset, pcieClock);

    Reg#(Bit#(1)) start_flag <- mkReg(0);
	Reg#(Bit#(32)) num_of_cycles_to_wait <- mkReg(0);
    Reg#(Bit#(64)) dma_start_time <- mkReg(0);

    Vector#(NUM_OF_SERVERS, Reg#(Bit#(32))) count <- replicateM(mkReg(0));

    Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) start_flow <- replicateM(mkReg(0));

	Vector#(NUM_OF_SERVERS, Reg#(Bit#(1)))
        wait_for_pkt_trans_to_complete <- replicateM(mkReg(0));
	Vector#(NUM_OF_SERVERS, Reg#(Bit#(1)))
        start_sending_new_pkt <- replicateM(mkReg(0));

    Vector#(NUM_OF_SERVERS, Reg#(Header)) header <- replicateM(mkReg(defaultValue));
    Vector#(NUM_OF_SERVERS, Reg#(Bit#(7))) block_count <- replicateM(mkReg(0));
    Vector#(NUM_OF_SERVERS, Reg#(Bit#(7)))
        num_of_blocks_to_transmit <- replicateM(mkReg(0));
    Vector#(NUM_OF_SERVERS, Reg#(Bit#(1)))
        transmission_in_progress <- replicateM(mkReg(0));
    Vector#(NUM_OF_SERVERS, Reg#(Bit#(1))) init_header <- replicateM(mkReg(0));

	Reg#(Bit#(32)) rate_reg <- mkReg(0);

    Vector#(NUM_OF_SERVERS, Reg#(Bit#(64))) flow_length <- replicateM(mkReg(0));
    Vector#(NUM_OF_SERVERS, Reg#(Bit#(16))) flow_id <- replicateM(mkReg(1));
    Vector#(NUM_OF_SERVERS, Reg#(Bit#(16))) seq_num <- replicateM(mkReg(1));

    for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
    begin
        rule manage_flows (fromInteger(i) != host_index && start_flag == 1
                        && clk.currTime() == dma_start_time + (2*fromInteger(i)+5));
            count[i] <= num_of_cycles_to_wait;
            flow_length[i] <= 15;
            start_flow[i] <= 1;
        endrule
    end

    for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
    begin
        rule counter_increment (fromInteger(i) != host_index && start_flow[i] == 1
                                && wait_for_pkt_trans_to_complete[i] == 0);
            if (count[i] == num_of_cycles_to_wait)
            begin
                count[i] <= 0;
                start_sending_new_pkt[i] <= 1;
                wait_for_pkt_trans_to_complete[i] <= 1;
            end
            else
            begin
                count[i] <= count[i] + 1;
            end
        endrule

        rule prepare_pkt_transmission (fromInteger(i) != host_index
                                       && start_flow[i] == 1
                                       && start_sending_new_pkt[i] == 1
                                       && transmission_in_progress[i] == 0);

            if (flow_pkt_count[i] == flow_length[i] - 1)
            begin
                start_flow[i] <= 0;
            end

            flow_pkt_count[i] <= flow_pkt_count[i] + 1;

            if (flow_pkt_count[i] == fromInteger(valueof(NUM_OF_SERVERS))-1)
            begin //notify scheduler that a new flow has started
                FlowStartEndT f = FlowStartEndT {
                                    dst : fromInteger(i),
                                    flow_start : 1
                                  };
                scheduler.flow_notification_req.put(f);
            end

            transmission_in_progress[i] <= 1;
            init_header[i] <= 1;
            block_count[i] <= 0;

    //		debug_sending_pkt_fifo.enq(1);

            num_of_blocks_to_transmit[i] <= 4; /* 64 byte packets */
        endrule

        rule set_up_the_header
                (transmission_in_progress[i] == 1 && init_header[i] == 1);
            init_header[i] <= 0;
            Header h = defaultValue;
            h.src_mac = mac_address(host_index);
            h.src_ip = ip_address(host_index);
            h.dst_mac = mac_address(fromInteger(i));
            h.dst_ip = ip_address(fromInteger(i));
            header[i] <= h;
        endrule

        rule transmit_packet (transmission_in_progress[i] == 1
                              && init_header[i] == 0
                              && block_count[i] < num_of_blocks_to_transmit[i]);
            block_count[i] <= block_count[i] + 1;
            Bit#(384) header_data = pack(header[i]);
            if (block_count[i] == 0)
            begin
                if (flow_pkt_count[i] == flow_length[i]) //last pkt in the flow
                begin
                    flow_pkt_count[i] <= 0;
                    header_data[258] = 1;
                    header_data[259] = 1;
                end
                scheduler.dma_write_request[i].put
                        (makeWriteReq(1, 0, header_data[383:256]));
            end
            else if (block_count[i] == 1)
            begin
                Bit#(32) temp = {flow_id[i], seq_num[i]};
                header_data[255:224] = temp;
                seq_num[i] <= seq_num[i] + 1;
                scheduler.dma_write_request[i].put
                        (makeWriteReq(0, 0, header_data[255:128]));
            end
            else if (block_count[i] == 2)
            begin
                if (flow_pkt_count[i] == flow_length[i])
                begin
                    flow_id[i] <= flow_id[i] + 1;
                    seq_num[i] <= 1;
                end
                scheduler.dma_write_request[i].put
                        (makeWriteReq(0, 0, header_data[127:0]));
            end
            else if (block_count[i] == num_of_blocks_to_transmit[i] - 1)
            begin
                transmission_in_progress[i] <= 0;
                wait_for_pkt_trans_to_complete[i] <= 0;
                start_sending_new_pkt[i] <= 0;
                scheduler.dma_write_request[i].put
                      (makeWriteReq(0, 1, zeroExtend(host_index)));
            end
            else
            begin
                scheduler.dma_write_request[i].put
                      (makeWriteReq(0, 0, 'hab4eff284ffabeff36277842baffe465));
            end
        endrule
    end

    rule consume_packet_from_host_Rx;
        scheduler.dma_read_request.put(makeReadReq(READ));
    endrule

	Reg#(Bit#(1)) rate_set_flag <- mkReg(0);
	rule decodeRate (rate_set_flag == 1);
		case (rate_reg)
			10      : begin
					  num_of_cycles_to_wait <= 1;
				      end
			9       : begin
					  num_of_cycles_to_wait <= 2;
				      end
			8       : begin
					  num_of_cycles_to_wait <= 3;
				      end
			7       : begin
					  num_of_cycles_to_wait <= 4;
				      end
			6       : begin
					  num_of_cycles_to_wait <= 6;
				      end
			5       : begin
					  num_of_cycles_to_wait <= 9;
				      end
			4       : begin
					  num_of_cycles_to_wait <= 13;
				      end
			3       : begin
					  num_of_cycles_to_wait <= 20;
				      end
			2       : begin
					  num_of_cycles_to_wait <= 34;
				      end
			1       : begin
					  num_of_cycles_to_wait <= 74;
				      end
			default : begin
					  num_of_cycles_to_wait <= 9;
				      end
		endcase
		start_flag <= 1;
		rate_set_flag <= 0;
	endrule

    method Action start(ServerIndex idx, Bit#(32) rate, ServerIndex n);
        if (verbose)
            $display("[DMA (%d)] Starting..........................", idx);
		rate_reg <= rate;
		host_index <= idx;
		if (n > 0)
			num_of_servers_transmitting <= n;
		rate_set_flag <= 1;
        dma_start_time <= clk.currTime();
    endmethod

    method Action stop();
        if (verbose)
            $display("[DMA (%d)] Stopping..........................", host_index);
        start_flag <= 0;
    endmethod

	method Action getDMAStats();
        Bit#(64) c = 0;
        for (Integer i = 0; i < valueof(NUM_OF_SERVERS); i = i + 1)
            c = c + flow_pkt_count[i];
        DMAStatsT stats = DMAStatsT {
                            pkt_count : c
                          };
		dma_stats_fifo.enq(stats);
	endmethod

	interface dma_stats_response = toGet(dma_stats_fifo);
//	interface debug_sending_pkt = toGet(debug_sending_pkt_fifo);
endmodule
