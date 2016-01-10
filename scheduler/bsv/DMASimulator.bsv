import Vector::*;
import DefaultValue::*;
import Randomizable::* ;
import GetPut::*;

import Scheduler::*;
import SchedulerTypes::*;
import RingBufferTypes::*;
import Addresses::*;

typedef struct {
    Bit#(112) payload;
    IP dst_ip;
    IP src_ip;
    Bit#(16) header_checksum;
    Bit#(8) protocol;
    Bit#(8) ttl;
    Bit#(13) frag_offset;
    Bit#(3) flags;
    Bit#(16) identification;
    Bit#(16) total_len;
    Bit#(8) diffserv;
    Bit#(4) ihl;
    Bit#(4) version;

    Bit#(16) ether_type;
    MAC src_mac;
    MAC dst_mac;
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

interface DMASimulator;
    method Action start();
    method Action stop();
endinterface

module mkDMASimulator#(Integer host_index,
    Scheduler#(SchedReqResType, SchedReqResType,
               ReadReqType, ReadResType,
               WriteReqType, WriteResType) scheduler) (DMASimulator);

    Reg#(Bool) verbose <- mkReg(False);

    Reg#(Bit#(64)) count <- mkReg(0);
    Reg#(Bit#(1)) start_flag <- mkReg(0);

    Randomize#(Bit#(4)) rand_dst_index <- mkConstrainedRandomizer
                                    (0, fromInteger(valueof(NUM_OF_SERVERS))-1);


    Reg#(Header) header <- mkReg(defaultValue);
    Reg#(ServerIndex) dst_index <- mkReg(0);
    Reg#(Bit#(7)) block_count <- mkReg(0);
    Reg#(Bit#(7)) num_of_blocks_to_transmit <- mkReg(4);
    Reg#(Bit#(1)) transmission_in_progress <- mkReg(0);
    Reg#(Bit#(1)) init_header <- mkReg(0);

    Reg#(Bit#(64)) pkt_count <- mkReg(0);

    rule prepare_pkt_transmission
             (start_flag == 1 && transmission_in_progress == 0);

        count <= count + 1;

        if (count % 3 == 0) /* wait for * cycles between pkt transmissions */
        begin
            pkt_count <= pkt_count + 1;
            transmission_in_progress <= 1;
            init_header <= 1;
            block_count <= 0;

            Bit#(4) r <- rand_dst_index.next();
            if (r == fromInteger(host_index))
            begin
                dst_index <= (r + 1) % fromInteger(valueof(NUM_OF_SERVERS));
                if (verbose)
                    $display("[DMA (%d)] dst index = %d", host_index,
                                  (r + 1) % fromInteger(valueof(NUM_OF_SERVERS)));
            end
            else
            begin
                dst_index <= r;
                if (verbose)
                    $display("[DMA (%d)] dst index = %d", host_index, r);
            end

            num_of_blocks_to_transmit <= 4; /* 64 byte packets */

        end
    endrule

    rule set_up_the_header
            (transmission_in_progress == 1 && init_header == 1);
        init_header <= 0;
        Header h = defaultValue;
        h.src_mac = mac_address(fromInteger(host_index));
        h.src_ip = ip_address(fromInteger(host_index));
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
                    (makeWriteReq(1, 0, header_data[127:0]));
        end
        else if (block_count == 1)
        begin
            scheduler.dma_write_request.put
                    (makeWriteReq(0, 0, header_data[255:128]));
        end
        else if (block_count == 2)
        begin
            scheduler.dma_write_request.put
                    (makeWriteReq(0, 0, header_data[383:256]));
        end
        else if (block_count == num_of_blocks_to_transmit - 1)
        begin
            transmission_in_progress <= 0;
            scheduler.dma_write_request.put
                  (makeWriteReq(0, 1, fromInteger(host_index)));
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

    method Action start();
        if (verbose)
            $display("[DMA (%d)] Starting..........................", host_index);
        rand_dst_index.cntrl.init();
        start_flag <= 1;
    endmethod

    method Action stop();
        if (verbose)
            $display("[DMA (%d)] Stopping..........................", host_index);
        start_flag <= 0;
        $display("[DMA (%d)] Packets transmitted = %d", host_index, pkt_count);
    endmethod
endmodule
