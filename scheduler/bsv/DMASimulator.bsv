import Vector::*;
import DefaultValue::*;
import Randomizable::* ;
import GetPut::*;

import Scheduler::*;
import SchedulerTypes::*;
import RingBufferTypes::*;

typedef struct {
    Bit#(112) payload;
    Bit#(32) dst_ip;
    Bit#(32) src_ip;
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
    Bit#(48) src_mac;
    Bit#(48) dst_mac;
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
    Bit#(32) ip_addr;
    Bit#(48) mac_addr;
} Addresses deriving(Bits, Eq);

instance DefaultValue#(Addresses);
    defaultValue = Addresses {
                              ip_addr  : 0,
                              mac_addr : 0
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


    Vector#(NUM_OF_SERVERS, Reg#(Addresses)) address
                           <- replicateM(mkReg(defaultValue));

    Reg#(Bit#(1)) loaded_ip <- mkReg(0);
    Reg#(Bit#(1)) loaded_mac <- mkReg(0);

    rule load_ip_addresses_into_register (start_flag == 1 && loaded_ip == 0);
        loaded_ip <= 1;
        address[0].ip_addr <= 'hc0a80001;
        address[1].ip_addr <= 'hc0a80002;
        address[2].ip_addr <= 'hc0a80003;
        address[3].ip_addr <= 'hc0a80004;
        address[4].ip_addr <= 'hc0a80005;
        //address[5].ip_addr <= 'hc0a80006;
        //address[6].ip_addr <= 'hc0a80007;
        //address[7].ip_addr <= 'hc0a80008;
        //address[8].ip_addr <= 'hc0a80009;
        //address[9].ip_addr <= 'hc0a8000a;
    endrule

    rule load_mac_addresses_into_register (start_flag == 1
                                           && loaded_ip == 1 && loaded_mac == 0);
        loaded_mac <= 1;
        address[0].mac_addr <= 'hffab4859fbc4;
        address[1].mac_addr <= 'hab4673df3647;
        address[2].mac_addr <= 'h2947baffe64c;
        address[3].mac_addr <= 'h5bdc664dffee;
        address[4].mac_addr <= 'h85774bbcfeaa;
        //address[5].mac_addr <= 'h95babbdfe857;
        //address[6].mac_addr <= 'h7584bcaafe65;
        //address[7].mac_addr <= 'h1baeef3647af;
        //address[8].mac_addr <= 'hbcaffe43562b;
        //address[9].mac_addr <= 'hc64bafe66381;
    endrule

    Reg#(Header) header <- mkReg(defaultValue);
    Reg#(AddrIndex) dst_index <- mkReg(0);
    Reg#(Bit#(7)) block_count <- mkReg(0);
    Reg#(Bit#(7)) num_of_blocks_to_transmit <- mkReg(4);
    Reg#(Bit#(1)) transmission_in_progress <- mkReg(0);
    Reg#(Bit#(1)) init_header <- mkReg(0);

    Reg#(Bit#(64)) pkt_count <- mkReg(0);

    rule prepare_pkt_transmission
             (start_flag == 1 && transmission_in_progress == 0 && loaded_ip == 1
             && loaded_mac == 1);

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
        h.src_mac = address[host_index].mac_addr;
        h.src_ip = address[host_index].ip_addr;
        h.dst_mac = address[dst_index].mac_addr;
        h.dst_ip = address[dst_index].ip_addr;
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
