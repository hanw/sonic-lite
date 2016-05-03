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

interface MatchTable#(numeric type depth, numeric type keySz, numeric type actionSz);
   interface Server#(Bit#(keySz), Maybe#(Bit#(actionSz))) lookupPort;
   interface Put#(Tuple2#(Bit#(keySz), Bit#(actionSz))) add_entry;
   interface Put#(Bit#(TLog#(depth))) delete_entry;
   interface Put#(Tuple2#(Bit#(TLog#(depth)), Bit#(actionSz))) modify_entry;
endinterface

import "BDPI" function ActionValue#(Bit#(10)) matchtable_read_dmac(Bit#(54) dstAddr);
import "BDPI" function Action matchtable_write_dmac(Bit#(54) dstAddr, Bit#(10) data);
import "BDPI" function ActionValue#(Bit#(2)) matchtable_read_acceptor(Bit#(18) msgtype);
import "BDPI" function Action matchtable_write_acceptor(Bit#(18) msgtype, Bit#(2) data);
import "BDPI" function ActionValue#(Bit#(1)) matchtable_read_sequence(Bit#(18) msgtype);
import "BDPI" function Action matchtable_write_sequence(Bit#(18) msgtype, Bit#(1) data);

typeclass MatchTableSim#(numeric type ksz, numeric type vsz);
   function ActionValue#(Bit#(vsz)) matchtable_read(Bit#(ksz) key);
   function Action matchtable_write(Bit#(ksz) key, Bit#(vsz) data);
endtypeclass

instance MatchTableSim#(54, 10);
   function ActionValue#(Bit#(10)) matchtable_read(Bit#(54) key);
   actionvalue
      let v <- matchtable_read_dmac(key);
      return v;
   endactionvalue
   endfunction
   function Action matchtable_write(Bit#(54) key, Bit#(10) data);
   action
      $display("(%0d) matchtable write dmac %h %h", $time, key, data);
      matchtable_write_dmac(key, data);
      $display("(%0d) matchtable write dmac done", $time);
   endaction
   endfunction
endinstance

instance MatchTableSim#(18, 1);
   function ActionValue#(Bit#(1)) matchtable_read(Bit#(18) key);
   actionvalue
      let v <- matchtable_read_sequence(key);
      return v;
   endactionvalue
   endfunction
   function Action matchtable_write(Bit#(18) key, Bit#(1) data);
   action
      matchtable_write_sequence(key, data);
   endaction
   endfunction
endinstance

instance MatchTableSim#(18, 2);
   function ActionValue#(Bit#(2)) matchtable_read(Bit#(18) key);
   actionvalue
      let v <- matchtable_read_acceptor(key);
      return v;
   endactionvalue
   endfunction
   function Action matchtable_write(Bit#(18) key, Bit#(2) data);
   action
      $display("(%0d) matchtable write acceptor %h %h", $time, key, data);
      matchtable_write_acceptor(key, data);
      $display("(%0d) matchtable write acceptor done", $time);
   endaction
   endfunction
endinstance

module mkMatchTable(MatchTable#(depth, keySz, actionSz))
   provisos(Mul#(c__, 256, d__),
            Add#(c__, 7, TLog#(depth)),
            Log#(d__, TLog#(depth)),
            Mul#(e__, 9, keySz),
            Add#(TAdd#(TLog#(c__), 4), 2, TLog#(TDiv#(depth, 4))),
            Log#(TDiv#(depth, 16), TAdd#(TLog#(c__), 4)),
            Add#(9, f__, keySz),
            PriorityEncoder::PEncoder#(d__),
            Add#(2, g__, TLog#(depth)),
            Add#(4, h__, TLog#(depth)),
`ifdef SIMULATION
            MatchTableSim#(keySz, actionSz),
`endif
            Add#(TAdd#(TLog#(c__), 4), i__, TLog#(depth)));

   MatchTable#(depth, keySz, actionSz) ret_ifc;
`ifdef SIMULATION
   ret_ifc <- mkMatchTableBluesim();
`else
   ret_ifc <- mkMatchTableSynth();
`endif
   return ret_ifc;
endmodule

module mkMatchTableSynth(MatchTable#(depth, keySz, actionSz))
   provisos (NumAlias#(depthSz, TLog#(depth)),
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
      if (verbose) $display("(%0d) matchTable recv bcam response ", $time, fshow(v));
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
         method Action put (Bit#(keySz) v);
            BcamReadReq#(Bit#(keySz)) req_bcam = BcamReadReq{data: v};
            bcam.readServer.request.put(pack(req_bcam));
            //if (verbose) $display("matchTable %d: lookup ", cycle, fshow(req_bcam));
         endmethod
      endinterface
      interface Get response;
         method ActionValue#(Maybe#(Bit#(actionSz))) get();
            let m <- toGet(bcamMatchFifo).get;
            let act <- ram.portA.response.get;
            if (verbose) $display("(%0d) matchTable: recv ram response ", $time, fshow(act));
            case (m) matches
               True: return tagged Valid act;
               False: return tagged Invalid;
            endcase
         endmethod
      endinterface
   endinterface

   // Interface for write from control-plane
   interface Put add_entry;
      method Action put (Tuple2#(Bit#(keySz), Bit#(actionSz)) v);
         BcamWriteReq#(Bit#(depthSz), Bit#(keySz)) req_bcam = BcamWriteReq{addr: addrIdx, data: pack(tpl_1(v))};
         BRAMRequest#(Bit#(depthSz), Bit#(actionSz)) req_ram = BRAMRequest{write: True, responseOnWrite: False, address: addrIdx, datain: pack(tpl_2(v))};
         bcam.writeServer.put(req_bcam);
         ram.portA.request.put(req_ram);
         $display("(%0d) match_table: add flow %x %x %x", $time, addrIdx, tpl_1(v), tpl_2(v));
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
      method Action put (Tuple2#(Bit#(depthSz), Bit#(actionSz)) v);
         match { .flowid, .act} = v;
         BRAMRequest#(Bit#(depthSz), Bit#(actionSz)) req_ram = BRAMRequest{write: True, responseOnWrite: False, address: flowid, datain: pack(act)};
         ram.portA.request.put(req_ram);
      endmethod
   endinterface
endmodule

module mkMatchTableBluesim(MatchTable#(depth, keySz, actionSz))
   provisos (MatchTableSim#(keySz, actionSz),
             Log#(depth, depthSz));
   let verbose = True;

   FIFO#(Tuple2#(Bit#(keySz), Bit#(actionSz))) writeReqFifo <- mkFIFO;
   FIFO#(Bit#(keySz)) readReqFifo <- mkFIFO;
   FIFO#(Maybe#(Bit#(actionSz))) readDataFifo <- mkFIFO;

   Reg#(Bool)      isInitialized   <- mkReg(False);

   rule do_read (isInitialized);
      let v <- toGet(readReqFifo).get;
      $display("(%0d) MatchTable: do_read %h", $time, v);
      let ret <- matchtable_read(pack(v));
      $display("(%0d) MatchTable: read %h", $time, ret);
      if (ret != 0)
         readDataFifo.enq(tagged Valid ret);
      else
         readDataFifo.enq(tagged Invalid);
   endrule

   rule do_init (!isInitialized);
      isInitialized <= True;
   endrule

   interface Server lookupPort;
      interface Put request = toPut(readReqFifo);
      interface Get response = toGet(readDataFifo);
   endinterface
   interface Put add_entry;
      method Action put (Tuple2#(Bit#(keySz), Bit#(actionSz)) v);
         $display("(%0d) MatchTable: insert %h %h", $time, tpl_1(v), tpl_2(v));
         matchtable_write(tpl_1(v), tpl_2(v));
      endmethod
   endinterface
   interface Put delete_entry;
      method Action put (Bit#(depthSz) id);
         
      endmethod
   endinterface
   interface Put modify_entry;
      method Action put (Tuple2#(Bit#(depthSz), Bit#(actionSz)) v);

      endmethod
   endinterface
endmodule
