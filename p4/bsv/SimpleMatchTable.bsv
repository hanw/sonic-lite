// Copyright (c) 2015 Cornell University.

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

/*
* SimpleMatchTable, which:
* - uses low order bits in input keys as indices to internal table
* - implements the same interface as cuckoo hashtable
* - is used for development and debugging purposes only
*/

import BRAM::*;
import Connectable::*;
import FIFOF::*;
import Pipe::*;
import SpecialFIFOs::*;
import Types::*;

typedef 16 BramAddrWidth;

interface Table;
   // Get/Put interface??
   interface PipeIn#(HeaderType_ethernet) etherIn;
   interface PipeIn#(HeaderType_ipv4) ipv4In;
   interface Put#(MatchEntry) putKey;
   interface Get#(Maybe#(MatchEntry)) readData;
   interface PipeOut#(ActionEntry) actionOut;
endinterface

(* synthesize *)
module mkSimpleMatchTable(Table);

   FIFOF#(HeaderType_ethernet) fifo_in_ether <- mkSizedFIFOF(1);
   FIFOF#(HeaderType_ipv4) fifo_in_ipv4 <- mkSizedFIFOF(1);
   FIFOF#(ActionEntry) fifo_out_action <- mkSizedFIFOF(1);
   FIFOF#(HeaderType_ethernet) fifo_out_ether <- mkSizedFIFOF(1);
   FIFOF#(HeaderType_ipv4) fifo_out_ipv4 <- mkSizedFIFOF(1);

   FIFOF#(Bit#(16)) match_cfFifo <- mkSizedFIFOF(1);

   // MatchTable
   BRAM_Configure matchBramConfig = defaultValue;
   matchBramConfig.latency = 1;
   BRAM2Port#(Bit#(BramAddrWidth), MatchEntry) matchRam <- mkBRAM2Server(matchBramConfig);

   // ActionTable
   BRAM_Configure actionBramConfig = defaultValue;
   actionBramConfig.latency = 1;
   BRAM2Port#(Bit#(BramAddrWidth), ActionEntry) actionRam <- mkBRAM2Server(actionBramConfig);

   rule get_ether;
      let v <- toGet(fifo_in_ether).get;
      $display("ethernet, %x %x", v.srcAddr, v.dstAddr);
      // hash
      fifo_out_ether.enq(v);
   endrule

   rule get_ipv4;
      let v <- toGet(fifo_in_ipv4).get;
      $display("ipv4 %x %x", v.srcAddr, v.dstAddr);
      // hash
      fifo_out_ipv4.enq(v);
      match_cfFifo.enq(1);
   endrule

   rule doMatch;
      let v <- toGet(match_cfFifo).get;
      matchRam.portB.request.put(BRAMRequest{write:False, address: zeroExtend(v), datain:?, responseOnWrite:?});
   endrule

   rule getMatchResult;
      let entry <- matchRam.portB.response.get;
      fifo_out_action.enq(ActionEntry{ipv4:0, stats:0, insts:0, actions:0});
   endrule

   interface Put putKey;
      method Action put(MatchEntry e);
         matchRam.portA.request.put(BRAMRequest{write:True, address: truncate(pack(e)), datain: e, responseOnWrite:? });
      endmethod
   endinterface
   interface Get readData;
      method ActionValue#(Maybe#(MatchEntry)) get();
         let entry <- matchRam.portA.response.get;
         Maybe#(MatchEntry) v = tagged Valid entry;
         return v;
      endmethod
   endinterface

   interface PipeIn etherIn = toPipeIn(fifo_in_ether);
   interface PipeIn ipv4In = toPipeIn(fifo_in_ipv4);
   interface PipeOut actionOut = toPipeOut(fifo_out_action);
endmodule
