import FIFOF::*;
import GetPut::*;
import ClientServer::*;
import StmtFSM::*;
import Vector::*;
import DefaultValue::*;
import BRAM::*;

import P4Types::*;
import HashFunction::*;
import HashTable::*;

module mkMatchTable_Hash (Server#(RequestType, ResponseType));
    function BRAMRequest#(Address, Bit#(TABLE_ASSOCIATIVITY))
        makeRequest(Bool write, Address addr, Bit#(TABLE_ASSOCIATIVITY) data);
        return BRAMRequest {
            write : write,
            responseOnWrite : False,
            address : addr,
            datain : data
        };
    endfunction
    
    BRAM_Configure cfg = defaultValue;
    cfg.memorySize = fromInteger(valueof(TABLE_LEN))
                   * fromInteger(valueof(TABLE_ASSOCIATIVITY));
    
    BRAM2Port#(Address, Bit#(TABLE_ASSOCIATIVITY)) validBitMem  <- mkBRAM2Server(cfg);

    Vector#(TABLE_ASSOCIATIVITY, Server#(RequestType, ResponseType)) hTable <-
                replicateM(mkHashTable);

    FIFOF#(RequestType) requestFIFO <- mkSizedFIFOF(10);
    FIFOF#(ResponseType) responseFIFO <- mkFIFOF;

    Reg#(RequestType) currRequest <- mkReg(defaultValue);
    
    /* Flag to make sure PUT and REM ops are atomic */
    Reg#(Bit#(1)) opInProgress <- mkReg(0);
    
    /* Pipeline Registers*/
    Reg#(Address) address <- mkReg(0);
    Reg#(Bit#(3)) index <- mkReg(0); // change bit size if u change ASSOCIATIVITY

    Vector#(TABLE_ASSOCIATIVITY, FIFOF#(Bit#(1))) remResFIFO <- replicateM(mkFIFOF);

    for (Integer i=0; i<fromInteger(valueof(TABLE_ASSOCIATIVITY)); i=i+1)
    begin
        rule response_from_hTable;
            ResponseType res <- hTable[i].response.get; 
            if (res.op == GET) 
            begin
                if (res.tag == VALID)
                    responseFIFO.enq(res);
            end
            else if (res.op == REMOVE)
            begin
                if (res.tag == VALID)
                begin
                    Address addr = zeroExtend(res.addrIdx)
                                 * fromInteger(valueof(TABLE_ASSOCIATIVITY));
                    validBitMem.portB.request.put(makeRequest(False, addr, 0));
                    index <= fromInteger(i);
                    address <= addr;
                    remResFIFO[i].enq(1);
                end
                else
                    remResFIFO[i].enq(0);
            end
        endrule
    end

    rule rem_request;
        Integer found = 0;
        for (Integer i=0; i<fromInteger(valueof(TABLE_ASSOCIATIVITY)); i=i+1)
        begin
            let flag <- toGet(remResFIFO[i]).get;
            if (found == 0 && flag == 1)
            begin
                found = 1;
                let d <- validBitMem.portB.response.get;
                d[index] = 0;
                validBitMem.portB.request.put(makeRequest(True, address, d));
            end
        end
        opInProgress <= 0;
    endrule

    rule put_request;
        Bit#(TABLE_ASSOCIATIVITY) d <- validBitMem.portA.response.get;
        Integer found = 0;
        for (Integer i=0; i<fromInteger(valueof(TABLE_ASSOCIATIVITY)); i=i+1)
        begin
            if (found == 0 && d[i] == 0)
            begin
                d[i] = 1;
                hTable[i].request.put(currRequest);
                validBitMem.portA.request.put(makeRequest(True, address, d));
                found = 1;
            end
        end
        if (found == 0)
            $display("PUT Failed : No Empty slots");
        
        opInProgress <= 0;
    endrule

    rule start (opInProgress == 0);
        let currReq <- toGet(requestFIFO).get;
        AddrIndex addrIdx = hash_function(currReq.key);
        currReq.addrIdx = addrIdx;
        if (currReq.op == REMOVE)
            opInProgress <= 1;
        if (currReq.op == PUT)
        begin
            opInProgress <= 1;
            Address addr = zeroExtend(addrIdx)
                         * fromInteger(valueof(TABLE_ASSOCIATIVITY));
            validBitMem.portA.request.put(makeRequest(False, addr, 0));
            address <= addr;
        end
        else
        begin
            for (Integer i=0; i<fromInteger(valueof(TABLE_ASSOCIATIVITY)); i=i+1)
                hTable[i].request.put(currReq);
        end
        currRequest <= currReq;
    endrule

    interface Put request = toPut(requestFIFO);
    interface Get response = toGet(responseFIFO);
endmodule
