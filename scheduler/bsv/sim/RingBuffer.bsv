import FIFO::*;
import SpecialFIFOs::*;
import BRAM::*;
import GetPut::*;
import DefaultValue::*;

import RingBufferTypes::*;
import GlobalClock::*;

interface RingBuffer#(type readReqType, type readResType,
                      type writeReqType, type writeResType);
    interface Put#(readReqType) read_request;
    interface Put#(writeReqType) write_request;
    interface Get#(readResType) read_response;
    interface Get#(writeResType) write_response;

    method ActionValue#(Bool) empty();
    method ActionValue#(Bool) full();
    method ActionValue#(Bit#(64)) elements();
endinterface

module mkRingBuffer#(Integer size)
        (RingBuffer#(ReadReqType, ReadResType, WriteReqType, WriteResType));

    function BRAMRequest#(Address, Payload)
      makeBRAMDataRequest(Bool write, Address addr, Payload data);
        return BRAMRequest {
                            write           : write,
                            responseOnWrite : False,
                            address         : addr,
                            datain          : data
                            };
    endfunction

    BRAM_Configure cfg = defaultValue;
    cfg.memorySize = fromInteger(size)
                   * fromInteger(valueof(MAX_PKT_LEN));

    BRAM2Port#(Address, Payload) ring_buffer <- mkBRAM2Server(cfg);

/*-------------------------------------------------------------------------------*/
    function BRAMRequest#(Address, Bit#(32))
      makeBRAMLenRequest(Bool write, Address addr, Bit#(32) data);
        return BRAMRequest {
                            write           : write,
                            responseOnWrite : False,
                            address         : addr,
                            datain          : data
                            };
    endfunction

    BRAM_Configure cfg1 = defaultValue;
    cfg1.memorySize = fromInteger(size) * 32;

    BRAM2Port#(Address, Bit#(32)) len_buffer <- mkBRAM2Server(cfg1);

/*-------------------------------------------------------------------------------*/
    Reg#(Bit#(64)) head <- mkReg(0);
    Reg#(Bit#(64)) tail <- mkReg(0);

    Bool is_empty = (head == tail);
    Bool is_full = (head == tail + fromInteger(size));

    FIFO#(ReadReqType) read_request_fifo <- mkFIFO;
    FIFO#(ReadResType) read_response_fifo <- mkFIFO;
    FIFO#(WriteReqType) write_request_fifo <- mkFIFO;
    FIFO#(WriteResType) write_response_fifo <- mkFIFO;

	GlobalClock clk <- mkGlobalClock;
/*-------------------------------------------------------------------------------*/
    Reg#(Bit#(1)) write_in_progress <- mkReg(0);
    Reg#(Address) w_offset <- mkReg(0);
    Reg#(Bit#(32)) length <- mkReg(0);

    rule write_req;
        let w_req <- toGet(write_request_fifo).get;

        Bool write_flag = False;

        if (!is_full)
        begin
            if ((w_req.data.sop == 1 && w_req.data.eop == 0)
               && write_in_progress == 0)
            begin
                write_in_progress <= 1;
                write_flag = True;
                w_offset <= w_offset + 1;
                length <= length + fromInteger(valueof(BUS_WIDTH));
            end

            else if ((w_req.data.sop == 0 && w_req.data.eop == 0)
                    && write_in_progress == 1)
            begin
                write_flag = True;
                w_offset <= w_offset + 1;
                length <= length + fromInteger(valueof(BUS_WIDTH));
            end

            else if ((w_req.data.sop == 0 && w_req.data.eop == 1)
                    && write_in_progress == 1)
            begin
                write_in_progress <= 0;
                write_flag = True;
                head <= head + 1;
                w_offset <= 0;
                length <= 0;
                Address addr = (truncate(head) & (fromInteger(size)-1)) << 5;
                len_buffer.portA.request.put(makeBRAMLenRequest(True, addr,
                                        length + fromInteger(valueof(BUS_WIDTH))));
                //write_response_fifo.enq(makeWriteRes(SUCCESS));
            end

            else if ((w_req.data.sop == 1 && w_req.data.eop == 1)
                    && write_in_progress == 0)
            begin
                write_flag = True;
                head <= head + 1;
                w_offset <= 0;
                length <= 0;
                Address addr = (truncate(head) & (fromInteger(size)-1)) << 5;
                len_buffer.portA.request.put(makeBRAMLenRequest(True, addr,
                                         length + fromInteger(valueof(BUS_WIDTH))));
                //write_response_fifo.enq(makeWriteRes(SUCCESS));
            end

            //else
            //    write_response_fifo.enq(makeWriteRes(FAILURE));

            if (write_flag == True)
            begin
            Address addr = ((truncate(head) & (fromInteger(size)-1))
					     << fromInteger(valueof(MAX_PKT_LEN_POW_OF_2)))
                         + (w_offset << fromInteger(valueof(BUS_WIDTH_POW_OF_2)));
            ring_buffer.portA.request.put(makeBRAMDataRequest(True, addr,
                                                               w_req.data.payload));
            end
        end
        //else
        //    write_response_fifo.enq(makeWriteRes(FAILURE));
    endrule

/*-------------------------------------------------------------------------------*/
    Reg#(Bit#(1)) read_in_progress <- mkReg(0);
    Reg#(Address) r_offset <- mkReg(0);
    Reg#(Address) r_offset_1 <- mkReg(0);
    Reg#(Address) r_max_offset <- mkReg(0);
    Reg#(Bit#(1)) next_round <- mkReg(1);

    rule read_req (read_in_progress == 0);
        let r_req <- toGet(read_request_fifo).get;

        if (!is_empty)
        begin
            read_in_progress <= 1;
			r_offset <= 0;
			r_offset_1 <= 1;
			r_max_offset <= 0;
            Address addr = (truncate(tail) & (fromInteger(size)-1)) << 5;
            len_buffer.portB.request.put(makeBRAMLenRequest(False, addr, 0));
        end
        //else
        //    read_response_fifo.enq(makeReadRes(unpack(0)));
    endrule

    rule read_len_res;
        let len <- len_buffer.portB.response.get;

        if ((len & (fromInteger(valueof(BUS_WIDTH))-1)) == 0)
            r_max_offset <= len >> fromInteger(valueof(BUS_WIDTH_POW_OF_2));
        else
            r_max_offset <= (len >> fromInteger(valueof(BUS_WIDTH_POW_OF_2))) + 1;
    endrule

    rule read_data_req (r_offset < r_max_offset);
        Address addr = ((truncate(tail) & (fromInteger(size)-1))
                     << fromInteger(valueof(MAX_PKT_LEN_POW_OF_2)))
                     + (r_offset << fromInteger(valueof(BUS_WIDTH_POW_OF_2)));
        ring_buffer.portB.request.put(makeBRAMDataRequest(False, addr, 0));
        r_offset <= r_offset + 1;
    endrule

    rule read_data_res;
        let d <- ring_buffer.portB.response.get;

		r_offset_1 <= r_offset_1 + 1;

        if (r_offset_1 - 1 == 0 && r_offset_1 < r_max_offset)
        begin
            RingBufferDataT data = RingBufferDataT {
                              sop : 1,
                              eop : 0,
                              payload : d
                             };
            read_response_fifo.enq(makeReadRes(data));
        end

        else if (r_offset_1 - 1 > 0 && r_offset_1 < r_max_offset)
        begin
            RingBufferDataT data = RingBufferDataT {
                              sop : 0,
                              eop : 0,
                              payload : d
                             };
            read_response_fifo.enq(makeReadRes(data));
        end

        else if (r_offset_1 - 1 > 0 && r_offset_1 == r_max_offset)
        begin
            RingBufferDataT data = RingBufferDataT {
                              sop : 0,
                              eop : 1,
                              payload : d
                             };
            read_response_fifo.enq(makeReadRes(data));
            read_in_progress <= 0;
            tail <= tail + 1;
        end

        else if (r_offset_1 - 1 == 0 && r_offset_1 == r_max_offset)
        begin
            RingBufferDataT data = RingBufferDataT {
                              sop : 1,
                              eop : 1,
                              payload : d
                             };
            read_response_fifo.enq(makeReadRes(data));
            read_in_progress <= 0;
            tail <= tail + 1;
        end
    endrule

/*-------------------------------------------------------------------------------*/
    method ActionValue#(Bool) empty();
        return is_empty;
    endmethod

    method ActionValue#(Bool) full();
        return is_full;
    endmethod

    method ActionValue#(Bit#(64)) elements();
        return (head - tail);
    endmethod

    interface Put read_request = toPut(read_request_fifo);
    interface Put write_request = toPut(write_request_fifo);
    interface Get read_response = toGet(read_response_fifo);
    interface Get write_response = toGet(write_response_fifo);
endmodule

