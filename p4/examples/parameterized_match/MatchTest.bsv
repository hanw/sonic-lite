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
import TdmTypes::*; // FIXME
import DbgTypes::*;
import MMUIndication::*;
import MatchTable::*;

typedef 12 PktSize; // maximum 4096b
typedef 256 DepthSz;
typedef 36  KeySz;
typedef TDiv#(`DataBusWidth, 32) WordsPerBeat;

interface MatchTestIndication;
   method Action read_version_resp(Bit#(32) version);
   method Action add_entry_resp(FlowId id);
   method Action match_table_resp(Bit#(32) addr);
   method Action readMatchTableCntrsResp(Bit#(64) matchRequestCount, Bit#(64) matchResponseCount, Bit#(64) matchValidCount, Bit#(64) lastMatchIdx, Bit#(64) lastMatchRequest);
endinterface

interface MatchTestRequest;
   method Action read_version();
   method Action add_entry(Bit#(32) table_name, MatchFieldSourceMac key);
   method Action delete_entry(Bit#(32) table_name, Bit#(16) flow_id);
   method Action modify_entry(Bit#(32) table_name, Bit#(16) flow_id, ActionSourceMac arg);
   method Action lookup_entry(MatchFieldSourceMac field);
   method Action readMatchTableCntrs();
endinterface

interface MatchTest;
   interface MatchTestRequest request;
endinterface
module mkMatchTest#(MatchTestIndication indication)(MatchTest);

   let verbose = True;

   MatchTable#(DepthSz, MatchFieldSourceMac, ActionSourceMac) match_table <- mkMatchTable();

//   rule read_flow_id;
//      let v <- toGet(match_table.entry_added).get;
//      indication.add_entry_resp(v);
//   endrule

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
      method Action add_entry(Bit#(32) name, MatchFieldSourceMac fields);
         //ActionSourceMac args = ActionSourceMac {egress_index : truncate(name)};
         //TableEntry entry = TableEntry {field: fields, argument: 0};
         match_table.add_entry.put(fields);
      endmethod
      method Action delete_entry(Bit#(32) name, Bit#(16) id);
         $display("delete entry flow id ", fshow(id));
         match_table.delete_entry.put(truncate(id));
      endmethod
      method Action modify_entry(Bit#(32) name, Bit#(16) id, ActionSourceMac args);
         //$display("modify entry flow id ", fshow(id), " action ", fshow(args));
         match_table.modify_entry.put(tuple2(truncate(id), args));
      endmethod
      method Action lookup_entry(MatchFieldSourceMac field);
         match_table.lookupPort.request.put(field);
      endmethod
//      method Action readMatchTableCntrs();
//         let v = match_table.dbg();
//         indication.readMatchTableCntrsResp(v.matchRequestCount, v.matchResponseCount, v.matchValidCount, v.lastMatchIdx, v.lastMatchRequest);
//      endmethod
   endinterface
endmodule: mkMatchTest
endpackage: MatchTest
