import FIFO::*;
import FIFOLevel::*;
import Vector::*;
import GetPut::*;
import Clocks::*;
import DefaultValue::*;

import SchedulerTypes::*;
import Scheduler::*;
import RingBufferTypes::*;

//import AlteraMacWrap::*;
//import EthMac::*;

interface Mac;
    method Action start();
    method Action stop();
endinterface

typedef struct {
    dataT d;  // data (generic)
    Bit#(1) sop; // start-of-packet marker
    Bit#(1) eop; // end-of-packet marker
} PacketDataT#(type dataT) deriving (Bits,Eq);

instance DefaultValue#(PacketDataT#(Bit#(64)));
    defaultValue = PacketDataT {
                                d : 0,
                                sop : 0,
                                eop : 0
                               };
endinstance

module mkMac#(Integer host_index, Vector#(NUM_OF_SERVERS,
    Scheduler#(SchedReqResType, SchedReqResType,
               ReadReqType, ReadResType,
               WriteReqType, WriteResType)) scheduler,
    Clock txClock, Reset txReset,
    Clock rxClock, Reset rxReset) (Mac);

    //Clock defaultClock <- exposeCurrentClock();
    //Reset defaultReset <- exposeCurrentReset();
    //EthMacIfc mac <- mkEthMac(defaultClock, txClock, rxClock, txReset);

/*-------------------------------------------------------------------------------*/

                                /* Tx Path */

/*-------------------------------------------------------------------------------*/
    Reg#(Bool) tx_verbose <- mkReg(False, clocked_by txClock, reset_by txReset);

    Vector#(NUM_OF_PORTS, SyncFIFOLevelIfc#(PacketDataT#(Bit#(64)), 8)) buffer
                        <- replicateM(mkSyncFIFOLevel(txClock, txReset, rxClock));

    Vector#(NUM_OF_PORTS, Vector#(2, FIFO#(PacketDataT#(Bit#(64))))) mac_in_buffer
    <- replicateM(replicateM(mkSizedFIFO(2, clocked_by txClock, reset_by txReset)));

    Vector#(NUM_OF_PORTS, Reg#(Bit#(2))) turn
                      <- replicateM(mkReg(0, clocked_by txClock, reset_by txReset));

    rule start_polling_tx_buffer_port_1;
        scheduler[host_index].mac_read_request_port_1.put(makeReadReq(READ));
    endrule

    rule start_polling_tx_buffer_port_2;
        scheduler[host_index].mac_read_request_port_2.put(makeReadReq(READ));
    endrule

    rule start_polling_tx_buffer_port_3;
        scheduler[host_index].mac_read_request_port_3.put(makeReadReq(READ));
    endrule

    rule start_polling_tx_buffer_port_4;
        scheduler[host_index].mac_read_request_port_4.put(makeReadReq(READ));
    endrule

    rule add_blocks_to_fifo_port_1;
        let d <- scheduler[host_index].mac_read_response_port_1.get;

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
        (mac_in_buffer[0])[0].enq(data1);
        (mac_in_buffer[0])[1].enq(data2);

    endrule

    rule add_blocks_to_fifo_port_2;
        let d <- scheduler[host_index].mac_read_response_port_2.get;

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
        (mac_in_buffer[1])[0].enq(data1);
        (mac_in_buffer[1])[1].enq(data2);

    endrule

    rule add_blocks_to_fifo_port_3;
        let d <- scheduler[host_index].mac_read_response_port_3.get;

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
        (mac_in_buffer[2])[0].enq(data1);
        (mac_in_buffer[2])[1].enq(data2);

    endrule

    rule add_blocks_to_fifo_port_4;
        let d <- scheduler[host_index].mac_read_response_port_4.get;

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
        (mac_in_buffer[3])[0].enq(data1);
        (mac_in_buffer[3])[1].enq(data2);

    endrule

    for (Integer i = 0; i < fromInteger(valueof(NUM_OF_PORTS)); i = i + 1)
    begin
        for (Integer j = 0; j < 2; j = j + 1)
        begin
            rule send_to_mac (turn[i] == fromInteger(j));
                let d <- toGet((mac_in_buffer[i])[j]).get;

                buffer[i].enq(d);
                //mac.packet_tx.put(d);

                if (tx_verbose)
                    $display("[MAC (%d)] input to mac %d %d %x i = %d",
                               host_index, d.sop, d.eop, d.d, i);
                turn[i] <= (turn[i] + 1) % 2;
            endrule
        end
    end


/*-------------------------------------------------------------------------------*/

                                /* Rx Path */

