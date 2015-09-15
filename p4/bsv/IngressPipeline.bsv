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

import Clocks::*;
import Connectable::*;
import DefaultValue::*;
import FIFO::*;
import FIFOF::*;
import GetPut::*;
import Vector::*;

import Pipe::*;
import SimpleMatchTable::*;
import SimpleActionEngine::*;
import Types::*;

interface Pipeline_port_mapping;
   interface PipeIn#(PHV_port_mapping) phvIn;
   interface PipeOut#(PHV_bd) phvOut;
endinterface

interface Pipeline_bd;
   interface PipeIn#(PHV_bd) phvIn;
   interface PipeOut#(PHV_ipv4_fib) phvOut;
endinterface

// Data Plane:
// - Input: PHV for this stage
// - Output: PHV for next stage
// Control Plane:
// - Input: MatchSpec
// - Output: ActionSpec
(* synthesize *)
module mkIngressPipeline_port_mapping(Pipeline_port_mapping);
   FIFOF#(PHV_port_mapping) fifo_in_phv <- mkSizedFIFOF(1);
   FIFOF#(PHV_bd) fifo_out_phv <- mkSizedFIFOF(1);

   FIFOF#(Bit#(12)) ingress_metadata_vrf <- mkSizedFIFOF(1);
   FIFOF#(Bit#(16)) ingress_metadata_bd <- mkSizedFIFOF(1);
   FIFOF#(Bit#(9)) standard_metadata_ingress_port <- mkSizedFIFOF(1);
   FIFOF#(Bit#(32)) ipv4_dstAddr <- mkSizedFIFOF(1);
   FIFOF#(Bit#(16)) ingress_metadata_nexthop_index <- mkSizedFIFOF(1);

   FIFOF#(Bit#(16)) res_ingress_metadata_bd <- mkSizedFIFOF(1);

   // generate table specific interface
   MatchTable_port_mapping matchTable <- mkMatchTable_port_mapping();
   ActionEngine_port_mapping actionEngine <- mkActionEngine_port_mapping();

   rule get_phv_in;
      let v <- toGet(fifo_in_phv).get;
      // match field -> match table
      matchTable.phv_in.enq(MatchInput_port_mapping{standard_metadata_ingress_port:v.standard_metadata_ingress_port});
   endrule

   // Rules to forward bypass signals.
   // can further optimized
   rule mk_phv_out;
      let v_ingress_metadata_vrf <- toGet(ingress_metadata_vrf).get;
      let v_ingress_metadata_bd <- toGet(ingress_metadata_bd).get;
      let v_ingress_metadata_nexthop_index <- toGet(ingress_metadata_nexthop_index).get;
      let v_ipv4_dstAddr <- toGet(ipv4_dstAddr).get;
      PHV_bd data = defaultValue;
      data.ingress_metadata_vrf = v_ingress_metadata_vrf;
      data.ingress_metadata_bd = v_ingress_metadata_bd;
      data.ingress_metadata_nexthop_index = v_ingress_metadata_nexthop_index;
      data.ipv4_dstAddr = v_ipv4_dstAddr;
      fifo_out_phv.enq(data);
   endrule

   // Control logic is associated with next_tables pointer
   // Control specifies connection between ouput of one table to input of another.
   // Use of control is by data flow.
   mkConnection(matchTable.action_data, actionEngine.action_data);

   interface PipeIn phvIn = toPipeIn(fifo_in_phv);
   interface PipeOut phvOut = toPipeOut(fifo_out_phv);
endmodule

(* synthesize *)
module mkIngressPipeline_bd(Pipeline_bd);
   FIFOF#(PHV_bd) fifo_in_phv <- mkSizedFIFOF(1);
   FIFOF#(PHV_ipv4_fib) fifo_out_phv <- mkSizedFIFOF(1);

   FIFOF#(Bit#(12)) ingress_metadata_vrf <- mkSizedFIFOF(1);
   FIFOF#(Bit#(32)) ipv4_dstAddr <- mkSizedFIFOF(1);
   FIFOF#(Bit#(16)) ingress_metadata_nexthop_index <- mkSizedFIFOF(1);

   FIFOF#(Bit#(16)) res_ingress_metadata_bd <- mkSizedFIFOF(1);

   // generate table specific interface
   MatchTable_bd matchTable <- mkMatchTable_bd();
   ActionEngine_bd actionEngine <- mkActionEngine_bd();

   rule get_phv_in;
      let v <- toGet(fifo_in_phv).get;
      // match field -> match table
   endrule

   // Rules to forward bypass signals.
   // can further optimized
   rule mk_phv_out;
      let v_ingress_metadata_vrf <- toGet(ingress_metadata_vrf).get;
      let v_ingress_metadata_nexthop_index <- toGet(ingress_metadata_nexthop_index).get;
      let v_ipv4_dstAddr <- toGet(ipv4_dstAddr).get;
      PHV_ipv4_fib data = defaultValue;
      data.ingress_metadata_vrf = v_ingress_metadata_vrf;
      data.ingress_metadata_nexthop_index = v_ingress_metadata_nexthop_index;
      data.ipv4_dstAddr = v_ipv4_dstAddr;
      fifo_out_phv.enq(data);
   endrule

   // Control logic is associated with next_tables pointer
   // Control specifies connection between ouput of one table to input of another.
   // Use of control is by data flow.
   mkConnection(matchTable.action_data, actionEngine.action_data);

   interface PipeIn phvIn = toPipeIn(fifo_in_phv);
   interface PipeOut phvOut = toPipeOut(fifo_out_phv);
endmodule

