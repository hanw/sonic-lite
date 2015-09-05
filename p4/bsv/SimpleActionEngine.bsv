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
* SimpleActionEngine, which:
* - only support subset of instructions
* - implements the same interface as full action engine
* - is used for development and debugging purposes only
*/
import Clocks::*;
import DefaultValue::*;
import FIFO::*;
import FIFOF::*;
import GetPut::*;
import Vector::*;
import Pipe::*;

import Types::*;

// Action Types
interface ActionEngine_port_mapping;
   interface PipeIn#(PHV_port_mapping) phv_in;
   // params from match table
   interface PipeIn#(ActionSpec_port_mapping) action_data;
   interface PipeOut#(PHV_bd) phv_out;
endinterface

(* synthesize *)
module mkSimpleActionEngine(ActionEngine_port_mapping);
   FIFOF#(ActionSpec_port_mapping) fifo_in_action <- mkSizedFIFOF(1);
   FIFOF#(PHV_port_mapping) fifo_in_phv <- mkSizedFIFOF(1);
   FIFOF#(PHV_bd) fifo_out_phv <- mkSizedFIFOF(1);

   FIFOF#(Bit#(12)) ingress_metadata_vrf <- mkSizedFIFOF(1);
   FIFOF#(Bit#(16)) ingress_metadata_bd <- mkSizedFIFOF(1);
   FIFOF#(Bit#(9)) standard_metadata_ingress_port <- mkSizedFIFOF(1);
   FIFOF#(Bit#(32)) ipv4_dstAddr <- mkSizedFIFOF(1);
   FIFOF#(Bit#(16)) ingress_metadata_nexthop_index <- mkSizedFIFOF(1);

   FIFOF#(Bit#(16)) res_ingress_metadata_bd <- mkSizedFIFOF(1);

   FIFOF#(Bit#(16)) action_data_bd <- mkSizedFIFOF(1);

   rule get_phv;
      let v <- toGet(fifo_in_phv).get;
      ingress_metadata_vrf.enq(v.ingress_metadata_vrf);
      ingress_metadata_bd.enq(v.ingress_metadata_bd);
      ingress_metadata_nexthop_index.enq(v.ingress_metadata_nexthop_index);
      standard_metadata_ingress_port.enq(v.standard_metadata_ingress_port);
      ipv4_dstAddr.enq(v.ipv4_dstAddr);
   endrule

   rule get_action_data;
      let v <- toGet(fifo_in_action).get;
      action_data_bd.enq(v.bd);
   endrule

   // Action Engine Operations
   rule modify_field_ingress_metadata_bd;
      let field <- toGet(ingress_metadata_bd).get;
      let action_data <- toGet(action_data_bd).get;
      // modify field
      field = action_data;
      res_ingress_metadata_bd.enq(field);
   endrule

   rule mk_phv_bd;
      let v_ingress_metadata_vrf <- toGet(ingress_metadata_vrf).get;
      let v_ingress_metadata_nexthop_index <- toGet(ingress_metadata_nexthop_index).get;
      let v_standard_metadata_ingress_port <- toGet(standard_metadata_ingress_port).get;
      let v_ipv4_dstAddr <- toGet(ipv4_dstAddr).get;
      PHV_bd data = defaultValue;
      data.ingress_metadata_vrf = v_ingress_metadata_vrf;
      data.ingress_metadata_nexthop_index = v_ingress_metadata_nexthop_index;
      data.ipv4_dstAddr = v_ipv4_dstAddr;
      fifo_out_phv.enq(data);
   endrule

   interface PipeIn phv_in = toPipeIn(fifo_in_phv);
   interface PipeIn action_data = toPipeIn(fifo_in_action);
   interface PipeOut phv_out = toPipeOut(fifo_out_phv);
endmodule

