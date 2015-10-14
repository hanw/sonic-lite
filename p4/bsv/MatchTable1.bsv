import FIFOF::*;
import SpecialFIFOs::*;
import GetPut::*;
import ClientServer::*;
import StmtFSM::*;
import Vector::*;
import DefaultValue::*;

import MatchTableTypes::*;
import HashFunction::*;
import HashTable::*;

module mkMatchTable (Server#(RequestType, ResponseType));

    function RequestType backup (RequestType currReq);
        return RequestType {
            key : currReq.key,
            value : currReq.value,
            op : currReq.op,
            addrIdx : currReq.addrIdx
        };
    endfunction

    Vector#(MATCH_TABLE_ASSOCIATIVITY, Server#(RequestType, ResponseType)) hTable <-
                replicateM(mkHashTable);

    FIFOF#(RequestType) requestFIFO <- mkSizedBypassFIFOF(10);
    FIFOF#(ResponseType) responseFIFO <- mkBypassFIFOF;

    Reg#(RequestType) currReq <- mkReg(defaultValue);
    Reg#(RequestType) currReq_backup <- mkReg(defaultValue);
    Vector#(MATCH_TABLE_ASSOCIATIVITY, Reg#(Bit#(1))) free <- replicateM(mkReg(1));
    Reg#(Bit#(1)) putInProgress <- mkReg(0);
    FIFOF#(Bit#(1)) fsm_start_signal_fifo <- mkFIFOF;

    for (Integer i=0; i<fromInteger(valueof(MATCH_TABLE_ASSOCIATIVITY)); i=i+1)
    begin
        rule response_from_hTable;
            ResponseType res <- hTable[i].response.get; 
            if (res.tag == VALID && res.op == GET)    
                responseFIFO.enq(res);
        endrule
    end

    Stmt putFSM = (seq
    action
    endaction
    action
    endaction
    par
        action
            ResponseType res <- hTable[0].response.get;
            if (res.op == NON_EMPTY_SLOTS && res.tag == VALID)
                free[0] <= 0;
        endaction
        action
            ResponseType res <- hTable[1].response.get;
            if (res.op == NON_EMPTY_SLOTS && res.tag == VALID)
                free[1] <= 0;
        endaction
        action
            ResponseType res <- hTable[2].response.get;
            if (res.op == NON_EMPTY_SLOTS && res.tag == VALID)
                free[2] <= 0;
        endaction
        action
            ResponseType res <- hTable[3].response.get;
            if (res.op == NON_EMPTY_SLOTS && res.tag == VALID)
                free[3] <= 0;
        endaction
        action
            ResponseType res <- hTable[4].response.get;
            if (res.op == NON_EMPTY_SLOTS && res.tag == VALID)
                free[4] <= 0;
        endaction
        action
            ResponseType res <- hTable[5].response.get;
            if (res.op == NON_EMPTY_SLOTS && res.tag == VALID)
                free[5] <= 0;
        endaction
        action
            ResponseType res <- hTable[6].response.get;
            if (res.op == NON_EMPTY_SLOTS && res.tag == VALID)
                free[6] <= 0;
        endaction
        action
            ResponseType res <- hTable[7].response.get;
            if (res.op == NON_EMPTY_SLOTS && res.tag == VALID)
                free[7] <= 0;
        endaction
    endpar
    action
        Integer found = 0;
        for (Integer i=0; i<fromInteger(valueof(MATCH_TABLE_ASSOCIATIVITY)); i=i+1)
        begin
            if (found == 0 && free[i] == 1)
            begin
                $display("Putting at index = %d", i);
                hTable[i].request.put(currReq_backup);
                found = 1;
            end
        end
        putInProgress <= 0;
    endaction
    endseq);

    FSM fsm <- mkFSM(putFSM);

    rule start (putInProgress == 0);
        let currReq <- toGet(requestFIFO).get;
        AddrIndex addrIdx = hash_function(currReq.key);
        currReq.addrIdx = addrIdx;
        currReq_backup <= backup(currReq);
        if (currReq.op == PUT)
        begin
            for (Integer i=0; i<fromInteger(valueof(MATCH_TABLE_ASSOCIATIVITY));i=i+1)
                free[i] <= 1;
            putInProgress <= 1;
            currReq.op = NON_EMPTY_SLOTS;
            fsm_start_signal_fifo.enq(1);
        end
        for (Integer i=0; i<fromInteger(valueof(MATCH_TABLE_ASSOCIATIVITY)); i=i+1)
            hTable[i].request.put(currReq);
    endrule

    rule startFSM;
        let x <- toGet(fsm_start_signal_fifo).get;
        fsm.start();
    endrule
     
    interface Put request = toPut(requestFIFO);
    interface Get response = toGet(responseFIFO);
endmodule
