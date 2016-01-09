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
import MatchTable::*;
import MatchTableTypes::*;
import MemTypes::*;
import MemServerIndication::*;
import MMUIndication::*;

typedef 12 PktSize; // maximum 4096b
typedef TDiv#(`DataBusWidth, 32) WordsPerBeat;

typedef struct {
   Bit#(9) key1;
   Bit#(9) key2;
} MatchInput deriving (Bits, Eq, FShow);

typedef struct {
   Bit#(1) op;
} ActionInput deriving (Bits, Eq, FShow);

interface MatchTestIndication;
   method Action read_version_resp(Bit#(32) version);
   method Action add_entry_resp(FlowId id);
endinterface

interface MatchTestRequest;
   method Action read_version();
   method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
   method Action add_entry(Bit#(32) table_name, MatchInput match_key);
   method Action set_default_action(Bit#(32) table_name);
   method Action delete_entry(Bit#(32) table_name, FlowId flow_id);
   method Action modify_entry(Bit#(32) table_name, FlowId flow_id, ActionSpec_t actions);
endinterface

interface MatchTest;
   interface MatchTestRequest request;
endinterface
module mkMatchTest#(MatchTestIndication indication, ConnectalMemory::MemServerIndication memServerIndication)(MatchTest);

   let verbose = True;
   // read client interface
   FIFO#(MemRequest) readReqFifo <-mkSizedFIFO(4);
   FIFO#(MemData#(`DataBusWidth)) readDataFifo <- mkSizedFIFO(32);
   MemReadClient#(`DataBusWidth) dmaReadClient = (interface MemReadClient;
   interface Get readReq = toGet(readReqFifo);
   interface Put readData = toPut(readDataFifo);
   endinterface);

   // write client interface
   FIFO#(MemRequest) writeReqFifo <- mkSizedFIFO(4);
   FIFO#(MemData#(`DataBusWidth)) writeDataFifo <- mkSizedFIFO(32);
   FIFO#(Bit#(MemTagSize)) writeDoneFifo <- mkSizedFIFO(4);
   MemWriteClient#(`DataBusWidth) dmaWriteClient = (interface MemWriteClient;
   interface Get writeReq = toGet(writeReqFifo);
   interface Get writeData = toGet(writeDataFifo);
   interface Put writeDone = toPut(writeDoneFifo);
   endinterface);

   PacketBuffer rxPktBuff <- mkPacketBuffer();
   MatchTable match_table <- mkMatchTable();

   rule read_flow_id;
      let v <- toGet(match_table.entry_added).get;
      indication.add_entry_resp(v);
   endrule

   interface MatchTestRequest request;
      method Action read_version();
         let v= `NicVersion;
         $display("read version");
         indication.read_version_resp(v);
      endmethod
      method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
         EtherData beat = defaultValue;
         beat.data = pack(reverse(data));
         beat.mask = pack(reverse(mask));
         beat.sop = unpack(sop);
         beat.eop = unpack(eop);
         rxPktBuff.writeServer.writeData.put(beat);
      endmethod
      method Action add_entry(Bit#(32) table_name, MatchInput match_key);
         // write entries to table
         $display("added entry ", fshow(match_key));
         ActionSpec_t as = ActionSpec_t{ op : 4 };
         MatchSpec_t ms = MatchSpec_t{ data: match_key.key1, param: as };
         match_table.add_entry.put(ms);
      endmethod

      method Action set_default_action(Bit#(32) table_name);
         // write default action to action engine
      endmethod

      method Action delete_entry(Bit#(32) table_name, FlowId id);
         // invalidate entries in table
         $display("delete entry flow id ", fshow(id));
         match_table.delete_entry.put(id);
      endmethod

      method Action modify_entry(Bit#(32) table_name, FlowId id, ActionSpec_t actions);
         // enqueue match key
         $display("modify entry flow id ", fshow(id), " action ", fshow(actions));
         match_table.modify_entry.put(tuple2(id, actions));
      endmethod
   endinterface
endmodule: mkMatchTest
endpackage: MatchTest
