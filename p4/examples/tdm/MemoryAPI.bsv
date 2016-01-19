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

import BuildVector::*;
import ClientServer::*;
import Connectable::*;
import DefaultValue::*;
import GetPut::*;
import Vector::*;

import Ethernet::*;
import PacketBuffer::*;
import PktGen::*;
import SharedBuff::*;
import GenericMatchTable::*;

interface MemoryTestIndication;
   method Action read_version_resp(Bit#(32) version);
   method Action addEntryResp(FlowId id);
endinterface

interface MemoryTestRequest;
   method Action read_version();
   method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
   method Action free(Bit#(32) id);
   method Action start(Bit#(32) iter, Bit#(32) ipg);
   method Action stop();
   method Action clear();
   method Action addEntry(Bit#(32) name, MatchField fields);
   method Action deleteEntry(Bit#(32) name, FlowId flow_id);
   method Action modifyEntry(Bit#(32) name, FlowId flow_id, ActionArg actions);
endinterface

interface MemoryAPI;
   interface MemoryTestRequest request;
endinterface

module mkMemoryAPI#(MemoryTestIndication indication, PktGen pktgen, SharedBuffer#(12, 128, 1) mem, MatchTable match_table)(MemoryAPI);
   interface MemoryTestRequest request;
      method Action read_version();
         let v= `NicVersion;
         indication.read_version_resp(v);
      endmethod
      method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
         EtherData beat = defaultValue;
         beat.data = pack(reverse(data));
         beat.mask = pack(reverse(mask));
         beat.sop = unpack(sop);
         beat.eop = unpack(eop);
         pktgen.writeServer.writeData.put(beat);
      endmethod
      method Action free(Bit#(32) id);
         mem.freeReq.put(id);
      endmethod
      method start = pktgen.start;
      method stop = pktgen.stop;
      method clear = pktgen.clear;
      method Action addEntry(Bit#(32) table_name, MatchField fields);
         $display("MemoryAPI:: added entry ", fshow(fields));
         ActionArg args = ActionArg{egress_index: 4};
         TableEntry entry = TableEntry{field: fields, argument: args };
         match_table.add_entry.put(entry);
      endmethod

      method Action deleteEntry(Bit#(32) table_name, FlowId id);
         $display("MemoryAPI:: delete entry flow id ", fshow(id));
         match_table.delete_entry.put(id);
      endmethod

      method Action modifyEntry(Bit#(32) table_name, FlowId id, ActionArg args);
         $display("MemoryAPI:: modify entry flow id ", fshow(id), " action ", fshow(args));
         match_table.modify_entry.put(tuple2(id, args));
      endmethod

   endinterface
endmodule
