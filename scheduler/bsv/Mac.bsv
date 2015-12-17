import FIFO::*;
import FIFOLevel::*;
import Vector::*;
import GetPut::*;
import Clocks::*;
import DefaultValue::*;

import SchedulerTypes::*;
import Scheduler::*;
import RingBufferTypes::*;

import AlteraMacWrap::*;
import EthMac::*;

interface Mac;
    method Action start();
    method Action stop();
endinterface

module mkMac#(Integer host_index, Vector#(NUM_OF_SERVERS,
    Scheduler#(SchedReqResType, SchedReqResType,
               ReadReqType, ReadResType,
               WriteReqType, WriteResType)) scheduler,
    Clock defaultClock, Reset defaultReset,
    Clock txClock, Reset txReset,
    Clock rxClock, Reset rxReset) (Mac);

    EthMacIfc mac <- mkEthMac(defaultClock, txClock, rxClock, txReset);


/*-------------------------------------------------------------------------------*/

                                /* Tx Path */

/*-------------------------------------------------------------------------------*/

    SyncFIFOLevelIfc#(PacketDataT#(Bit#(64)), 8) buffer
                        <- mkSyncFIFOLevel(txClock, txReset, rxClock);

    Vector#(2, FIFO#(PacketDataT#(Bit#(64)))) mac_in_buffer
                     <- replicateM(mkFIFO(clocked_by txClock, reset_by txReset));

    Reg#(Bit#(1)) waiting_for_transmission
                       <- mkReg(0, clocked_by txClock, reset_by txReset);

    Reg#(Bit#(2)) turn <- mkReg(0, clocked_by txClock, reset_by txReset);

    Reg#(Bit#(1)) dont_fire <- mkReg(1, clocked_by txClock, reset_by txReset);

    rule start_polling_tx_buffer (dont_fire == 1);
        scheduler[host_index].mac_read_request.put(makeReadReq(READ));
    endrule

    rule add_blocks_to_fifo (waiting_for_transmission == 0);

        let d <- scheduler[host_index].mac_read_response.get;

        Vector#(2, Bit#(1)) start_bit = replicate(0);
        Vector#(2, Bit#(1)) end_bit = replicate(0);

        if (d.data.sop == 1 && d.data.eop == 0)
        begin
            start_bit[0] = 1;
            end_bit[0] = 0;
            start_bit[1] = 0;
            end_bit[1] = 0;
        end
        if (d.data.sop == 0 && d.data.eop == 0)
        begin
            start_bit[0] = 0;
            end_bit[0] = 0;
            start_bit[1] = 0;
            end_bit[1] = 0;
        end
        if (d.data.sop == 0 && d.data.eop == 1)
        begin
            start_bit[0] = 0;
            end_bit[0] = 0;
            start_bit[1] = 0;
            end_bit[1] = 1;
        end

        PacketDataT#(Bit#(64)) data1 = PacketDataT {
                                            d : d.data.payload[63:0],
                                            sop : start_bit[0],
                                            eop : end_bit[0]
                                          };
        PacketDataT#(Bit#(64)) data2 = PacketDataT {
                                            d : d.data.payload[127:64],
                                            sop : start_bit[1],
                                            eop : end_bit[1]
                                          };
        mac_in_buffer[0].enq(data1);
        mac_in_buffer[1].enq(data2);

        waiting_for_transmission <= 1;
    endrule

    for (Integer i = 0; i < 2; i = i + 1)
    begin
        rule send_to_mac (turn == fromInteger(i));

            let d <- toGet(mac_in_buffer[turn]).get;

            //mac.packet_tx.put(d);
            buffer.enq(d);

            $display("[MAC (%d)] input to mac layer %d %d %x", host_index,
                                                           d.sop, d.eop, d.d);
            turn <= (turn + 1) % 2;
            if (turn == 1)
                waiting_for_transmission <= 0;
        endrule
    end


/*-------------------------------------------------------------------------------*/

                                /* Rx Path */

