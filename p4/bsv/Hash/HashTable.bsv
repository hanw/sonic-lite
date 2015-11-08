import Vector::*;
import FIFOF::*;
import SpecialFIFOs::*;
import BRAM::*;
import StmtFSM::*;
import GetPut::*;
import ClientServer::*;
import DefaultValue::*;

import MatchTableTypes::*;
import HashFunction::*;

module mkHashTable (Server#(RequestType, ResponseType)); 
    FIFOF#(RequestType) requestFIFO <- mkBypassFIFOF;
    FIFOF#(ResponseType) responseFIFO <- mkBypassFIFOF;
    
    function BRAMRequest#(Address, Data) 
            makeRequest(Bool write, Address addr, Key key, Value value, Tag t);
        Data data = Data {
                          key : key,
                          value : value,
                          valid : t
                          };
        return BRAMRequest {
                            write : write,
                            responseOnWrite : False,
                            address : addr,
                            datain : data
                            };
    endfunction

    function ResponseType makeResponse(Key key, Value value, AddrIndex addrIdx, Operation op, Tag tag);
        return ResponseType {
                             key : key,
                             value : value,
                             addrIdx : addrIdx,
                             op : op,
                             tag : tag
                            };
    endfunction

    BRAM_Configure cfg = defaultValue;
    cfg.memorySize = fromInteger(valueof(TABLE_LEN))
                   * (fromInteger(valueof(KEY_LEN))
                   + fromInteger(valueof(VALUE_LEN)));  // total memory size

    BRAM2Port#(Address, Data) hashTable <- mkBRAM2Server(cfg);
    
    Reg#(Address) a <- mkReg(0);
    Reg#(AddrIndex) aIdx <- mkReg(0);

    FIFOF#(RequestType) hTable_get_req_fifo <- mkFIFOF;
    FIFOF#(RequestType) hTable_put_req_fifo <- mkFIFOF;
    FIFOF#(RequestType) hTable_update_req_fifo <- mkFIFOF;
    FIFOF#(RequestType) hTable_remove_req_fifo <- mkFIFOF;
    FIFOF#(RequestType) hTable_non_empty_slots_req_fifo <- mkFIFOF;
    
    FIFOF#(RequestType) hTable_get_res_fifo <- mkFIFOF;
    FIFOF#(RequestType) hTable_update_res_fifo <- mkFIFOF;
    FIFOF#(RequestType) hTable_remove_res_fifo <- mkFIFOF;
    FIFOF#(RequestType) hTable_non_empty_slots_res_fifo <- mkFIFOF;

    rule hTable_get_req;
        RequestType req <- toGet(hTable_get_req_fifo).get;
        AddrIndex addrIdx = req.addrIdx;
        Address addr = zeroExtend(addrIdx)
                     * (fromInteger(valueof(KEY_LEN))
                     + fromInteger(valueof(VALUE_LEN)));
        hashTable.portB.request.put(makeRequest(False, addr, 0, 0, VALID));
        hTable_get_res_fifo.enq(req);
    endrule

    rule hTable_get_res;
        RequestType req <- toGet(hTable_get_res_fifo).get;
        Data d <- hashTable.portB.response.get;
        if (d.valid == VALID && d.key == req.key)
            responseFIFO.enq(makeResponse(d.key, d.value, req.addrIdx, GET, VALID));
        else
            responseFIFO.enq(makeResponse(0, 0, req.addrIdx, GET, INVALID));
    endrule

    rule hTable_put_req;
        RequestType req <- toGet(hTable_put_req_fifo).get;
        AddrIndex addrIdx = req.addrIdx;
        Address addr = zeroExtend(addrIdx)
                     * (fromInteger(valueof(KEY_LEN))
                     + fromInteger(valueof(VALUE_LEN)));
        hashTable.portA.request.put
                (makeRequest(True, addr, req.key, req.value, VALID));
    endrule

    rule hTable_update_req; 
        RequestType req <- toGet(hTable_update_req_fifo).get;
        AddrIndex addrIdx = req.addrIdx;
        Address addr = zeroExtend(addrIdx)
                     * (fromInteger(valueof(KEY_LEN))
                     + fromInteger(valueof(VALUE_LEN)));
        hashTable.portB.request.put(makeRequest(False, addr, 0, 0, VALID));
        hTable_update_res_fifo.enq(req);
    endrule

    rule hTable_update_res;
        RequestType req <- toGet(hTable_update_res_fifo).get;
        Data d <- hashTable.portB.response.get;
        if (d.valid == VALID && d.key == req.key)
        begin
            AddrIndex addrIdx = req.addrIdx;
            Address addr = zeroExtend(addrIdx)
                         * (fromInteger(valueof(KEY_LEN))
                         + fromInteger(valueof(VALUE_LEN)));
            hashTable.portB.request.put
                        (makeRequest(True, addr, req.key, req.value, VALID));
        end
    endrule
    
    rule hTable_remove_req;
        RequestType req <- toGet(hTable_remove_req_fifo).get;
        AddrIndex addrIdx = req.addrIdx;
        Address addr = zeroExtend(addrIdx)
                     * (fromInteger(valueof(KEY_LEN))
                     + fromInteger(valueof(VALUE_LEN)));
        hashTable.portB.request.put(makeRequest(False, addr, 0, 0, VALID));
        hTable_remove_res_fifo.enq(req);
    endrule
    
    rule hTable_remove_res;
        RequestType req <- toGet(hTable_remove_res_fifo).get;
        Data d <- hashTable.portB.response.get;
        if (d.key == req.key)
        begin
            AddrIndex addrIdx = req.addrIdx;
            Address addr = zeroExtend(addrIdx)
                         * (fromInteger(valueof(KEY_LEN))
                         + fromInteger(valueof(VALUE_LEN)));
            hashTable.portB.request.put
                        (makeRequest(True, addr, req.key, req.value, INVALID));
            responseFIFO.enq(makeResponse(0, 0, req.addrIdx, REMOVE, VALID));
        end
        else
            responseFIFO.enq(makeResponse(0, 0, req.addrIdx, REMOVE, INVALID));
    endrule

    rule run;
        let currReq <- toGet(requestFIFO).get;
        case (currReq.op)
            GET    : hTable_get_req_fifo.enq(currReq);
            PUT    : hTable_put_req_fifo.enq(currReq);
            UPDATE : hTable_update_req_fifo.enq(currReq);
            REMOVE : hTable_remove_req_fifo.enq(currReq);
        endcase
    endrule
    
    interface Put request = toPut(requestFIFO);
    interface Get response = toGet(responseFIFO);
endmodule

