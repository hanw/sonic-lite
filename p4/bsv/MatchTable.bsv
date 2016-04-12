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

interface MatchTable#(numeric type depth, type keys, type actions);
   interface Server#(keys, Maybe#(actions)) lookupPort;
   interface Put#(Tuple2#(keys, actions)) add_entry;
   interface Put#(Bit#(TLog#(depth))) delete_entry;
   interface Put#(Tuple2#(Bit#(TLog#(depth)), actions)) modify_entry;
endinterface

module mkMatchTable(MatchTable#(depth, keys, actions))
   provisos(Bits#(keys, a__),
            Bits#(actions, b__),
            Mul#(c__, 256, d__),
            Add#(c__, 7, TLog#(depth)),
            Log#(d__, TLog#(depth)),
            Mul#(e__, 9, a__),
            Add#(TAdd#(TLog#(c__), 4), 2, TLog#(TDiv#(depth, 4))),
            Log#(TDiv#(depth, 16), TAdd#(TLog#(c__), 4)),
            Add#(9, f__, a__),
            PriorityEncoder::PEncoder#(d__),
            Add#(2, g__, TLog#(depth)),
            Add#(4, h__, TLog#(depth)),
            Add#(TAdd#(TLog#(c__), 4), i__, TLog#(depth)));

   MatchTable#(depth, keys, actions) ret_ifc;
`ifdef SIMULATION
   ret_ifc <- mkMatchTableBluesim();
`else
   ret_ifc <- mkMatchTableSynth();
`endif
   return ret_ifc;
endmodule

module mkMatchTableSynth(MatchTable#(depth, keys, actions))
   provisos (Bits#(keys, keySz),
             Bits#(actions, actionSz),
             NumAlias#(depthSz, TLog#(depth)),
             Mul#(a__, 256, b__),
             Add#(a__, 7, depthSz),
             Log#(b__, depthSz),
             Mul#(c__, 9, keySz),
             Add#(TAdd#(TLog#(a__), 4), 2, TLog#(TDiv#(depth, 4))),
             Log#(TDiv#(depth, 16), TAdd#(TLog#(a__), 4)),
             Add#(9, d__, keySz),
             PriorityEncoder::PEncoder#(b__),
             Add#(2, e__, TLog#(depth)),
             Add#(4, f__, TLog#(depth)),
             Add#(TAdd#(TLog#(a__), 4), g__, TLog#(depth))
            );
   let verbose = True;
   Reg#(Bit#(32)) cycle <- mkReg(0);

   rule every1 (verbose);
      cycle <= cycle + 1;
   endrule

   BinaryCam#(depth, keySz) bcam <- mkBinaryCam();
   FIFO#(Bool) bcamMatchFifo <- mkFIFO();

   BRAM_Configure cfg = defaultValue;
   cfg.latency = 2;
   BRAM2Port#(Bit#(depthSz), Bit#(actionSz)) ram <- mkBRAM2Server(cfg);

   Reg#(Bit#(depthSz)) addrIdx <- mkReg(0);

   rule handle_bcam_response;
      let v <- bcam.readServer.response.get;
      //if (verbose) $display("matchTable %d: recv bcam response ", cycle, fshow(v));
      if (isValid(v)) begin // if match
         let address = fromMaybe(?, v);
         ram.portA.request.put(BRAMRequest{write:False, responseOnWrite: False, address: address, datain:?});
         bcamMatchFifo.enq(True);
      end
      else begin // if miss
         ram.portA.request.put(BRAMRequest{write:False, responseOnWrite: False, address: 0, datain: ?});
         bcamMatchFifo.enq(False);
      end
   endrule

   // Interface for lookup from data-plane modules
   interface Server lookupPort;
      interface Put request;
         method Action put (keys v);
            BcamReadReq#(keys) req_bcam = BcamReadReq{data: v};
            bcam.readServer.request.put(pack(req_bcam));
            //if (verbose) $display("matchTable %d: lookup ", cycle, fshow(req_bcam));
         endmethod
      endinterface
      interface Get response;
         method ActionValue#(Maybe#(actions)) get();
            let m <- toGet(bcamMatchFifo).get;
            let v <- ram.portA.response.get;
            if (verbose) $display("(%0d) matchTable: recv ram response ", $time, fshow(v));
            case (m) matches
               True: return tagged Valid unpack(v);
               False: return tagged Invalid;
            endcase
         endmethod
      endinterface
   endinterface

   // Interface for write from control-plane
   interface Put add_entry;
      method Action put (Tuple2#(keys, actions) v);
         BcamWriteReq#(Bit#(depthSz), Bit#(keySz)) req_bcam = BcamWriteReq{addr: addrIdx, data: pack(tpl_1(v))};
         BRAMRequest#(Bit#(depthSz), Bit#(actionSz)) req_ram = BRAMRequest{write: True, responseOnWrite: False, address: addrIdx, datain: 0};
         bcam.writeServer.put(req_bcam);
         ram.portA.request.put(req_ram);
         $display("(%0d) match_table: add flow %x", $time, addrIdx);
         addrIdx <= addrIdx + 1; //FIXME: currently no reuse of address.
      endmethod
   endinterface
   interface Put delete_entry;
      method Action put (Bit#(depthSz) id);
         BcamWriteReq#(Bit#(depthSz), Bit#(keySz)) req_bcam = BcamWriteReq{addr: id, data: 0};
         BRAMRequest#(Bit#(depthSz), Bit#(actionSz)) req_ram = BRAMRequest{write: True, responseOnWrite: False, address: id, datain: 0};
         bcam.writeServer.put(req_bcam);
         ram.portA.request.put(req_ram);
         $display("(%0d) match_table: delete flow %x", $time, id);
      endmethod
   endinterface
   interface Put modify_entry;
      method Action put (Tuple2#(Bit#(depthSz), actions) v);
         match { .flowid, .act} = v;
         BRAMRequest#(Bit#(depthSz), Bit#(actionSz)) req_ram = BRAMRequest{write: True, responseOnWrite: False, address: flowid, datain: pack(act)};
         ram.portA.request.put(req_ram);
      endmethod
   endinterface
endmodule

import "BDPI" matchtable_read = function ActionValue#(data_t) matchtable_read (key_t key)
   provisos (Bits#(key_t, keySz),
             Bits#(data_t, dataSz));

import "BDPI" matchtable_write = function Action matchtable_write (key_t key, data_t actions)
   provisos (Bits#(key_t, keySz),
             Bits#(data_t, dataSz));

module mkMatchTableBluesim(MatchTable#(depth, keys, actions))
   provisos (Bits#(keys, keySz),
             Bits#(actions, actionSz),
             Log#(depth, depthSz));

   let verbose = True;

   FIFO#(Tuple2#(keys, actions)) writeReqFifo <- mkFIFO;
   FIFO#(keys) readReqFifo <- mkFIFO;
   FIFO#(Maybe#(actions)) readDataFifo <- mkFIFO;

   Reg#(Bool)      isInitialized   <- mkReg(False);

   rule do_read (isInitialized);
      let v <- toGet(readReqFifo).get;
      $display("(%0d) do read %h", $time, v);
      let ret <- matchtable_read(v);
      readDataFifo.enq(tagged Valid unpack(ret));
   endrule

   rule do_init (!isInitialized);
      isInitialized <= True;
   endrule

   interface Server lookupPort;
      interface Put request = toPut(readReqFifo);
      interface Get response = toGet(readDataFifo);
   endinterface
   interface Put add_entry;
      method Action put (Tuple2#(keys, actions) v);
         matchtable_write(tpl_1(v), tpl_2(v));
      endmethod
   endinterface
   interface Put delete_entry;
      method Action put (Bit#(depthSz) id);
         
      endmethod
   endinterface
   interface Put modify_entry;
      method Action put (Tuple2#(Bit#(depthSz), actions) v);

      endmethod
   endinterface
endmodule
