import FIFO::*;
import FIFOF::*;
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
    (* always_ready, always_enabled *)
    method Bit#(72) mac_tx(Integer port_index);
    (* always_ready, always_enabled *)
    method Action mac_rx(Integer port_index, Bit#(72) v);
endinterface

module mkMac#(Integer host_index,
              Scheduler#(SchedReqResType, SchedReqResType,
                         ReadReqType, ReadResType,
                         WriteReqType, WriteResType) scheduler,
              Clock txClock, Reset txReset, Clock rxClock, Reset rxReset) (Mac);

    Clock defaultClock <- exposeCurrentClock();
    Reset defaultReset <- exposeCurrentReset();

    Vector#(NUM_OF_PORTS, EthMacIfc) eth_mac <- replicateM(mkEthMac(defaultClock,
                                                     txClock, rxClock, txReset));

/*------------------------------------------------------------------------------*/

                                /* Tx Path */

/*------------------------------------------------------------------------------*/
    Reg#(Bit#(64)) clk_counter <- mkReg(0);
    rule clk;
        clk_counter <= clk_counter + 1;
    endrule

    Reg#(Bool) tx_verbose <- mkReg(False, clocked_by txClock, reset_by txReset);

    Vector#(NUM_OF_PORTS, Vector#(2, FIFO#(PacketDataT#(64)))) mac_in_buffer
    <- replicateM
               (replicateM(mkSizedFIFO(2, clocked_by txClock, reset_by txReset)));

    Vector#(NUM_OF_PORTS, Reg#(Bit#(2))) turn
                    <- replicateM(mkReg(0, clocked_by txClock, reset_by txReset));

    rule start_polling_tx_buffer_port_1;
        scheduler.mac_read_request_port_1.put(makeReadReq(READ));
    endrule

    rule start_polling_tx_buffer_port_2;
        scheduler.mac_read_request_port_2.put(makeReadReq(READ));
    endrule

    rule start_polling_tx_buffer_port_3;
        scheduler.mac_read_request_port_3.put(makeReadReq(READ));
    endrule

    rule start_polling_tx_buffer_port_4;
        scheduler.mac_read_request_port_4.put(makeReadReq(READ));
    endrule

    rule add_blocks_to_fifo_port_1;
        let d <- scheduler.mac_read_response_port_1.get;

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

        PacketDataT#(64) data1 = PacketDataT {
                                            data : d.data.payload[63:0],
                                            mask : 0,
                                            sop  : start_bit[0],
                                            eop  : end_bit[0]
                                          };
        PacketDataT#(64) data2 = PacketDataT {
                                            data : d.data.payload[127:64],
                                            mask : 0,
                                            sop  : start_bit[1],
                                            eop  : end_bit[1]
                                          };
        (mac_in_buffer[0])[0].enq(data1);
        (mac_in_buffer[0])[1].enq(data2);

    endrule

    rule add_blocks_to_fifo_port_2;
        let d <- scheduler.mac_read_response_port_2.get;

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

        PacketDataT#(64) data1 = PacketDataT {
                                            data : d.data.payload[63:0],
                                            mask : 0,
                                            sop  : start_bit[0],
                                            eop  : end_bit[0]
                                          };
        PacketDataT#(64) data2 = PacketDataT {
                                            data : d.data.payload[127:64],
                                            mask : 0,
                                            sop  : start_bit[1],
                                            eop  : end_bit[1]
                                          };
        (mac_in_buffer[1])[0].enq(data1);
        (mac_in_buffer[1])[1].enq(data2);

    endrule

    rule add_blocks_to_fifo_port_3;
        let d <- scheduler.mac_read_response_port_3.get;

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

        PacketDataT#(64) data1 = PacketDataT {
                                            data : d.data.payload[63:0],
                                            mask : 0,
                                            sop  : start_bit[0],
                                            eop  : end_bit[0]
                                          };
        PacketDataT#(64) data2 = PacketDataT {
                                            data : d.data.payload[127:64],
                                            mask : 0,
                                            sop  : start_bit[1],
                                            eop  : end_bit[1]
                                          };
        (mac_in_buffer[2])[0].enq(data1);
        (mac_in_buffer[2])[1].enq(data2);

    endrule

    rule add_blocks_to_fifo_port_4;
        let d <- scheduler.mac_read_response_port_4.get;

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

        PacketDataT#(64) data1 = PacketDataT {
                                            data : d.data.payload[63:0],
                                            mask : 0,
                                            sop  : start_bit[0],
                                            eop  : end_bit[0]
                                          };
        PacketDataT#(64) data2 = PacketDataT {
                                            data : d.data.payload[127:64],
                                            mask : 0,
                                            sop  : start_bit[1],
                                            eop  : end_bit[1]
                                          };
        (mac_in_buffer[3])[0].enq(data1);
        (mac_in_buffer[3])[1].enq(data2);

    endrule

    for (Integer i = 0; i < fromInteger(valueof(NUM_OF_PORTS)); i = i + 1)
    begin
        for (Integer j = 0; j < 2; j = j + 1)
        begin
            rule send_to_mac (turn[i] == fromInteger(j));
                let d <- toGet((mac_in_buffer[i])[j]).get;

                if (tx_verbose)
                    $display("[MAC (%d)] CLK = %d input to mac %d %d %x i = %d",
                               host_index, clk_counter, d.sop, d.eop, d.data, i);

                eth_mac[i].packet_tx.put(d);

                turn[i] <= (turn[i] + 1) % 2;
            endrule
        end
    end


