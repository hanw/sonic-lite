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
import PriorityEncoder::*;
import TopTypes::*;
import DbgTypes::*;

// depthSz is multiple of 8 for 256 entries
// keySz is multiple of 9 for 9 bits
interface MatchTable#(numeric type depth, numeric type keySz);
   interface Server#(MatchField, ActionArg) lookupPort;
   interface Server#(Bit#(TLog#(depth)), Bit#(keySz)) readPort;
   interface PipeOut#(FlowId) entry_added;
   interface Put#(TableEntry) add_entry;
   interface Put#(FlowId) delete_entry;
   interface Put#(Tuple2#(FlowId, ActionArg)) modify_entry;
   method MatchTableDbgRec dbg;
endinterface

module mkMatchTable(MatchTable#(depth, keySz))
   provisos(PriorityEncoder::PEncoder#(depthSz)
           ,Log#(depth, depthSz)
           ,Add#(a__, depthSz, 16)
           ,Add#(b__, 32, keySz)
           ,Add#(c__, 7, depthSz)
           ,Mul#(c__, 256, d__)
           ,Log#(d__, depthSz)
           ,Mul#(e__, 9, keySz)
           ,Add#(TAdd#(TLog#(c__), 4), 2, TLog#(TDiv#(depth, 4)))
           ,Log#(TDiv#(depth, 16), TAdd#(TLog#(c__), 4))
           ,Add#(9, f__, keySz)
           ,Add#(2, g__, depthSz)
           ,Add#(4, h__, depthSz)
           ,Add#(j__, TLog#(depth), 16)
           ,PriorityEncoder::PEncoder#(depth)
           ,PriorityEncoder::PEncoder#(d__)
           ,Add#(k__, TLog#(depth), 64)
           ,Add#(TAdd#(TLog#(c__), 4), i__, depthSz));
   let verbose = False;
   Reg#(Bit#(32)) cycle <- mkReg(0);

   Reg#(Bit#(64)) matchResponseCount <- mkReg(0);
   Reg#(Bit#(64)) matchRequestCount <- mkReg(0);
   Reg#(Bit#(64)) matchValidCount <- mkReg(0);
   Reg#(Bit#(64)) lastMatchIdx <- mkReg(0);
   Reg#(Bit#(64)) lastMatchRequest <- mkReg(0);

   rule every1 if (verbose);
      cycle <= cycle + 1;
   endrule

   FIFO#(Bit#(depthSz)) addrFifo <- mkFIFO;
   FIFOF#(TableEntry) writeReqFifo <- mkFIFOF;
   FIFOF#(FlowId) entryAddDoneFifo <- mkFIFOF;
   BinaryCam#(depth, keySz) bcam <- mkBinaryCam();

   BRAM_Configure cfg = defaultValue;
   cfg.latency = 2;
   BRAM2Port#(Bit#(depthSz), ActionArg) ram <- mkBRAM2Server(cfg);

   Reg#(Bit#(depth)) freeTableEntry <- mkReg(maxBound);
   PE#(depth) idxPe <- mkPEncoder();

   rule handle_bcam_response;
      let v <- bcam.readServer.response.get;
      if (verbose) $display("GenericMatchTable:: %d: bcam response ", cycle, fshow(v));
      if (isValid(v)) begin
         let address = fromMaybe(?, v);
         ram.portA.request.put(BRAMRequest{write:False, responseOnWrite: False, address: address, datain:?});
         matchValidCount <= matchValidCount + 1;
         lastMatchIdx <= extend(address);
      end
      matchResponseCount <= matchResponseCount + 1;
   endrule

   // clear bit at location n in a vector
   function Bit#(depth) clearbit(Bit#(depth) vec, Bit#(TLog#(depth)) n);
      return vec & ~(1 << n);
   endfunction

   function Bit#(depth) setbit(Bit#(depth) vec, Bit#(TLog#(depth)) n);
      return vec | (1 << n);
   endfunction

   rule compute_next_address;
      let idx <- idxPe.bin.get;
      Bit#(TLog#(depth)) entry = isValid(idx) ? fromMaybe(?, idx) : 0;
      Bit#(TLog#(depth)) nextAddr = isValid(idx) ? entry : 1;
      freeTableEntry <= clearbit(freeTableEntry, entry);
      addrFifo.enq(nextAddr);
      $display("GenericMatchTable:: indx=", fshow(idx));
      $display("GenericMatchTable:: nextAddr=%h", nextAddr);
   endrule

   rule handle_bcam_write_request;
      let req <- toGet(writeReqFifo).get;
      let addrIdx <- toGet(addrFifo).get;
      BcamWriteReq#(depthSz, keySz) req_bcam = BcamWriteReq{addr: addrIdx, data: extend(req.field.dstip)};
      let actionArg = ActionArg{egress_index: req.argument.egress_index};
      BRAMRequest#(Bit#(depthSz), ActionArg) req_ram = BRAMRequest{write: True, responseOnWrite: False, address: addrIdx, datain: actionArg};
      bcam.writeServer.put(req_bcam);
      ram.portA.request.put(req_ram);
      $display("GenericMatchTable:: %d: add flow %x", cycle, addrIdx);
      entryAddDoneFifo.enq(extend(addrIdx));
   endrule

   // Interface for lookup from data-plane modules
   interface Server lookupPort;
      interface Put request;
         method Action put (MatchField field);
            BcamReadReq#(keySz) req_bcam = BcamReadReq{data: extend(field.dstip)};
            bcam.readServer.request.put(pack(req_bcam));
            matchRequestCount <= matchRequestCount + 1;
            if (verbose) $display("GenericMatchTable:: %d: bcam lookup ", cycle, fshow(req_bcam));
            lastMatchRequest <= extend(field.dstip);
         endmethod
      endinterface
      interface Get response;
         method ActionValue#(ActionArg) get();
            let v <- ram.portA.response.get;
            if (verbose) $display("GenericMatchTable:: %d: bcam response ", cycle, fshow(v));
            return v;
         endmethod
      endinterface
   endinterface

   // Interface for read from control-plane
   interface Server readPort;
      interface Put request;
         method Action put (Bit#(depthSz) addr);
            if (freeTableEntry[addr] != 0) begin
            end
         endmethod
      endinterface
      interface Get response;
         method ActionValue#(Bit#(keySz)) get();
            return 0;
         endmethod
      endinterface
   endinterface

   // Interface for write from control-plane
   interface Put add_entry;
      method Action put (TableEntry entry);
         idxPe.oht.put(freeTableEntry);
         writeReqFifo.enq(entry);
      endmethod
   endinterface
   interface PipeOut entry_added = toPipeOut(entryAddDoneFifo);
   interface Put delete_entry;
      method Action put (FlowId id);
         BcamWriteReq#(depthSz, keySz) req_bcam = BcamWriteReq{addr: truncate(id), data: 0};
         BRAMRequest#(Bit#(depthSz), ActionArg) req_ram = BRAMRequest{write: True, responseOnWrite: False, address: truncate(id), datain: ActionArg{egress_index: 0}};
         bcam.writeServer.put(req_bcam);
         ram.portA.request.put(req_ram);
         freeTableEntry <= setbit(freeTableEntry, truncate(id));
         $display("GenericMatchTable:: %d: delete flow %x", cycle, id);
      endmethod
   endinterface
   interface Put modify_entry;
      method Action put (Tuple2#(FlowId, ActionArg) v);
         match { .flowid, .argument} = v;
         $display("GenericMatchTable:: %d: modify flow %x with action %x", cycle, flowid, argument);
         let actionArg = ActionArg{egress_index: argument.egress_index};
         BRAMRequest#(Bit#(depthSz), ActionArg) req_ram = BRAMRequest{write: True, responseOnWrite: False, address: truncate(flowid), datain: actionArg};
         ram.portA.request.put(req_ram);
      endmethod
   endinterface
   method MatchTableDbgRec dbg();
      return MatchTableDbgRec {matchRequestCount: matchRequestCount
                              ,matchResponseCount: matchResponseCount
                              ,matchValidCount: matchValidCount
                              ,lastMatchIdx: lastMatchIdx
                              ,lastMatchRequest: lastMatchRequest};
   endmethod
endmodule