/*-------------------------------------------------------------------------------*/

    Vector#(NUM_OF_SERVERS, Reg#(MAC)) mac_addr_list
             <- replicateM(mkReg(0, clocked_by rxClock, reset_by rxReset));

    Reg#(Bit#(1)) done_populating_mac_list
                         <- mkReg(0, clocked_by rxClock, reset_by rxReset);

    rule populate_mac_addr_list (done_populating_mac_list == 0);
        done_populating_mac_list <= 1;
        mac_addr_list[0] <= 'hffab4859fbc4;
        mac_addr_list[1] <= 'hab4673df3647;
        //mac_addr_list[2] <= 'h2947baffe64c;
        //mac_addr_list[3] <= 'h5bdc664dffee;
        //mac_addr_list[4] <= 'h85774bbcfeaa;
        //mac_addr_list[5] <= 'h95babbdfe857;
        //mac_addr_list[6] <= 'h7584bcaafe65;
        //mac_addr_list[7] <= 'h1baeef3647af;
        //mac_addr_list[8] <= 'hbcaffe43562b;
        //mac_addr_list[9] <= 'hc64bafe66381;
        //mac_addr_list[10] <= 'hd6b4392ba774;
        //mac_addr_list[11] <= 'hefa553617bbc;
    endrule

    function AddrIndex macToIndex(MAC mac_addr);
        AddrIndex res = 0;
        for (Integer i = 0; i < fromInteger(valueof(NUM_OF_SERVERS)); i = i + 1)
        begin
            if (mac_addr_list[i] == mac_addr)
                res = fromInteger(i);
        end
        return res;
    endfunction


    Reg#(AddrIndex) curr_dst_index <- mkReg(0, clocked_by rxClock, reset_by rxReset);

    Reg#(PacketDataT#(Bit#(64))) mac_out_buffer
                     <- mkReg(defaultValue, clocked_by rxClock, reset_by rxReset);

    Reg#(Bit#(2)) b_count <- mkReg(0, clocked_by rxClock, reset_by rxReset);

    Reg#(Bit#(1)) never_fire <- mkReg(1, clocked_by rxClock, reset_by rxReset);

    rule send_blocks_to_dst (never_fire == 1);

        let d <- toGet(buffer).get;
        //let d <- mac.packet_rx.get;

        $display("[MAC (%d)] output from mac layer %d %d %x", host_index,
                                                           d.sop, d.eop, d.d);
        if (b_count == 0)
        begin
            mac_out_buffer <= d;
            b_count <= (b_count + 1) % 2;
        end

        else if (b_count == 1)
        begin
            b_count <= (b_count + 1) % 2;

            Payload pload = {d.d, mac_out_buffer.d};

            Bit#(1) start_bit = 0;
            Bit#(1) end_bit = 0;

            if (mac_out_buffer.sop == 1 && mac_out_buffer.eop == 0
                && d.sop == 0 && d.eop == 0)
            begin
                start_bit = 1;
                end_bit = 0;
            end
            else if (mac_out_buffer.sop == 0 && mac_out_buffer.eop == 0
                     && d.sop == 0 && d.eop == 0)
            begin
                start_bit = 0;
                end_bit = 0;
            end
            else if (mac_out_buffer.sop == 0 && mac_out_buffer.eop == 0
                && d.sop == 0 && d.eop == 1)
            begin
                start_bit = 0;
                end_bit = 1;
            end

            if (start_bit == 1 && end_bit == 0)
            begin
                AddrIndex dst_index = macToIndex(pload[47:0]);
                scheduler[dst_index].mac_write_request.put(makeWriteReq(start_bit,
                                                                        end_bit,
                                                                        pload));
                curr_dst_index <= dst_index;
                $display("[MAC (%d)] data = %d %d %x, Sending to dst = %d",
                              host_index, start_bit, end_bit, pload, dst_index);
            end

            else
            begin
                scheduler[curr_dst_index].mac_write_request.put
                                      (makeWriteReq(start_bit, end_bit, pload));
                $display("[MAC (%d)] data = %d %d %x, Sending to dst = %d",
                              host_index, start_bit, end_bit, pload, curr_dst_index);
            end
        end
    endrule


/*-------------------------------------------------------------------------------*/

                                /* Loopback */

/*-------------------------------------------------------------------------------*/

    SyncFIFOLevelIfc#(Bit#(72), 2) syncfifo
                <- mkSyncFIFOLevel(txClock, txReset, rxClock);

    rule mac_loopback_tx;
        syncfifo.enq(mac.tx);
    endrule

    rule mac_loopback_rx;
        let v <- toGet(syncfifo).get;
        mac.rx(v);
    endrule

    Reg#(Bit#(1)) once <- mkReg(0, clocked_by txClock, reset_by txReset);
    rule send_to_tx (once == 0);
        once <= 1;

        $display("[MAC (%d)] SENDING DATA");
        PacketDataT#(Bit#(64)) data = PacketDataT {
                                            d : 'h28374fabcce53678,
                                            sop : 1,
                                            eop : 0
                                          };
        mac.packet_tx.put(data);
    endrule

    rule get_from_rx;
        let d <- mac.packet_rx.get;
        $display("[MAC (%d)] DATA = %d %d %x", host_index, d.sop, d.eop, d.d);
    endrule


/*-------------------------------------------------------------------------------*/

                            /* Inteface Methods */

/*-------------------------------------------------------------------------------*/

    method Action start();
        $display("[MAC (%d)] Starting...............................", host_index);
    endmethod

    method Action stop();
        $display("[MAC (%d)] Stopping...............................", host_index);
    endmethod
endmodule