/*------------------------------------------------------------------------------*/

                                /* Rx Path */

/*------------------------------------------------------------------------------*/

    Reg#(Bool) rx_verbose <- mkReg(False, clocked_by rxClock, reset_by rxReset);

    Vector#(NUM_OF_PORTS, Reg#(PacketDataT#(64))) mac_out_buffer
        <- replicateM(mkReg(defaultValue, clocked_by rxClock, reset_by rxReset));

    Vector#(NUM_OF_PORTS, Reg#(Bit#(2))) b_count
                   <- replicateM(mkReg(0, clocked_by rxClock, reset_by rxReset));

    for (Integer i = 0; i < fromInteger(valueof(NUM_OF_PORTS)); i = i + 1)
    begin
        rule send_blocks_to_dst;
            let d <- eth_mac[i].packet_rx.get;

            if (rx_verbose)
                $display("[MAC (%d)] output from mac layer %d %d %x",
                           host_index, d.sop, d.eop, d.data);

            if (b_count[i] == 0)
            begin
                mac_out_buffer[i] <= d;
                b_count[i] <= (b_count[i] + 1) % 2;
            end

            else if (b_count[i] == 1)
            begin
                b_count[i] <= (b_count[i] + 1) % 2;

                Payload pload = {d.data, mac_out_buffer[i].data};

                Bit#(1) start_bit = 0;
                Bit#(1) end_bit = 0;

                if (mac_out_buffer[i].sop == 1 && mac_out_buffer[i].eop == 0
                    && d.sop == 0 && d.eop == 0)
                begin
                    start_bit = 1;
                    end_bit = 0;
                end
                else if (mac_out_buffer[i].sop == 0 && mac_out_buffer[i].eop == 0
                         && d.sop == 0 && d.eop == 0)
                begin
                    start_bit = 0;
                    end_bit = 0;
                end
                else if (mac_out_buffer[i].sop == 0 && mac_out_buffer[i].eop == 0
                    && d.sop == 0 && d.eop == 1)
                begin
                    start_bit = 0;
                    end_bit = 1;
                end

                case (i)
                    0 : scheduler.mac_write_request_port_1.put
                                      (makeWriteReq(start_bit, end_bit, pload));
                    1 : scheduler.mac_write_request_port_2.put
                                      (makeWriteReq(start_bit, end_bit, pload));
                    2 : scheduler.mac_write_request_port_3.put
                                      (makeWriteReq(start_bit, end_bit, pload));
                    3 : scheduler.mac_write_request_port_4.put
                                      (makeWriteReq(start_bit, end_bit, pload));
                endcase

                if (rx_verbose)
                    $display("[MAC (%d)] data = %d %d %x i = %d",
                        host_index, start_bit, end_bit, pload, i);
            end
        endrule
    end