/*-------------------------------------------------------------------------------*/

    Reg#(Bool) rx_verbose <- mkReg(False, clocked_by rxClock, reset_by rxReset);

    Vector#(NUM_OF_PORTS, Reg#(PacketDataT#(Bit#(64)))) mac_out_buffer
        <- replicateM(mkReg(defaultValue, clocked_by rxClock, reset_by rxReset));

    Vector#(NUM_OF_PORTS, Reg#(Bit#(2))) b_count
                   <- replicateM(mkReg(0, clocked_by rxClock, reset_by rxReset));

    for (Integer i = 0; i < fromInteger(valueof(NUM_OF_PORTS)); i = i + 1)
    begin
        rule send_blocks_to_dst;
            let d <- toGet(buffer[i]).get;
            //let d <- mac.packet_rx.get;

            if (rx_verbose)
                $display("[MAC (%d)] output from mac layer %d %d %x",
                           host_index, d.sop, d.eop, d.d);

            if (b_count[i] == 0)
            begin
                mac_out_buffer[i] <= d;
                b_count[i] <= (b_count[i] + 1) % 2;
            end

            else if (b_count[i] == 1)
            begin
                b_count[i] <= (b_count[i] + 1) % 2;

                Payload pload = {d.d, mac_out_buffer[i].d};

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

                if (host_index == 0)
                begin
                    case (i)
                    0 : scheduler[1].mac_write_request_port_1.put
                                      (makeWriteReq(start_bit, end_bit, pload));
                    1 : scheduler[2].mac_write_request_port_1.put
                                      (makeWriteReq(start_bit, end_bit, pload));
                    2 : scheduler[3].mac_write_request_port_1.put
                                      (makeWriteReq(start_bit, end_bit, pload));
                    3 : scheduler[4].mac_write_request_port_1.put
                                      (makeWriteReq(start_bit, end_bit, pload));
                    endcase
                end

                else if (host_index == 1)
                begin
                    case (i)
                    0 : scheduler[0].mac_write_request_port_1.put
                                      (makeWriteReq(start_bit, end_bit, pload));
                    1 : scheduler[2].mac_write_request_port_2.put
                                      (makeWriteReq(start_bit, end_bit, pload));
                    2 : scheduler[3].mac_write_request_port_2.put
                                      (makeWriteReq(start_bit, end_bit, pload));
                    3 : scheduler[4].mac_write_request_port_2.put
                                      (makeWriteReq(start_bit, end_bit, pload));
                    endcase
                end

                else if (host_index == 2)
                begin
                    case (i)
                    0 : scheduler[0].mac_write_request_port_2.put
                                      (makeWriteReq(start_bit, end_bit, pload));
                    1 : scheduler[1].mac_write_request_port_2.put
                                      (makeWriteReq(start_bit, end_bit, pload));
                    2 : scheduler[3].mac_write_request_port_3.put
                                      (makeWriteReq(start_bit, end_bit, pload));
                    3 : scheduler[4].mac_write_request_port_3.put
                                      (makeWriteReq(start_bit, end_bit, pload));
                    endcase
                end

                else if (host_index == 3)
                begin
                    case (i)
                    0 : scheduler[0].mac_write_request_port_3.put
                                      (makeWriteReq(start_bit, end_bit, pload));
                    1 : scheduler[1].mac_write_request_port_3.put
                                      (makeWriteReq(start_bit, end_bit, pload));
                    2 : scheduler[2].mac_write_request_port_3.put
                                      (makeWriteReq(start_bit, end_bit, pload));
                    3 : scheduler[4].mac_write_request_port_4.put
                                      (makeWriteReq(start_bit, end_bit, pload));
                    endcase
                end

                else if (host_index == 4)
                begin
                    case (i)
                    0 : scheduler[0].mac_write_request_port_4.put
                                      (makeWriteReq(start_bit, end_bit, pload));
                    1 : scheduler[1].mac_write_request_port_4.put
                                      (makeWriteReq(start_bit, end_bit, pload));
                    2 : scheduler[2].mac_write_request_port_4.put
                                      (makeWriteReq(start_bit, end_bit, pload));
                    3 : scheduler[3].mac_write_request_port_4.put
                                      (makeWriteReq(start_bit, end_bit, pload));
                    endcase
                end

                if (rx_verbose)
                    $display("[MAC (%d)] data = %d %d %x i = %d",
                        host_index, start_bit, end_bit, pload, i);
            end
        endrule
    end


/*-------------------------------------------------------------------------------*/

                                /* Loopback */

/*-------------------------------------------------------------------------------*/
//
//    SyncFIFOLevelIfc#(Bit#(72), 2) syncfifo
//                <- mkSyncFIFOLevel(txClock, txReset, rxClock);
//
//    rule mac_loopback_tx;
//        syncfifo.enq(mac.tx);
//    endrule
//
//    rule mac_loopback_rx;
//        let v <- toGet(syncfifo).get;
//        mac.rx(v);
//    endrule
//
//    Reg#(Bit#(1)) once <- mkReg(0, clocked_by txClock, reset_by txReset);
//    rule send_to_tx (once == 0);
//        once <= 1;
//
//        $display("[MAC (%d)] SENDING DATA");
//        PacketDataT#(Bit#(64)) data = PacketDataT {
//                                            d : 'h28374fabcce53678,
//                                            sop : 1,
//                                            eop : 0
//                                          };
//        mac.packet_tx.put(data);
//    endrule
//
//    rule get_from_rx;
//        let d <- mac.packet_rx.get;
//        $display("[MAC (%d)] DATA = %d %d %x", host_index, d.sop, d.eop, d.d);
//    endrule
//
//
/*-------------------------------------------------------------------------------*/

                            /* Inteface Methods */

/*-------------------------------------------------------------------------------*/

    method Action start();
        //$display("[MAC (%d)] Starting...............................", host_index);
    endmethod

    method Action stop();
        //$display("[MAC (%d)] Stopping...............................", host_index);
    endmethod
endmodule
