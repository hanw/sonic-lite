import Vector::*;
import FIFOLevel::*;
import FIFOF::*;
import SpecialFIFOs::*;
import BRAM::*;
import GetPut::*;
import DefaultValue::*;

import SchedulerTypes::*;
import ScheduleTable::*;
import RingBufferTypes::*;
import RingBuffer::*;

interface Scheduler#(type reqType, type resType,
                     type readReqType, type readResType,
                     type writeReqType, type writeResType);
    /* Controller interface */
    interface Put#(reqType) request;
    interface Get#(resType) settime_response;
    interface Get#(resType) gettime_response;
    interface Get#(resType) setinterval_response;
    interface Get#(resType) getinterval_response;
    interface Get#(resType) insert_response;
    interface Get#(resType) delete_response;
    interface Get#(resType) display_response;

    /* MAC interface */
    interface Put#(readReqType) mac_read_request;
    interface Put#(writeReqType) mac_write_request;
    interface Get#(readResType) mac_read_response;
    interface Get#(writeResType) mac_write_response;

    /* DMA simulator interface */
    interface Put#(readReqType) dma_read_request;
    interface Put#(writeReqType) dma_write_request;
    interface Get#(readResType) dma_read_response;
    interface Get#(writeResType) dma_write_response;
endinterface

module mkScheduler#(Integer host_index,
                    Clock defaultClock, Reset defaultReset,
                    Clock txClock, Reset txReset,
                    Clock rxClock, Reset rxReset) (Scheduler#(SchedReqResType,
                                                    SchedReqResType,
                                                    ReadReqType, ReadResType,
                                                    WriteReqType, WriteResType));

    FIFOF#(SchedReqResType) request_fifo <- mkSizedFIFOF(10);
    FIFOF#(SchedReqResType) settime_response_fifo <- mkFIFOF;
    FIFOF#(SchedReqResType) gettime_response_fifo <- mkFIFOF;
    FIFOF#(SchedReqResType) setinterval_response_fifo <- mkFIFOF;
    FIFOF#(SchedReqResType) getinterval_response_fifo <- mkFIFOF;
    FIFOF#(SchedReqResType) insert_response_fifo <- mkFIFOF;
    FIFOF#(SchedReqResType) delete_response_fifo <- mkFIFOF;
    FIFOF#(SchedReqResType) display_response_fifo <- mkFIFOF;

    SyncFIFOLevelIfc#(ReadReqType, 2) mac_read_request_fifo
                    <- mkSyncFIFOLevel(txClock, txReset, defaultClock);
    SyncFIFOLevelIfc#(ReadResType, 4) mac_read_response_fifo
                    <- mkSyncFIFOLevel(defaultClock, defaultReset, txClock);
    SyncFIFOLevelIfc#(WriteReqType, 2) mac_write_request_fifo
                    <- mkSyncFIFOLevel(rxClock, rxReset, defaultClock);
    SyncFIFOLevelIfc#(WriteResType, 2) mac_write_response_fifo
                    <- mkSyncFIFOLevel(defaultClock, defaultReset, rxClock);

    FIFOF#(ReadReqType) dma_read_request_fifo <- mkFIFOF;
    FIFOF#(ReadResType) dma_read_response_fifo <- mkFIFOF;
    FIFOF#(WriteReqType) dma_write_request_fifo <- mkPipelineFIFOF;
    FIFOF#(WriteResType) dma_write_response_fifo <- mkFIFOF;

    Reg#(Bit#(64)) clk <- mkReg(0);
    Reg#(Bit#(64)) start_time <- mkReg(0);
    Reg#(Bit#(64)) interval <- mkReg(0);

    Server#(TableReqResType, TableReqResType) sched_table <- mksched_table;

    Reg#(SchedulerOp) curr_op <- mkReg(NONE);
    Reg#(State) curr_state <- mkReg(CONFIG);

    Reg#(Bit#(1)) table_op_in_progress <- mkReg(0);

    FIFOF#(SchedReqResType) sched_req_fifo <- mkFIFOF;

