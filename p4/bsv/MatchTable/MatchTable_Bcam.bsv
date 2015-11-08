import FIFOF::*;
import GetPut::*;
import ClientServer::*;
import StmtFSM::*;
import Vector::*;
import DefaultValue::*;
import BRAM::*;

import P4Types::*;
import Bcam::*;

module mkMatchTable_Bcam (Server#(RequestType, ResponseType));
    BinaryCam#(BCAM_TABLE_LEN, KEY_LEN) bcam <- mkBinaryCam;

    BRAM_Configure cfg = defaultValue;
    cfg.memorySize = fromInteger(valueof(BCAM_TABLE_LEN))
                   * fromInteger(valueof(VALUE_LEN));

    BRAM2Port#(Address, Value) valueMem  <- mkBRAM2Server(cfg);
    
    function BRAMRequest#(Address, Value)
        makeRequest(Bool write, Address addr, Value data);
        return BRAMRequest {
            write : write,
            responseOnWrite : False,
            address : addr,
            datain : data
        };
    endfunction

    FIFOF#(RequestType) requestFIFO <- mkSizedFIFOF(10);
    FIFOF#(ResponseType) responseFIFO <- mkFIFOF;
    
    Reg#(AddrIndex) addrIdx <- mkReg(5);

    /* Pipeline FIFOs */
    FIFOF#(RequestType) put_fifo <- mkFIFOF;
    FIFOF#(RequestType) get_fifo_1 <- mkFIFOF;
    FIFOF#(RequestType) get_fifo_2 <- mkFIFOF;

    rule put_value_to_bram;
        let currReq <- toGet(put_fifo).get;
        addrIdx <= (currReq.addrIdx + 1) % fromInteger(valueof(BCAM_TABLE_LEN));
        Address addr = zeroExtend(currReq.addrIdx)
                     * fromInteger(valueof(VALUE_LEN));
        $display("Putting value to address = %d", addr);
        valueMem.portA.request.put(makeRequest(True, addr, currReq.value));
    endrule

    rule get_addr_from_bcam;
        let currReq <- toGet(get_fifo_1).get;
        Maybe#(Bit#(TLog#(BCAM_TABLE_LEN))) a <- bcam.readServer.response.get;
        Address addr = zeroExtend(pack(fromMaybe(0,a))) * fromInteger(valueof(VALUE_LEN));
        $display("Getting value from address = %d", addr);
        valueMem.portA.request.put(makeRequest(False, addr, 0));
        get_fifo_2.enq(currReq);
    endrule

    rule get_value_from_bram;
        let currReq <- toGet(get_fifo_2).get;
        let value <- valueMem.portA.response.get;
        responseFIFO.enq(makeResponse(currReq.key, value, 0, GET, VALID));
    endrule

    rule start;
        let currReq <- toGet(requestFIFO).get;
        if (currReq.op == PUT)
        begin
            bcam.writeServer.put(tuple2(truncate(addrIdx), truncate(currReq.key)));
            currReq.addrIdx = addrIdx;
            put_fifo.enq(currReq);
        end
        else if (currReq.op == GET)
        begin
            bcam.readServer.request.put(truncate(currReq.key));
            get_fifo_1.enq(currReq);
        end

    endrule

    interface Put request = toPut(requestFIFO);
    interface Get response = toGet(responseFIFO);
endmodule
