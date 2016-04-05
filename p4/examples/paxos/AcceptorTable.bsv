// Copyright (c) 2016 Cornell University.

// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import ClientServer::*;
import DbgTypes::*;
import Ethernet::*;
import FIFO::*;
import GetPut::*;
import PaxosTypes::*;
import MatchTable::*;
import RegFile::*;

interface BasicBlockHandle1A;

endinterface

module mkBasicBlockHandle1A#(MetadataClient md)(BasicBlockHandle1A);

endmodule

interface BasicBlockHandle2A;

endinterface

module mkBasicBlockHandle2A#(MetadataClient md)(BasicBlockHandle2A);

endmodule

interface BasicBlockDrop;

endinterface

module mkBasicBlockDrop#(MetadataClient md)(BasicBlockDrop);

endmodule

interface AcceptorTable;
   interface Client#(MetadataRequest, MetadataResponse) next;
   //interface Client#(RoundRegRequest, RoundRegResponse) regAccess;
endinterface

module mkAcceptorTable#(Client#(MetadataRequest, MetadataResponse) md)(AcceptorTable);
   let verbose = True;
   MatchTable#(256, MatchFieldAcceptorTbl, ActionArgsAcceptorTbl) matchTable <- mkMatchTable_256_acceptorTable();

   FIFO#(MetadataRequest) outReqFifo <- mkFIFO;
   FIFO#(MetadataResponse) inRespFifo <- mkFIFO;
   FIFO#(PacketInstance) currPacketFifo <- mkFIFO;

   rule tableLookupRequest;
      let v <- md.request.get;
      case (v) matches
         tagged AcceptorTblRequest {pkt: .pkt} : begin
            //matchTable.lookupPort.request.put(MatchFieldAcceptorTbl { key_field_0: v.key_field_0 });
            //currPacketFifo.enq(pkt);
            if (verbose) $display("Acceptor: %h", pkt.id);
            MetadataRequest nextReq = tagged ForwardQueueRequest {pkt: pkt};
            outReqFifo.enq(nextReq);
         end
      endcase
   endrule

   rule tableLookupResponse;
      let v <- matchTable.lookupPort.response.get;
   endrule

   interface next = (interface Client#(MetadataRequest, MetadataResponse);
      interface request = toGet(outReqFifo);
      interface response = toPut(inRespFifo);
   endinterface);
endmodule
