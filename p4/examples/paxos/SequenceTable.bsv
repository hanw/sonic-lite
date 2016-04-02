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
import RegFile::*;
import MatchTable::*;

// P4 Table size
typedef 8 TableSize;

// Generic p4 fields to match against tables
typedef union tagged {
   struct {

   } NoneField;

   struct {
      Bit#(16) msgtype;
   } MsgtypeField;
} MatchFields deriving(Bits, Eq, FShow);

typedef Bit#(32) ActionArg;

interface SequenceTable;
   interface Client#(MetadataRequest, MetadataResponse) next;
endinterface

module mkSequenceTable#(Client#(MetadataRequest, MetadataResponse) md)(SequenceTable);
   let verbose = True;

   FIFO#(MetadataRequest) outReqFifo <- mkFIFO;
   FIFO#(MetadataResponse) inRespFifo <- mkFIFO;
   FIFO#(PacketInstance) currPacketFifo <- mkFIFO;
   // Current instance register is a global counter than increases every time
   // the Coordinator receives a Paxos 2A message
   // INIT to 0
   Reg#(int) current_instance = mkReg (0);

   MatchTable#(TableSize, MatchFields, ActionArg) matchTable <- mkMatchTable();

   rule tableLookupRequest;
      let v <- md.request.get;
      case (v) matches
         tagged SequenceTblRequest { pkt: .pkt } : begin
            matchTable.lookupPort.request.put(NoneField);
         end
      endcase
   endrule

   rule tableLookupResponse;
      let resp <- fromMaybe(?, matchTable.lookupPort.response.get);
      // inRespFifo.enq(resp);
   endrule

   interface next = (interface Client#(MetadataRequest, MetadataResponse);
      interface request = toGet(outReqFifo);
      interface response = toPut(inRespFifo);
   endinterface);

   method ActionValue#(int) increaseSequence();
      // TODO: Replace the value of inst field of Paxos message with the current_instance
      // paxos.inst <= current_instance

      // increase the counter
      current_instance <= current_instance + 1;
      return current_instance;
   endmethod

endmodule
