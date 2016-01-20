import FIFO::*;
import FIFOF::*;
import GetPut::*;
import ClientServer::*;
import StmtFSM::*;
import Vector::*;
import DefaultValue::*;
import BRAM::*;
import FShow::*;
import Pipe::*;

import MatchTableTypes::*;
import Bcam::*;
import BcamTypes::*;

typedef 9 KeyLen;
typedef 10 ValueLen;
typedef 10 AddrIdx;

typedef Bit#(16) FlowId;

interface MatchTable;
   interface Server#(Bit#(KeyLen), ActionSpec_t) lookupPort;
   interface Server#(Bit#(10), Bit#(9)) readPort;
   interface PipeOut#(FlowId) entry_added;
   interface Put#(MatchSpec_t) add_entry;
   interface Put#(FlowId) delete_entry;
   interface Put#(Tuple2#(FlowId, ActionSpec_t)) modify_entry;
endinterface

module mkMatchTable(MatchTable);
   let verbose = True;
   Reg#(Bit#(32)) cycle <- mkReg(0);

   rule every1 (verbose);
      cycle <= cycle + 1;
   endrule

   FIFOF#(FlowId) entry_added_fifo <- mkSizedFIFOF(1);
   BinaryCam#(1024, 9) bcam <- mkBinaryCam;

   BRAM_Configure cfg = defaultValue;
   cfg.latency = 2;
   BRAM2Port#(Bit#(10), ActionSpec_t) ram <- mkBRAM2Server(cfg);

   Reg#(Bit#(AddrIdx)) addrIdx <- mkReg(0);

   rule handle_bcam_response;
      let v <- bcam.readServer.response.get;
      if (verbose) $display("matchTable %d: recv bcam response ", cycle, fshow(v));
      if (isValid(v)) begin
         let address = fromMaybe(?, v);
         ram.portA.request.put(BRAMRequest{write:False, responseOnWrite: False, address: address, datain:?});
      end
   endrule

   // Interface for lookup from data-plane modules
   interface Server lookupPort;
      interface Put request;
         method Action put (Bit#(KeyLen) v);
            BcamReadReq#(KeyLen) req_bcam = BcamReadReq{data: v};
            bcam.readServer.request.put(pack(req_bcam));
            if (verbose) $display("matchTable %d: lookup ", cycle, fshow(req_bcam));
         endmethod
      endinterface
      interface Get response;
         method ActionValue#(ActionSpec_t) get();
            let v <- ram.portA.response.get;
            if (verbose) $display("matchTable %d: recv ram response ", cycle, fshow(v));
            return v;
         endmethod
      endinterface
   endinterface

   // Interface for read from control-plane
   interface Server readPort;
      interface Put request;
         method Action put (Bit#(10) addr);

         endmethod
      endinterface
      interface Get response;
         method ActionValue#(Bit#(9)) get();
            return 0;
         endmethod
      endinterface
   endinterface

   // Interface for write from control-plane
   interface Put add_entry;
      method Action put (MatchSpec_t m);
         BcamWriteReq#(10, KeyLen) req_bcam = BcamWriteReq{addr: addrIdx, data: m.data};
         BRAMRequest#(Bit#(10), ActionSpec_t) req_ram = BRAMRequest{write: True, responseOnWrite: False, address: addrIdx, datain: m.param};
         bcam.writeServer.put(req_bcam);
         ram.portA.request.put(req_ram);
         $display("match_table %d: add flow %x", cycle, addrIdx);
         addrIdx <= addrIdx + 1; //FIXME: currently no reuse of address.
         entry_added_fifo.enq(extend(addrIdx));
      endmethod
   endinterface
   interface PipeOut entry_added = toPipeOut(entry_added_fifo);
   interface Put delete_entry;
      method Action put (FlowId id);
         BcamWriteReq#(10, KeyLen) req_bcam = BcamWriteReq{addr: truncate(id), data: 0};
         BRAMRequest#(Bit#(10), ActionSpec_t) req_ram = BRAMRequest{write: True, responseOnWrite: False, address: truncate(id), datain: ActionSpec_t{op:0}};
         bcam.writeServer.put(req_bcam);
         ram.portA.request.put(req_ram);
         $display("match_table %d: delete flow %x", cycle, id);
      endmethod
   endinterface
   interface Put modify_entry;
      method Action put (Tuple2#(FlowId, ActionSpec_t) v);
         match { .flowid, .act} = v;
         $display("match_table %d: modify flow %x with action %x", cycle, flowid, act);
         BRAMRequest#(Bit#(10), ActionSpec_t) req_ram = BRAMRequest{write: True, responseOnWrite: False, address: truncate(flowid), datain: ActionSpec_t{ op : act.op } };
         ram.portA.request.put(req_ram);
      endmethod
   endinterface
endmodule
