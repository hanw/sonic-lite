package MatchTest;

import BuildVector::*;
import DefaultValue::*;
import GetPut::*;
import ClientServer::*;
import StmtFSM::*;
import FIFO::*;
import Pipe::*;
import Vector::*;
import ConnectalMemory::*;

import Ethernet::*;
import PacketBuffer::*;
import MemTypes::*;
import MMUIndication::*;
import MatchTable::*;
import DbgTypes::*;

typedef 12 PktSize; // maximum 4096b
typedef 256 DepthSz;
typedef 36  KeySz;
typedef Bit#(16) ActionArg;
typedef TDiv#(`DataBusWidth, 32) WordsPerBeat;

typedef struct {
   Bit#(32) dstip;
   Bit#(4) padding;
} MatchField deriving(Bits, Eq, FShow);

interface MatchTestIndication;
   method Action read_version_resp(Bit#(32) version);
   method Action add_entry_resp(Bit#(8) id);
   method Action match_table_resp(Bit#(32) addr);
   method Action readMatchTableCntrsResp(Bit#(64) matchRequestCount, Bit#(64) matchResponseCount, Bit#(64) matchValidCount, Bit#(64) lastMatchIdx, Bit#(64) lastMatchRequest);
endinterface

interface MatchTestRequest;
   method Action read_version();
   method Action add_entry(Bit#(32) table_name, MatchField key);
   method Action delete_entry(Bit#(32) table_name, Bit#(8) flow_id);
   method Action modify_entry(Bit#(32) table_name, Bit#(8) flow_id, ActionArg arg);
   method Action lookup_entry(MatchField field);
   method Action readMatchTableCntrs();
endinterface

interface MatchTest;
   interface MatchTestRequest request;
endinterface
module mkMatchTest#(MatchTestIndication indication)(MatchTest);

   let verbose = True;

   MatchTable#(DepthSz, MatchField, ActionArg) match_table <- mkMatchTable();

   //rule read_flow_id;
   //   let v <- toGet(match_table.entry_added).get;
   //   indication.add_entry_resp(v);
   //endrule

   // packet processing pipeline: ingress
   rule tableLookupResp;
      let v <- match_table.lookupPort.response.get;
      $display("TDM:: bcam matches %h", v);
      indication.match_table_resp(extend(pack(v)));
   endrule

   interface MatchTestRequest request;
      method Action read_version();
         let v= `NicVersion;
         $display("read version");
         indication.read_version_resp(v);
      endmethod
      method Action add_entry(Bit#(32) name, MatchField fields);
         ActionArg args = 0;
         //TableEntry entry = TableEntry {field: fields, argument: args};
         $display("add entry ", fshow(fields));
         match_table.add_entry.put(tuple2(fields, args));
      endmethod
      method Action delete_entry(Bit#(32) name, Bit#(8) id);
         $display("delete entry flow id ", fshow(id));
         match_table.delete_entry.put(id);
      endmethod
      method Action modify_entry(Bit#(32) name, Bit#(8) id, ActionArg args);
         $display("modify entry flow id ", fshow(id), " action ", fshow(args));
         match_table.modify_entry.put(tuple2(id, args));
      endmethod
      method Action lookup_entry(MatchField field);
         match_table.lookupPort.request.put(field);
      endmethod
      //method Action readMatchTableCntrs();
      //   let v = match_table.dbg();
      //   indication.readMatchTableCntrsResp(v.matchRequestCount, v.matchResponseCount, v.matchValidCount, v.lastMatchIdx, v.lastMatchRequest);
      //endmethod
   endinterface
endmodule: mkMatchTest
endpackage: MatchTest