/*------------------------------------------------------------------------------*/

                                /* Loopback Test */

/*------------------------------------------------------------------------------*/
//
//    SyncFIFOIfc#(Bit#(72)) syncfifo1
//                <- mkSyncFIFO(16, txClock, txReset, rxClock);
//
//    SyncFIFOIfc#(Bit#(72)) syncfifo2
//                <- mkSyncFIFO(16, txClock, txReset, rxClock);
//
//    rule mac_loopback_tx_1;
//        syncfifo1.enq(eth_mac[0].tx);
//    endrule
//
//    rule mac_loopback_rx_1;
//        let v <- toGet(syncfifo1).get;
//        eth_mac[1].rx(v);
//    endrule
//
//    rule mac_loopback_tx_2;
//        syncfifo2.enq(eth_mac[1].tx);
//    endrule
//
//    rule mac_loopback_rx_2;
//        let v <- toGet(syncfifo2).get;
//        eth_mac[0].rx(v);
//    endrule
//
//    Reg#(Bit#(1)) onnce <- mkReg(0);
//    rule test (onnce == 0);
//        $display("[MAC (%d)] CAN REACH HERE", host_index);
//        onnce <= 1;
//    endrule
//
//    Reg#(Bit#(64)) clk <- mkReg(0, clocked_by txClock, reset_by txReset);
//    rule clk_counter;
//        clk <= clk + 1;
//    endrule
//
//    FIFO#(PacketDataT#(64)) pkt_buffer <- mkSizedFIFO(10);
//
//    Reg#(Bit#(4)) count <- mkReg(0, clocked_by txClock, reset_by txReset);
//
//    rule enq_to_pkt_buffer (count < 9 && clk > 1000);
//        count <= count + 1;
//
//        if (count == 1)
//        begin
//            PacketDataT#(64) d = PacketDataT {
//                                        data : 'h28374fabcce53678,
//                                        mask : 0,
//                                        sop  : 1,
//                                        eop  : 0
//                                      };
//            pkt_buffer.enq(d);
//            //eth_mac[0].packet_tx.put(d);
//            $display("[MAC (%d)] ENQ DATA %d %d %x", host_index, d.sop, d.eop, d.data);
//        end
//
//        else if (count >= 2 && count < 8)
//        begin
//            PacketDataT#(64) d = PacketDataT {
//                                        data : 'h1a374fabcce53678,
//                                        mask : 0,
//                                        sop  : 0,
//                                        eop  : 0
//                                      };
//            pkt_buffer.enq(d);
//            //eth_mac[0].packet_tx.put(d);
//            $display("[MAC (%d)] ENQ  DATA %d %d %x", host_index, d.sop, d.eop, d.data);
//        end
//
//        else if (count == 8)
//        begin
//            PacketDataT#(64) d = PacketDataT {
//                                        data : 'hcab47596666bbbab,
//                                        mask : 0,
//                                        sop  : 0,
//                                        eop  : 1
//                                      };
//            pkt_buffer.enq(d);
//            //eth_mac[0].packet_tx.put(d);
//            $display("[MAC (%d)] ENQ DATA %d %d %x", host_index, d.sop, d.eop, d.data);
//        end
//
//    endrule
//
//    rule send_to_tx (clk > 10000);
//        let d <- toGet(pkt_buffer).get;
//        $display("[MAC (%d)] CLK = %d SEND DATA %d %d %x", host_index, clk, d.sop, d.eop, d.data);
//        eth_mac[0].packet_tx.put(d);
//    endrule
//
//    rule get_from_rx;
//        let d <- eth_mac[1].packet_rx.get;
//        $display("[MAC (%d)] DATA = %d %d %x", host_index, d.sop, d.eop, d.data);
//    endrule

/*------------------------------------------------------------------------------*/

                            /* Interface Methods */

/*------------------------------------------------------------------------------*/

    method Bit#(72) mac_tx(Integer port_index);
        let v = eth_mac[port_index].tx;
        return v;
    endmethod

    method Action mac_rx(Integer port_index, Bit#(72) v);
        eth_mac[port_index].rx(v);
    endmethod
endmodule
