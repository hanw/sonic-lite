import FIFO::*;
import FIFOF::*;
import Vector::*;
import DefaultValue::*;
import Random::*;
import GetPut::*;
import Clocks::*;

import Scheduler::*;
import SchedulerTypes::*;
import RingBufferTypes::*;
import Addresses::*;

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
                            payload         : 'h8475920bacccfe5463488baccef4
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
    method Action start(ServerIndex idx, Bit#(32) rate);
    method Action stop();
	method Action getDMAStats();
endinterface

module mkDMASimulator#(Scheduler#(ReadReqType, ReadResType,
                                  WriteReqType, WriteResType) scheduler,
	Clock pcieClock, Reset pcieReset) (DMASimulator);

    Clock defaultClock <- exposeCurrentClock();
    Reset defaultReset <- exposeCurrentReset();

    Reg#(Bool) verbose <- mkReg(False);

	Reg#(ServerIndex) host_index <- mkReg(0);

	SyncFIFOIfc#(DMAStatsT) dma_stats_fifo
	         <- mkSyncFIFO(1, defaultClock, defaultReset, pcieClock);
	Reg#(DMAStatsT) stats <- mkReg(defaultValue);

//	SyncFIFOIfc#(ServerIndex) debug_sending_pkt_fifo
//	         <- mkSyncFIFO(10, defaultClock, defaultReset, pcieClock);

    Reg#(Bit#(32)) count <- mkReg(0);
	Reg#(Bit#(32)) num_of_cycles_to_wait <- mkReg(3);

    Reg#(Bit#(1)) start_flag <- mkReg(0);

	Reg#(Bit#(1)) wait_for_pkt_trans_to_complete <- mkReg(0);
	Reg#(Bit#(1)) start_sending_new_pkt <- mkReg(0);

//	Random rand_dst_index <- mkRandom; // will return a 32-bit random number

    Reg#(Header) header <- mkReg(defaultValue);
    Reg#(ServerIndex) dst_index <- mkReg(0);
    Reg#(Bit#(7)) block_count <- mkReg(0);
    Reg#(Bit#(7)) num_of_blocks_to_transmit <- mkReg(4);
    Reg#(Bit#(1)) transmission_in_progress <- mkReg(0);
    Reg#(Bit#(1)) init_header <- mkReg(0);

	Reg#(Bit#(32)) rate_reg <- mkReg(0);

	rule counter_increment (start_flag == 1
		                    && wait_for_pkt_trans_to_complete == 0);
		if (count == num_of_cycles_to_wait)
		begin
			count <= 0;
			start_sending_new_pkt <= 1;
			wait_for_pkt_trans_to_complete <= 1;
		end
		else
		begin
			count <= count + 1;
		end
	endrule

    rule prepare_pkt_transmission (start_flag == 1 && start_sending_new_pkt == 1
			                       && transmission_in_progress == 0);

		stats.pkt_count <= stats.pkt_count + 1;
		transmission_in_progress <= 1;
		init_header <= 1;
		block_count <= 0;

//          let rand_num <- rand_dst_index.next();
//			ServerIndex r = truncate(rand_num %
//			                fromInteger(valueof(NUM_OF_SERVERS)));
//            if (r == host_index)
//            begin
//				let x = (r + 1) % fromInteger(valueof(NUM_OF_SERVERS));
//                dst_index <= x;
//				debug_sending_pkt_fifo.enq(x);
//            end
//            else
//            begin
//                dst_index <= r;
//				debug_sending_pkt_fifo.enq(r);
//            end
//
		if (host_index != (fromInteger(valueof(NUM_OF_SERVERS))-1))
			dst_index <= host_index + 1;
		else
			dst_index <= 0;
//		debug_sending_pkt_fifo.enq(1);

		num_of_blocks_to_transmit <= 4; /* 64 byte packets */

    endrule

    rule set_up_the_header
            (transmission_in_progress == 1 && init_header == 1);
        init_header <= 0;
        Header h = defaultValue;
        h.src_mac = mac_address(host_index);
        h.src_ip = ip_address(host_index);
        h.dst_mac = mac_address(dst_index);
        h.dst_ip = ip_address(dst_index);
        header <= h;
    endrule

    rule transmit_packet (transmission_in_progress == 1
                          && init_header == 0
                          && block_count < num_of_blocks_to_transmit);
        block_count <= block_count + 1;
        Bit#(384) header_data = pack(header);
        if (block_count == 0)
        begin
            scheduler.dma_write_request.put
                    (makeWriteReq(1, 0, header_data[383:256]));
        end
        else if (block_count == 1)
        begin
            scheduler.dma_write_request.put
                    (makeWriteReq(0, 0, header_data[255:128]));
        end
        else if (block_count == 2)
        begin
            scheduler.dma_write_request.put
                    (makeWriteReq(0, 0, header_data[127:0]));
        end
        else if (block_count == num_of_blocks_to_transmit - 1)
        begin
            transmission_in_progress <= 0;
			wait_for_pkt_trans_to_complete <= 0;
			start_sending_new_pkt <= 0;
            scheduler.dma_write_request.put
                  (makeWriteReq(0, 1, zeroExtend(host_index)));
        end
        else
        begin
            scheduler.dma_write_request.put
                  (makeWriteReq(0, 0, 'hab4eff284ffabeff36277842baffe465));
        end
    endrule

    rule consume_packet_from_host_Rx;
        scheduler.dma_read_request.put(makeReadReq(READ));
    endrule

	Reg#(Bit#(1)) rate_set_flag <- mkReg(0);
	rule decodeRate (rate_set_flag == 1);
		case (rate_reg)
			10      : begin
					  num_of_cycles_to_wait <= 1;
				      count <= 1;
				      end
			9       : begin
					  num_of_cycles_to_wait <= 2;
				      count <= 2;
				      end
			8       : begin
					  num_of_cycles_to_wait <= 3;
				      count <= 3;
				      end
			7       : begin
					  num_of_cycles_to_wait <= 4;
				      count <= 4;
				      end
			6       : begin
					  num_of_cycles_to_wait <= 6;
				      count <= 6;
				      end
			5       : begin
					  num_of_cycles_to_wait <= 9;
				      count <= 9;
				      end
			4       : begin
					  num_of_cycles_to_wait <= 13;
				      count <= 13;
				      end
			3       : begin
					  num_of_cycles_to_wait <= 20;
				      count <= 20;
				      end
			2       : begin
					  num_of_cycles_to_wait <= 34;
				      count <= 34;
				      end
			1       : begin
					  num_of_cycles_to_wait <= 74;
				      count <= 74;
				      end
			default : begin
					  num_of_cycles_to_wait <= 9;
				      count <= 9;
				      end
		endcase
		start_flag <= 1;
		rate_set_flag <= 0;
	endrule

    method Action start(ServerIndex idx, Bit#(32) rate);
        if (verbose)
            $display("[DMA (%d)] Starting..........................", idx);
		rate_reg <= rate;
		host_index <= idx;
		rate_set_flag <= 1;
    endmethod

    method Action stop();
        if (verbose)
            $display("[DMA (%d)] Stopping..........................", host_index);
        start_flag <= 0;
    endmethod

	method Action getDMAStats();
		dma_stats_fifo.enq(stats);
	endmethod

	interface dma_stats_response = toGet(dma_stats_fifo);
//	interface debug_sending_pkt = toGet(debug_sending_pkt_fifo);
endmodule
