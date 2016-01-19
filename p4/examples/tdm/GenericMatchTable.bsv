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

import Bcam::*;
import BcamTypes::*;

typedef 36 KeyLen;
typedef 10 AddrIdx;

typedef Bit#(16) FlowId;

typedef struct {
   Bit#(4) egress_index;
} ActionArg deriving (Bits, Eq, FShow);

typedef struct {
   Bit#(32) dstip;
} MatchField deriving (Bits, Eq, FShow);

typedef struct {
   MatchField field;
   ActionArg argument;
} TableEntry deriving (Bits, Eq, FShow);

typedef enum {
   MODIFY_MAC = 1
} OpCode deriving (Bits, Eq, FShow);

typedef struct {
   OpCode opcode;
} ActionOp deriving (Bits, Eq, FShow);

interface MatchTable;
   interface Server#(MatchField, ActionArg) lookupPort;
   interface Server#(Bit#(AddrIdx), Bit#(KeyLen)) readPort; //FIXME
   interface PipeOut#(FlowId) entry_added;
   interface Put#(TableEntry) add_entry;
   interface Put#(FlowId) delete_entry;
   interface Put#(Tuple2#(FlowId, ActionArg)) modify_entry;
endinterface

module mkMatchTable(MatchTable);
   let verbose = True;
   Reg#(Bit#(32)) cycle <- mkReg(0);

   rule every1 if (verbose);
      cycle <= cycle + 1;
   endrule

   FIFOF#(FlowId) entry_added_fifo <- mkSizedFIFOF(1);
   BinaryCam#(1024, KeyLen) bcam <- mkBinaryCam; //FIXME

   BRAM_Configure cfg = defaultValue;
   cfg.latency = 2;
   BRAM2Port#(Bit#(AddrIdx), ActionArg) ram <- mkBRAM2Server(cfg);

   Reg#(Bit#(AddrIdx)) addrIdx <- mkReg(0); //FIXME

   rule handle_bcam_response;
      let v <- bcam.readServer.response.get;
      if (verbose) $display("GenericMatchTable:: %d: recv bcam response ", cycle, fshow(v));
      if (isValid(v)) begin
         let address = fromMaybe(?, v);
         ram.portA.request.put(BRAMRequest{write:False, responseOnWrite: False, address: address, datain:?});
      end
   endrule

   // Interface for lookup from data-plane modules
   interface Server lookupPort;
      interface Put request;
         method Action put (MatchField field);
            BcamReadReq#(KeyLen) req_bcam = BcamReadReq{data: extend(field.dstip)};
            bcam.readServer.request.put(pack(req_bcam));
            if (verbose) $display("GenericMatchTable:: %d: lookup ", cycle, fshow(req_bcam));
         endmethod
      endinterface
      interface Get response;
         method ActionValue#(ActionArg) get();
            let v <- ram.portA.response.get;
            if (verbose) $display("GenericMatchTable:: %d: recv ram response ", cycle, fshow(v));
            return v;
         endmethod
      endinterface
   endinterface

   // Interface for read from control-plane
   interface Server readPort;
      interface Put request;
         method Action put (Bit#(AddrIdx) addr);

         endmethod
      endinterface
      interface Get response;
         method ActionValue#(Bit#(KeyLen)) get();
            return 0;
         endmethod
      endinterface
   endinterface

   // Interface for write from control-plane
   interface Put add_entry;
      method Action put (TableEntry entry);
         BcamWriteReq#(AddrIdx, KeyLen) req_bcam = BcamWriteReq{addr: addrIdx, data: extend(entry.field.dstip)};
         let actionArg = ActionArg{egress_index: entry.argument.egress_index};
         BRAMRequest#(Bit#(AddrIdx), ActionArg) req_ram = BRAMRequest{write: True, responseOnWrite: False, address: addrIdx, datain: actionArg};
         bcam.writeServer.put(req_bcam);
         ram.portA.request.put(req_ram);
         $display("GenericMatchTable:: %d: add flow %x", cycle, addrIdx);
         addrIdx <= addrIdx + 1; //FIXME: currently no reuse of address.
         entry_added_fifo.enq(extend(addrIdx));
      endmethod
   endinterface
   interface PipeOut entry_added = toPipeOut(entry_added_fifo);
   interface Put delete_entry;
      method Action put (FlowId id);
         BcamWriteReq#(AddrIdx, KeyLen) req_bcam = BcamWriteReq{addr: truncate(id), data: 0};
         BRAMRequest#(Bit#(AddrIdx), ActionArg) req_ram = BRAMRequest{write: True, responseOnWrite: False, address: truncate(id), datain: ActionArg{egress_index: 0}};
         bcam.writeServer.put(req_bcam);
         ram.portA.request.put(req_ram);
         $display("GenericMatchTable:: %d: delete flow %x", cycle, id);
      endmethod
   endinterface
   interface Put modify_entry;
      method Action put (Tuple2#(FlowId, ActionArg) v);
         match { .flowid, .argument} = v;
         $display("GenericMatchTable:: %d: modify flow %x with action %x", cycle, flowid, argument);
         let actionArg = ActionArg{egress_index: argument.egress_index};
         BRAMRequest#(Bit#(AddrIdx), ActionArg) req_ram = BRAMRequest{write: True, responseOnWrite: False, address: truncate(flowid), datain: actionArg};
         ram.portA.request.put(req_ram);
      endmethod
   endinterface
endmodule