/*-------------------------------------------------------------------------------*/
    rule set_time (curr_op == SETTIME);
        let req <- toGet(sched_req_fifo).get;
        if (curr_state == CONFIG)
        begin
            start_time <= req.start_time;
            settime_response_fifo.enq
                        (makeSchedReqRes(0, 0, 0, 0, 0, SETTIME, SUCCESS));
        end
        else
            settime_response_fifo.enq
                        (makeSchedReqRes(0, 0, 0, 0, 0, SETTIME, FAILURE));
    endrule

    rule get_time (curr_op == GETTIME);
        let req <- toGet(sched_req_fifo).get;
        gettime_response_fifo.enq
                (makeSchedReqRes(0, 0, start_time, 0, 0, GETTIME, SUCCESS));
    endrule

/*-------------------------------------------------------------------------------*/
    rule set_interval (curr_op == SETINTERVAL);
        let req <- toGet(sched_req_fifo).get;
        if (curr_state == CONFIG)
        begin
            interval <= req.interval;
            setinterval_response_fifo.enq
                   (makeSchedReqRes(0, 0, 0, 0, 0, SETINTERVAL, SUCCESS));
        end
        else
            setinterval_response_fifo.enq
                 (makeSchedReqRes(0, 0, 0, 0, 0, SETINTERVAL, FAILURE));
    endrule

    rule get_interval (curr_op == GETINTERVAL);
        let req <- toGet(sched_req_fifo).get;
        getinterval_response_fifo.enq(makeSchedReqRes(0, 0, 0, interval,
                                               0, GETINTERVAL,SUCCESS));
    endrule

/*-------------------------------------------------------------------------------*/
    rule insert_req (curr_op == INSERT);
        let req <- toGet(sched_req_fifo).get;
        if (curr_state == CONFIG)
            sched_table.request.put(makeTableReqRes(req.server_ip, req.server_mac,
                                    0, PUT, SUCCESS));
        else
        begin
            table_op_in_progress <= 0;
            insert_response_fifo.enq
                           (makeSchedReqRes(0, 0, 0, 0, 0, INSERT, FAILURE));
        end
    endrule

    rule insert_res (curr_op == INSERT);
        let res <- sched_table.response.get;
        if (res.op_outcome == SUCCESS)
            insert_response_fifo.enq
                            (makeSchedReqRes(0, 0, 0, 0, 0, INSERT, SUCCESS));
        else
            insert_response_fifo.enq
                            (makeSchedReqRes(0 ,0, 0, 0, 0, INSERT, FAILURE));

        table_op_in_progress <= 0;
    endrule

/*-------------------------------------------------------------------------------*/
    rule delete_req (curr_op == DELETE);
        let req <- toGet(sched_req_fifo).get;
        if (curr_state == CONFIG)
            sched_table.request.put(makeTableReqRes(req.server_ip, req.server_mac,
                                    0, REMOVE, SUCCESS));
        else
        begin
            table_op_in_progress <= 0;
            delete_response_fifo.enq
                          (makeSchedReqRes(0, 0, 0, 0, 0, DELETE, FAILURE));
        end
    endrule

    rule delete_res (curr_op == DELETE);
        let res <- sched_table.response.get;
        if (res.op_outcome == SUCCESS)
            delete_response_fifo.enq
                          (makeSchedReqRes(0, 0, 0, 0, 0, DELETE, SUCCESS));
        else
            delete_response_fifo.enq
                          (makeSchedReqRes(0 ,0, 0, 0, 0, DELETE, FAILURE));

        table_op_in_progress <= 0;
    endrule

