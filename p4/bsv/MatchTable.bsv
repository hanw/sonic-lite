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
    Vector#(8, Server#(RequestType, ResponseType)) hTable <-
                replicateM(mkHashTable);

    Vector#(TABLE_LEN,Reg#(Bit#(MATCH_TABLE_ASSOCIATIVITY)))
                        nextFree <- replicateM(mkReg(255));
    Reg#(Bit#(MATCH_TABLE_ASSOCIATIVITY)) temp <- mkReg(0);

    function Bit#(3) priority_encoder(Reg#(Bit#(8)) inp);
        case (inp) matches
            8'b10000000 : return 7;
            8'b?1000000 : return 6;
            8'b??100000 : return 5;
            8'b???10000 : return 4;
            8'b????1000 : return 3;
            8'b?????100 : return 2;
            8'b??????10 : return 1;
            8'b???????1 : return 0;
        endcase
    endfunction

    function Bit#(8) flip_bit_at_pos(Bit#(3) pos, AddrIndex addrIdx);
        case (pos)
            0 : return (nextFree[addrIdx] ^ 8'b00000001);
            1 : return (nextFree[addrIdx] ^ 8'b00000010);
            2 : return (nextFree[addrIdx] ^ 8'b00000100);
            3 : return (nextFree[addrIdx] ^ 8'b00001000);
            4 : return (nextFree[addrIdx] ^ 8'b00010000);
            5 : return (nextFree[addrIdx] ^ 8'b00100000);
            6 : return (nextFree[addrIdx] ^ 8'b01000000);
            7 : return (nextFree[addrIdx] ^ 8'b10000000);
        endcase
    endfunction

    FIFOF#(RequestType) requestFIFO <- mkBypassFIFOF;
    FIFOF#(ResponseType) responseFIFO <- mkBypassFIFOF;

    Vector#(3, Reg#(RequestType)) currReq <- replicateM(mkReg(defaultValue));

    for (Integer i = 0; i < fromInteger(valueof(MATCH_TABLE_ASSOCIATIVITY)); i = i + 1)
    begin
        rule response_from_hTable;
            ResponseType res <- hTable[i].response.get; 
            if (res.tag == VALID && res.op == GET)    
                responseFIFO.enq(res);
            else if (res.tag == VALID && res.op == REMOVE)
                nextFree[res.addrIdx] <= flip_bit_at_pos(fromInteger(i), res.addrIdx);
        endrule
    end

    rule start;
        let currReq <- toGet(requestFIFO).get;
        AddrIndex addrIdx = hash_function(currReq.key);
        currReq.addrIdx = addrIdx;
        case (currReq.op)
            PUT : begin
                    if (nextFree[addrIdx] != 0)
                    begin
                        Bit#(3) index = priority_encoder(nextFree[addrIdx]);
                        nextFree[addrIdx] <= flip_bit_at_pos(index, addrIdx);
                        hTable[index].request.put(currReq);
                    end
                    else
                        $display("PUT Failed : No empty slot");
                  end
            default : begin
                        for (Integer i = 0; i < fromInteger(valueof(MATCH_TABLE_ASSOCIATIVITY)); i = i + 1)
                            hTable[i].request.put(currReq);
                      end
         endcase             
    endrule

    interface Put request = toPut(requestFIFO);
    interface Get response = toGet(responseFIFO);
endmodule
