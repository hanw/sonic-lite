import Vector::*;
import FIFOF::*;
import SpecialFIFOs::*;
import BRAM::*;
import GetPut::*;
import ClientServer::*;
import DefaultValue::*;

import SchedulerTypes::*;

module mksched_table (Server#(TableReqResType, TableReqResType));
    FIFOF#(TableReqResType) request_fifo <- mkSizedFIFOF(5);
    FIFOF#(TableReqResType) response_fifo <- mkFIFOF;

    function BRAMRequest#(Address, Data)
      makeBRAMRequest(Bool write, Address addr, IP ip, MAC mac, Bit#(1) valid_bit);
        Data data = Data {
                          server_ip  : ip,
                          server_mac : mac,
                          is_valid   : valid_bit
                          };
        return BRAMRequest {
                            write           : write,
                            responseOnWrite : False,
                            address         : addr,
                            datain          : data
                            };
    endfunction

    function Address index_to_addr(AddrIndex addrIdx);
        Address addr = zeroExtend(addrIdx)
                     * (fromInteger(valueof(IP_ADDR_LEN))
                     + fromInteger(valueof(MAC_ADDR_LEN))
                     + 1);
        return addr;
    endfunction

    BRAM_Configure cfg = defaultValue;
    cfg.memorySize = fromInteger(valueof(TABLE_LEN))
                   * (fromInteger(valueof(IP_ADDR_LEN))
                   + fromInteger(valueof(MAC_ADDR_LEN))
                   + 1);  /* total memory size */

    BRAM2Port#(Address, Data) sched_table <- mkBRAM2Server(cfg);

    Reg#(Bit#(1)) op_in_progress <- mkReg(0);
    Reg#(Bit#(1)) rem_in_progress <- mkReg(0);
    Reg#(Bit#(1)) put_in_progress <- mkReg(0);

    Reg#(AddrIndex) curr_index <- mkReg(0);
    Reg#(TableReqResType) curr_req <- mkReg(defaultValue);

    Reg#(AddrIndex) index_itr <- mkReg(0);

/*-----------------------------------------------------------------------------*/
    FIFOF#(TableReqResType) table_get_req_fifo <- mkFIFOF;
    FIFOF#(TableReqResType) table_get_res_fifo <- mkFIFOF;

    rule table_get_req;
        let req <- toGet(table_get_req_fifo).get;
        AddrIndex addrIdx = req.addrIdx;
        Address addr = index_to_addr(addrIdx);
        sched_table.portA.request.put(makeBRAMRequest(False, addr, 0, 0, 0));
        table_get_res_fifo.enq(req);
    endrule

    rule table_get_res;
        let req <- toGet(table_get_res_fifo).get;
        Data d <- sched_table.portA.response.get;
        if (d.is_valid == 1)
            response_fifo.enq
            (makeTableReqRes(d.server_ip, d.server_mac, req.addrIdx, GET, SUCCESS));
        else
            response_fifo.enq
             (makeTableReqRes(0, 0, 0, GET, FAILURE));

        op_in_progress <= 0;
    endrule

/*-----------------------------------------------------------------------------*/
    Reg#(Bit#(1)) found_free_slot <- mkReg(0);
    FIFOF#(TableReqResType) table_put_pipeline_fifo <- mkPipelineFIFOF;

    rule table_put_req (put_in_progress == 1);
        if (found_free_slot == 0 && index_itr < fromInteger(valueOf(TABLE_LEN)))
        begin
            Address addr = index_to_addr(curr_index);
            sched_table.portA.request.put(makeBRAMRequest(False, addr, 0, 0, 0));
            table_put_pipeline_fifo.enq(curr_req);
            index_itr <= index_itr + 1;
        end
        else
        begin
            put_in_progress <= 0;
            op_in_progress <= 0;
            if (index_itr >= fromInteger(valueOf(TABLE_LEN)))
                response_fifo.enq(makeTableReqRes(0, 0, 0, PUT, FAILURE));
        end
    endrule

    rule table_put_check;
        let req <- toGet(table_put_pipeline_fifo).get;
        if (found_free_slot == 0)
        begin
            curr_index <= (curr_index + 1) % fromInteger(valueOf(TABLE_LEN));
            Data d <- sched_table.portA.response.get;
            if (d.is_valid == 0)
            begin
                Address addr = index_to_addr(curr_index);
                sched_table.portB.request.put
                   (makeBRAMRequest(True, addr, req.server_ip, req.server_mac, 1));
                found_free_slot <= 1;
                response_fifo.enq(makeTableReqRes(0, 0, 0, PUT, SUCCESS));
            end
        end
    endrule

/*-----------------------------------------------------------------------------*/
    Reg#(Bit#(1)) found_item_to_remove <- mkReg(0);
    FIFOF#(TableReqResType) table_rem_pipeline_fifo <- mkPipelineFIFOF;

    rule table_rem_req (rem_in_progress == 1);
        if(found_item_to_remove==0 && index_itr < fromInteger(valueOf(TABLE_LEN)))
        begin
            Address addr = index_to_addr(index_itr);
            sched_table.portA.request.put(makeBRAMRequest(False, addr, 0, 0, 0));
            table_rem_pipeline_fifo.enq(curr_req);
        end
        else
        begin
            rem_in_progress <= 0;
            op_in_progress <= 0;
            if (index_itr >= fromInteger(valueOf(TABLE_LEN)))
                response_fifo.enq(makeTableReqRes(0, 0, 0, REMOVE, FAILURE));
        end
    endrule

    rule table_rem_check;
        let req <- toGet(table_rem_pipeline_fifo).get;
        if (found_item_to_remove == 0)
        begin
            index_itr <= index_itr + 1;
            Data d <- sched_table.portA.response.get;
            if (d.server_ip == req.server_ip && d.server_mac == req.server_mac)
            begin
                Address addr = index_to_addr(index_itr);
                sched_table.portB.request.put
                                      (makeBRAMRequest(True, addr, 0, 0, 0));
                found_item_to_remove <= 1;
                response_fifo.enq(makeTableReqRes(0, 0, 0, REMOVE, SUCCESS));
            end
        end
    endrule

/*-----------------------------------------------------------------------------*/
    rule run (op_in_progress == 0);
        op_in_progress <= 1;
        let req <- toGet(request_fifo).get;
        case (req.op)
            GET    : table_get_req_fifo.enq(req);
            PUT    : begin
                     put_in_progress <= 1;
                     curr_req <= req;
                     index_itr <= 0;
                     found_free_slot <= 0;
                     end
            REMOVE : begin
                     rem_in_progress <= 1;
                     curr_req <= req;
                     index_itr <= 0;
                     found_item_to_remove <= 0;
                     end
        endcase
    endrule

    interface Put request = toPut(request_fifo);
    interface Get response = toGet(response_fifo);
endmodule