/*-------------------------------------------------------------------------------*/
    rule display_req (curr_op == DISPLAY);
        let req <- toGet(sched_req_fifo).get;
        sched_table.request.put(makeTableReqRes(0, 0, req.addrIdx, GET, SUCCESS));
    endrule

    rule display_res (curr_op == DISPLAY);
        let res <- sched_table.response.get;
        if (res.op_outcome == SUCCESS)
            display_response_fifo.enq
                           (makeSchedReqRes(res.server_ip, res.server_mac, 0, 0,
                                                            0, DISPLAY, SUCCESS));
        else
            display_response_fifo.enq
                      (makeSchedReqRes(0 ,0, 0, 0, 0, DISPLAY, FAILURE));

        table_op_in_progress <= 0;
    endrule

/*------------------------------------------------------------------------------*/
    RingBuffer#(ReadReqType, ReadResType, WriteReqType, WriteResType)
            rx_ring_buffer <- mkRingBuffer(fromInteger(valueof(RING_BUFFER_SIZE)));

    RingBuffer#(ReadReqType, ReadResType, WriteReqType, WriteResType)
            tx_ring_buffer <- mkRingBuffer(fromInteger(valueof(RING_BUFFER_SIZE)));

    Vector#(NUM_OF_SERVERS,
            RingBuffer#(ReadReqType, ReadResType, WriteReqType, WriteResType))
    ring_buffer <- replicateM(mkRingBuffer(fromInteger(valueof(RING_BUFFER_SIZE))));

    RingBuffer#(ReadReqType, ReadResType, WriteReqType, WriteResType)
        src_rx_ring_buffer <- mkRingBuffer(fromInteger(valueof(RING_BUFFER_SIZE)));

    Vector#(NUM_OF_SERVERS, Reg#(AddrIndex)) schedule_list <- replicateM(mkReg(0));
    Reg#(MAC) host_mac_addr <- mkReg(0);
    Reg#(IP) host_ip_addr <- mkReg(0);

    /* Flags */
    Reg#(Bit#(1)) configure <- mkReg(0);
    Reg#(Bit#(1)) get_host_mac <- mkReg(0);
    Reg#(Bit#(1)) wait_for_host_mac <- mkReg(0);
    Reg#(Bit#(1)) start_polling_rx_buffer <- mkReg(0);

    /*
    * Here the assumption is that since it is our own
    * network, so we assign the IP addresses to the
    * machines in such a way that the mapping IP -> index
    * is trivial. For eg. currently I am assuming that the
    * IP addresses have been assigned such as the mapping
    * is index = least significant byte of IP address - 1.
    * So the IP addrs may be like 192.168.0.1, 192.168.0.2,
    * 192.168.0.3 etc. Note that this is just to make processing
    * faster and saving memory resources. If this approach is not
    * viable in a particular setting, then we can rely back on
    * storing the mapping in a table in BRAM memory, and traversing
    * the table every time we need to know the index of a ring
    * buffer.
    */
    function AddrIndex ipToIndexMapping (IP ip_addr);
        AddrIndex index = truncate(ip_addr[7:0]) - 1;
        if (index < truncate(host_ip_addr[7:0]))
            index = index + 1;
        return index;
    endfunction

    rule start_scheduler (curr_state == RUN);
        let req <- toGet(sched_req_fifo).get;
        $display("[SCHED (%d)] Scheduler started..", host_index);
    endrule

    /*
    * 0th entry in the schedule table will always contain the info of the
    * host server. Entries 1 to NUM_OF_SERVERS-1 will contain info of the
    * remaining servers. As there will be a total of NUM_OF_SERVERS-1 time
    * slots, so the size of schedule_list is NUM_OF_SERVERS-1.
    *
    * schedule_list[i] = j means in time slot i, send pkt to server at index
    * j in the schedule table.
    */
    rule configure_scheduling (curr_state == RUN && configure == 1);
        configure <= 0;
        for (Integer i = 0; i < fromInteger(valueof(NUM_OF_SERVERS)) - 1; i = i + 1)
        begin
            schedule_list[i] <= fromInteger(i) + 1;
            $display("[SCHED (%d)] schedule_list[%d] = %d", host_index, i, i+1);
        end
    endrule

    rule get_host_mac_addr (curr_state == RUN && get_host_mac == 1);
        sched_table.request.put(makeTableReqRes(0, 0, 0, GET, SUCCESS));
        get_host_mac <= 0;
        wait_for_host_mac <= 1;
    endrule

    rule set_host_mac_addr (curr_state == RUN && wait_for_host_mac == 1);
        let d <- sched_table.response.get;
        wait_for_host_mac <= 0;
        host_mac_addr <= d.server_mac;
        host_ip_addr <= d.server_ip;
        start_polling_rx_buffer <= 1;
    endrule

    rule start_polling_rx (curr_state == RUN && start_polling_rx_buffer == 1);
        rx_ring_buffer.read_request.put(makeReadReq(READ));
    endrule

