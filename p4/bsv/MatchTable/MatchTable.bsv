import FIFOF::*;
import GetPut::*;
import ClientServer::*;
import StmtFSM::*;
import Vector::*;
import DefaultValue::*;
import BRAM::*;
import FShow::*;

import MatchTableTypes::*;
import Bcam::*;
import BcamTypes::*;

typedef 9 KeyLen;
typedef 10 ValueLen;
typedef 10 AddrIdx;

typedef struct {
   Bit#(16) action_ops;
} ActionSpec_t deriving (Bits, Eq, FShow);

typedef struct {
   Bit#(9) data;
   ActionSpec_t param;
} MatchSpec_t deriving (Bits, Eq, FShow);

interface MatchTable;
   interface Server#(Bit#(KeyLen), ActionSpec_t) lookupPort;
   interface Server#(Bit#(10), Bit#(9)) readPort;
   interface Put#(MatchSpec_t) add_entry;
endinterface

function BRAMRequest#(Address, Value)
   makeRequest(Bool write, Address addr, Value data);
   return BRAMRequest {
      write : write,
      responseOnWrite : False,
      address : addr,
      datain : data
   };
endfunction

module mkMatchTable(MatchTable);
   let verbose = True;
   Reg#(Bit#(32)) cycle <- mkReg(0);

   rule every1 (verbose);
      cycle <= cycle + 1;
   endrule

   BinaryCam#(1024, 9) bcam <- mkBinaryCam;

   BRAM_Configure cfg = defaultValue;
   cfg.latency = 2;
   BRAM2Port#(Bit#(10), ActionSpec_t) ram <- mkBRAM2Server(cfg);

   Reg#(Bit#(AddrIdx)) addrIdx <- mkReg(0);

//   rule start;
//      let currReq <- toGet(requestFIFO).get;
//      if (currReq.op == PUT)
//      begin
//         bcam.writeServer.put(tuple2(truncate(addrIdx), truncate(currReq.key)));
//         currReq.addrIdx = addrIdx;
//         put_fifo.enq(currReq);
//      end
//      else if (currReq.op == GET)
//      begin
//         bcam.readServer.request.put(truncate(currReq.key));
//         get_fifo_1.enq(currReq);
//      end
//   endrule

   rule handle_bcam_response;
      let v <- bcam.readServer.response.get;
      if (verbose) $display("matchTable %d: recv bcam response ", cycle, fshow(v));
      if (isValid(v)) begin
         let address = fromMaybe(?, v);
         ram.portA.request.put(BRAMRequest{write:False, responseOnWrite: False, address: address, datain:?});
      end
   endrule

   interface Server lookupPort;
      interface Put request;
         method Action put (Bit#(9) v);
            BcamReadReq#(9) req_bcam = BcamReadReq{data: v};
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

   interface Put add_entry;
      method Action put (MatchSpec_t m);
         BcamWriteReq#(10, 9) req_bcam = BcamWriteReq{addr: addrIdx, data: m.data};
         BRAMRequest#(Bit#(10), ActionSpec_t) req_ram = BRAMRequest{write: False, responseOnWrite: False, address: addrIdx, datain: m.param};
         bcam.writeServer.put(req_bcam);
         ram.portA.request.put(req_ram);
         addrIdx <= addrIdx + 1; //FIXME: currently no reuse of address.
      endmethod
   endinterface
endmodule
