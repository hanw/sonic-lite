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
    interface Get#(Bit#(64)) sop_count_port_0;
    interface Get#(Bit#(64)) eop_count_port_0;

    (* always_ready, always_enabled *)
    method Bit#(72) tx(Integer port_index);
    (* always_ready, always_enabled *)
    method Action rx(Integer port_index, Bit#(72) v);

    method Action getSOPCountForPort0();
    method Action getEOPCountForPort0();
endinterface

module mkMac#(Scheduler#(ReadReqType, ReadResType,
                         WriteReqType, WriteResType) scheduler,
              Clock txClock, Reset txReset,
			  Vector#(NUM_OF_PORTS, Clock) rxClock,
		      Vector#(NUM_OF_PORTS, Reset) rxReset) (Mac);

    Clock defaultClock <- exposeCurrentClock();
    Reset defaultReset <- exposeCurrentReset();

    Vector#(NUM_OF_PORTS, EthMacIfc) eth_mac;

	for (Integer i = 0; i < valueof(NUM_OF_PORTS); i = i + 1)
	begin
		eth_mac[i] <- mkEthMac(defaultClock, txClock, rxClock[i], txReset);
	end

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

    for (Integer i = 0; i < fromInteger(valueof(NUM_OF_PORTS)); i = i + 1)
    begin
		rule start_polling_tx_buffer;
			scheduler.mac_read_request_port[i].put(makeReadReq(READ));
		endrule

		rule add_blocks_to_fifo;
			let d <- scheduler.mac_read_response_port[i].get;

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
			(mac_in_buffer[i])[0].enq(data1);
			(mac_in_buffer[i])[1].enq(data2);

		endrule

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

    Vector#(NUM_OF_PORTS, Reg#(PacketDataT#(64))) mac_out_buffer;
    Vector#(NUM_OF_PORTS, Reg#(Bit#(2))) b_count;

//	SyncFIFOIfc#(PacketDataT#(64)) debug_received_from_phy_fifo
//	               <- mkSyncFIFO(16, rxClock, rxReset, defaultClock);

	for (Integer i = 0; i < valueof(NUM_OF_PORTS); i = i + 1)
	begin
		mac_out_buffer[i] <- mkReg(defaultValue,
	                             clocked_by rxClock[i], reset_by rxReset[i]);
		b_count[i] <- mkReg(0, clocked_by rxClock[i], reset_by rxReset[i]);
	end

/*------------------------------------------------------------------------------*/
	SyncFIFOIfc#(Bit#(64)) sop_count_fifo_port_0
	               <- mkSyncFIFO(1, rxClock[0], rxReset[0], defaultClock);

	SyncFIFOIfc#(Bit#(64)) eop_count_fifo_port_0
	               <- mkSyncFIFO(1, rxClock[0], rxReset[0], defaultClock);

    Vector#(NUM_OF_PORTS, Reg#(Bit#(64))) sop_count_reg;
    Vector#(NUM_OF_PORTS, Reg#(Bit#(64))) eop_count_reg;

	for (Integer i = 0; i < valueof(NUM_OF_PORTS); i = i + 1)
	begin
		sop_count_reg[i] <- mkReg(0, clocked_by rxClock[i], reset_by rxReset[i]);
		eop_count_reg[i] <- mkReg(0, clocked_by rxClock[i], reset_by rxReset[i]);
	end
/*------------------------------------------------------------------------------*/

    for (Integer i = 0; i < valueof(NUM_OF_PORTS); i = i + 1)
    begin
        rule send_blocks_to_dst;
            let d <- eth_mac[i].packet_rx.get;

            Bool write_flag = False;

			//debug_received_from_phy_fifo.enq(d);

            if (d.sop == 1 && d.eop == 0)
                sop_count_reg[i] <= sop_count_reg[i] + 1;

            if (d.sop == 0 && d.eop == 1)
                eop_count_reg[i] <= eop_count_reg[i] + 1;

            Bit#(1) start_bit = 0;
            Bit#(1) end_bit = 0;
            Payload pload = 0;

            if (b_count[i] == 0)
            begin
                if (d.sop == 0 && d.eop == 1)
                begin
                    start_bit = 0;
                    end_bit = 1;
                    pload = {d.data, '0};
                    write_flag = True;
                end

                else
                begin
                    mac_out_buffer[i] <= d;
                    b_count[i] <= (b_count[i] + 1) & 1; //same as mod 2
                end
            end

            else if (b_count[i] == 1)
            begin
                if (d.sop == 1 && d.eop == 0)
                begin
                    mac_out_buffer[i] <= d;
                end

                else
                begin
                    b_count[i] <= (b_count[i] + 1) & 1; //same as mod 2

                    pload = {mac_out_buffer[i].data, d.data};

                    if (mac_out_buffer[i].sop == 1
                        && mac_out_buffer[i].eop == 0
                        && d.sop == 0 && d.eop == 0)
                    begin
                        start_bit = 1;
                        end_bit = 0;
                    end
                    else if (mac_out_buffer[i].sop == 0
                             && mac_out_buffer[i].eop == 0
                             && d.sop == 0 && d.eop == 0)
                    begin
                        start_bit = 0;
                        end_bit = 0;
                    end
                    else if (mac_out_buffer[i].sop == 0
                             && mac_out_buffer[i].eop == 0
                             && d.sop == 0 && d.eop == 1)
                    begin
                        start_bit = 0;
                        end_bit = 1;
                    end

                    write_flag = True;
                end
            end

			if (write_flag == True)
				scheduler.mac_write_request_port[i].put
			                         (makeWriteReq(start_bit, end_bit, pload));
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

    method Action getSOPCountForPort0();
        sop_count_fifo_port_0.enq(sop_count_reg[0]);
    endmethod

    method Action getEOPCountForPort0();
        eop_count_fifo_port_0.enq(eop_count_reg[0]);
    endmethod

//	interface Get debug_sending_to_phy = toGet(debug_sending_to_phy_fifo);
//	interface Get debug_received_from_phy = toGet(debug_received_from_phy_fifo);
    interface Get sop_count_port_0 = toGet(sop_count_fifo_port_0);
    interface Get eop_count_port_0 = toGet(eop_count_fifo_port_0);
endmodule