/*------------------------------------------------------------------------------*/
    FIFOF#(RingBufferDataT) buffer_fifo <- mkSizedFIFOF(10);
    FIFOF#(AddrIndex) ring_buffer_index_fifo <- mkSizedFIFOF(10);
    Reg#(AddrIndex) curr_ring_buffer_index <- mkReg(0);
    Reg#(Bit#(1)) ready_to_deq_from_index_buffer <- mkReg(1);
    Reg#(Bit#(1)) ready_to_deq_from_ring_buffer <- mkReg(0);

    /* Stores the number of data blocks to buffer */
    Reg#(Bit#(10)) buffer_depth <- mkReg(0);

    /* Have to buffer first 3 data blocks to get to dst IP addr
    *
    * Assumption here is that the MAC Frame structure is as shown
    *  ------------------------------------------------------
    * | dst MAC | src MAC | ether type | IP header | Payload |
    *  ------------------------------------------------------
    * So, no VLAN tags etc.
    */
    Reg#(Bit#(384)) buffered_data <- mkReg(0); // 3 * 128

    rule buffer_and_parse_incoming_data (curr_state == RUN);
        let d <- rx_ring_buffer.read_response.get;

        if (d.data.sop == 1 && d.data.eop == 0)
        begin
            Bit#(384) pload = zeroExtend(d.data.payload);
            buffered_data <= buffered_data | pload;
            buffer_depth <= buffer_depth + 1;
            buffer_fifo.enq(d.data);
        end

        else if (d.data.sop == 0 && d.data.eop == 1)
        begin
            /* reset state */
            buffer_depth <= 0;
            buffered_data <= 0;
            buffer_fifo.enq(d.data);
        end

        else
        begin
            if (buffer_depth < 3)
            begin
                buffer_depth <= buffer_depth + 1;
                Bit#(384) pload = zeroExtend(d.data.payload);
                buffered_data <= buffered_data
                | (pload << (fromInteger(valueof(BUS_WIDTH)) * buffer_depth));
            end
            else if (buffer_depth == 3) /* 6th data block in series */
            begin
                if (d.data.sop == 0 && d.data.eop == 1)
                begin
                    /* reset state */
                    buffer_depth <= 0;
                    buffered_data <= 0;
                end
                else
                    buffer_depth <= buffer_depth + 1;

                /* Find the index of the ring buffer to insert to. */
                Bit#(32) dst_ip = buffered_data[271:240]; /* dst IP */
                //$display("[SCHED (%d)] data = %x", host_index, buffered_data);
                //$display("[SCHED (%d)] dst_ip = %x", host_index, dst_ip);
                if (dst_ip == host_ip_addr)
                    ring_buffer_index_fifo.enq(0);
                else
                begin
                    AddrIndex index = ipToIndexMapping(dst_ip);
                    ring_buffer_index_fifo.enq(index);
                end
            end

            buffer_fifo.enq(d.data);
        end
    endrule

    rule extract_ring_buffer_index_to_add_to
                (curr_state == RUN && ready_to_deq_from_index_buffer == 1);
        let index <- toGet(ring_buffer_index_fifo).get;
        curr_ring_buffer_index <= index;
        ready_to_deq_from_index_buffer <= 0;
        ready_to_deq_from_ring_buffer <= 1;
    endrule

    rule add_to_correct_ring_buffer
                (curr_state == RUN && ready_to_deq_from_ring_buffer == 1);
        let d <- toGet(buffer_fifo).get;

        if (d.sop == 0 && d.eop == 1)
        begin
            ready_to_deq_from_index_buffer <= 1;
            ready_to_deq_from_ring_buffer <= 0;
        end

        if (curr_ring_buffer_index != 0)
            ring_buffer[curr_ring_buffer_index].write_request.put
                            (makeWriteReq(d.sop, d.eop, d.payload));
        else
            src_rx_ring_buffer.write_request.put
                            (makeWriteReq(d.sop, d.eop, d.payload));
        $display("[SCHED (%d)] buffer index to put data into = %d  data = %d %d %x",
                   host_index, curr_ring_buffer_index, d.sop, d.eop, d.payload);
    endrule

