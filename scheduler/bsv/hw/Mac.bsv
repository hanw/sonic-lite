import FIFO::*;
import FIFOF::*;
import Vector::*;
import GetPut::*;
import Clocks::*;
import DefaultValue::*;

import SchedulerTypes::*;
import Scheduler::*;
import RingBufferTypes::*;
import Addresses::*;

import AlteraMacWrap::*;
import EthMac::*;

interface Mac;
//	interface Get#(PacketDataT#(64)) debug_sending_to_phy;
//	interface Get#(PacketDataT#(64)) debug_received_from_phy;
    (* always_ready, always_enabled *)
    method Bit#(72) tx(Integer port_index);
    (* always_ready, always_enabled *)
    method Action rx(Integer port_index, Bit#(72) v);
	method Action start_mac_rx(ServerIndex host_index);
endinterface

module mkMac#(Scheduler#(ReadReqType, ReadResType,
                         WriteReqType, WriteResType) scheduler,
              Clock txClock, Reset txReset, Clock rxClock, Reset rxReset) (Mac);

    Clock defaultClock <- exposeCurrentClock();
    Reset defaultReset <- exposeCurrentReset();

    Vector#(NUM_OF_PORTS, EthMacIfc) eth_mac <- replicateM(mkEthMac(defaultClock,
                                                     txClock, rxClock, txReset));

/*------------------------------------------------------------------------------*/

                                /* Tx Path */

/*------------------------------------------------------------------------------*/
    Reg#(Bool) tx_verbose <- mkReg(False, clocked_by txClock, reset_by txReset);

    Vector#(NUM_OF_PORTS, Vector#(2, FIFO#(PacketDataT#(64)))) mac_in_buffer
       <- replicateM(replicateM(mkSizedFIFO(fromInteger(valueof(DEFAULT_FIFO_LEN)),
		              clocked_by txClock, reset_by txReset)));

    Vector#(NUM_OF_PORTS, Reg#(Bit#(2))) turn
                    <- replicateM(mkReg(0, clocked_by txClock, reset_by txReset));

//	SyncFIFOIfc#(PacketDataT#(64)) debug_sending_to_phy_fifo
//	               <- mkSyncFIFO(16, txClock, txReset, defaultClock);

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
                                            data : d.data.payload[127:64],
                                            mask : 0,
                                            sop  : start_bit[0],
                                            eop  : end_bit[0]
                                          };
        PacketDataT#(64) data2 = PacketDataT {
                                            data : d.data.payload[63:0],
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
                                            data : d.data.payload[127:64],
                                            mask : 0,
                                            sop  : start_bit[0],
                                            eop  : end_bit[0]
                                          };
        PacketDataT#(64) data2 = PacketDataT {
                                            data : d.data.payload[63:0],
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
                                            data : d.data.payload[127:64],
                                            mask : 0,
                                            sop  : start_bit[0],
                                            eop  : end_bit[0]
                                          };
        PacketDataT#(64) data2 = PacketDataT {
                                            data : d.data.payload[63:0],
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
                                            data : d.data.payload[127:64],
                                            mask : 0,
                                            sop  : start_bit[0],
                                            eop  : end_bit[0]
                                          };
        PacketDataT#(64) data2 = PacketDataT {
                                            data : d.data.payload[63:0],
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

				//debug_sending_to_phy_fifo.enq(d);

                if (tx_verbose)
                    $display("[MAC] input to mac %d %d %x i = %d",
                                d.sop, d.eop, d.data, i);

                eth_mac[i].packet_tx.put(d);

                turn[i] <= (turn[i] + 1) & 1; //same as mod 2
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

	Vector#(NUM_OF_PORTS, Reg#(Bit#(1))) drop_pkt
                   <- replicateM(mkReg(0, clocked_by rxClock, reset_by rxReset));

	Reg#(ServerIndex) host_index <- mkReg(0, clocked_by rxClock, reset_by rxReset);

	Reg#(Bit#(1)) start_rx <- mkReg(0, clocked_by rxClock, reset_by rxReset);

//	SyncFIFOIfc#(PacketDataT#(64)) debug_received_from_phy_fifo
//	               <- mkSyncFIFO(16, rxClock, rxReset, defaultClock);

    for (Integer i = 0; i < fromInteger(valueof(NUM_OF_PORTS)); i = i + 1)
    begin
        rule send_blocks_to_dst (start_rx == 1);
            let d <- eth_mac[i].packet_rx.get;

			Bit#(1) drop = drop_pkt[i];
			//debug_received_from_phy_fifo.enq(d);

            if (rx_verbose)
                $display("[MAC] output from mac layer %d %d %x",
                           d.sop, d.eop, d.data);

			if (d.sop == 1 && d.eop == 0)
			begin
				MAC dst_mac_addr = d.data[63:16];
				if (dst_mac_addr != mac_address(host_index))
				begin
					drop_pkt[i] <= 1;
					drop = 1;
				end
			end

			else if (d.sop == 0 && d.eop == 1)
				drop_pkt[i] <= 0;

            if (b_count[i] == 0)
            begin
                mac_out_buffer[i] <= d;
                b_count[i] <= (b_count[i] + 1) & 1; //same as mod 2
            end

            else if (b_count[i] == 1)
            begin
                b_count[i] <= (b_count[i] + 1) & 1; //same as mod 2

                Payload pload = {mac_out_buffer[i].data, d.data};

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

				if (drop == 0)
				begin
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
				end

                if (rx_verbose)
                    $display("[MAC] data = %d %d %x i = %d",
                              start_bit, end_bit, pload, i);
            end
        endrule
    end

/*------------------------------------------------------------------------------*/

                            /* Interface Methods */

/*------------------------------------------------------------------------------*/

    method Bit#(72) tx(Integer port_index);
        let v = eth_mac[port_index].tx;
        return v;
    endmethod

    method Action rx(Integer port_index, Bit#(72) v);
        eth_mac[port_index].rx(v);
    endmethod

	method Action start_mac_rx(ServerIndex index);
		host_index <= index;
		start_rx <= 1;
	endmethod

//	interface Get debug_sending_to_phy = toGet(debug_sending_to_phy_fifo);
//	interface Get debug_received_from_phy = toGet(debug_received_from_phy_fifo);
endmodule