/*-------------------------------------------------------------------------------*/
    Reg#(Bit#(64)) curr_slot <- mkReg(0);
    Reg#(AddrIndex) ring_buffer_index <- mkReg(0);
    Reg#(MAC) dst_mac_addr <- mkReg(0);
    Reg#(Bit#(1)) wait_for_res <- mkReg(0);

    rule get_dst_addr (curr_state == RUN && clk == start_time);
        start_time <= start_time + interval;
        curr_slot <= (curr_slot + 1) % (fromInteger(valueof(NUM_OF_SERVERS)) - 1);

        $display("[SCHED (%d)] CLK = %d  schedule_list[%d] = %d", host_index,
                                         clk, curr_slot, schedule_list[curr_slot]);
        /* Get the dst mac and ip addr */
        sched_table.request.put
            (makeTableReqRes(0, 0, schedule_list[curr_slot], GET, SUCCESS));

        wait_for_res <= 1;
    endrule

    rule extract_from_correct_ring_buffer (curr_state == RUN && wait_for_res == 1);
        let d <- sched_table.response.get;
        wait_for_res <= 0;
        dst_mac_addr <= d.server_mac;
        $display("[SCHED (%d)] MAC = %x IP = %x", host_index,
                                              d.server_mac, d.server_ip);
        /* Get the index of the ring buffer to extract from */
        AddrIndex index = ipToIndexMapping(d.server_ip);
        ring_buffer_index <= index;

        $display("[SCHED (%d)] buffer index to extract from = %d %d", host_index,
                               index, ring_buffer[index].num_of_elements);

        Bool is_empty <- ring_buffer[index].empty;

        /*
         * Only if the forwarding ring buffer is empty, extract packet from
         * the host tx buffer.
         */
        if (!is_empty)
            ring_buffer[index].read_request.put(makeReadReq(READ));
        else
        begin
            $display("[SCHED (%d)] Empty forwarding buffer; extracting from host tx",
                    host_index);
            ring_buffer[0].read_request.put(makeReadReq(READ));
        end

    endrule

    for (Integer i = 0; i < fromInteger(valueof(NUM_OF_SERVERS)); i = i + 1)
    begin
        rule modify_mac_headers_and_put_to_tx (curr_state == RUN);
            let d <- ring_buffer[i].read_response.get;

            if (d.data.sop == 1 && d.data.eop == 0)
            begin
                /* Update MAC header */
                Bit#(96) new_addr = {host_mac_addr, dst_mac_addr};
                Bit#(96) zero = 0;
                Bit#(BUS_WIDTH) temp = {'1, zero};
                d.data.payload = (d.data.payload & temp) | zeroExtend(new_addr);
            end

            $display("[SCHED (%d)] data written to tx port buffer %d %d %x",
                             host_index, d.data.sop, d.data.eop, d.data.payload);
            tx_ring_buffer.write_request.put
                    (makeWriteReq(d.data.sop, d.data.eop, d.data.payload));
        endrule
    end

/*-------------------------------------------------------------------------------*/
    rule clock_simulator (curr_state == RUN && clk < 20000);
        clk <= clk + 1;
    endrule

/*-------------------------------------------------------------------------------*/
    rule handle_controller_req (table_op_in_progress == 0);
        let req <- toGet(request_fifo).get;
        sched_req_fifo.enq(req);
        case (req.op)
            SETTIME     : curr_op <= SETTIME;
            GETTIME     : curr_op <= GETTIME;
            SETINTERVAL : curr_op <= SETINTERVAL;
            GETINTERVAL : curr_op <= GETINTERVAL;
            INSERT      : begin
                          curr_op <= INSERT;
                          table_op_in_progress <= 1;
                          end
            DELETE      : begin
                          curr_op <= DELETE;
                          table_op_in_progress <= 1;
                          end
            DISPLAY     : begin
                          curr_op <= DISPLAY;
                          table_op_in_progress <= 1;
                          end
            STARTSCHED  : begin
                          curr_state <= RUN;
                          configure <= 1;
                          get_host_mac <= 1;
                          start_polling_rx_buffer <= 0;
                          end
            STOPSCHED   : curr_state <= CONFIG;
        endcase
    endrule

    rule handle_rx_buffer_write_req_from_mac;
        let req <- toGet(mac_write_request_fifo).get;
        $display("[SCHED (%d)] Putting data into rx port buffer %d %d %x",
                          host_index, req.data.sop, req.data.eop, req.data.payload);
        rx_ring_buffer.write_request.put
              (makeWriteReq(req.data.sop, req.data.eop, req.data.payload));
    endrule

    rule handle_tx_buffer_read_req_from_mac;
        let req <- toGet(mac_read_request_fifo).get;
        tx_ring_buffer.read_request.put(makeReadReq(req.op));
    endrule

    rule handle_tx_buffer_read_res_to_mac;
        let d <- tx_ring_buffer.read_response.get;
        mac_read_response_fifo.enq(makeReadRes(d.data));
    endrule

    rule handle_dma_simulator_write_req;
        let req <- toGet(dma_write_request_fifo).get;
        //$display("[SCHED (%d)] Putting data into host tx buffer %d %d %x",
        //                  host_index, req.data.sop, req.data.eop, req.data.payload);
        ring_buffer[0].write_request.put
            (makeWriteReq(req.data.sop, req.data.eop, req.data.payload));
    endrule

    rule handle_dma_simulator_read_req;
        let req <- toGet(dma_read_request_fifo).get;
        src_rx_ring_buffer.read_request.put(makeReadReq(READ));
    endrule

    rule consume_pkt_in_response_to_dma_simulator_read_req;
        let d <- src_rx_ring_buffer.read_response.get;
        $display("[SCHED (%d)] CONSUMING from host rx buffer %d %d %x", host_index,
                                          d.data.sop, d.data.eop, d.data.payload);
    endrule

    /* Controller interface */
    interface Put request = toPut(request_fifo);
    interface Get settime_response = toGet(settime_response_fifo);
    interface Get gettime_response = toGet(gettime_response_fifo);
    interface Get setinterval_response = toGet(setinterval_response_fifo);
    interface Get getinterval_response = toGet(getinterval_response_fifo);
    interface Get insert_response = toGet(insert_response_fifo);
    interface Get delete_response = toGet(delete_response_fifo);
    interface Get display_response = toGet(display_response_fifo);

    /* MAC interface */
    interface Put mac_read_request = toPut(mac_read_request_fifo);
    interface Put mac_write_request = toPut(mac_write_request_fifo);
    interface Get mac_read_response = toGet(mac_read_response_fifo);
    interface Get mac_write_response = toGet(mac_write_response_fifo);

    /* DMA simulator interface */
    interface Put dma_read_request = toPut(dma_read_request_fifo);
    interface Put dma_write_request = toPut(dma_write_request_fifo);
    interface Get dma_read_response = toGet(dma_read_response_fifo);
    interface Get dma_write_response = toGet(dma_write_response_fifo);
endmodule
