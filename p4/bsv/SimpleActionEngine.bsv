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
   interface PipeIn#(ActionInput_port_mapping) action_in;
   interface PipeOut#(ActionOutput_port_mapping) action_out;
   interface PipeIn#(ActionSpec_port_mapping) action_data;
endinterface

interface ActionEngine_bd;
   interface PipeIn#(ActionInput_bd) action_in;
   interface PipeOut#(ActionOutput_bd) action_out;
   interface PipeIn#(ActionSpec_bd) action_data;
endinterface

// Inputs: field_ref -> call_sequence.tuple(field_ref)
// Inputs: ActionSpec -> param_names
// Output: field_ref -> call_sequence.tuple(field_ref)
(* synthesize *)
module mkActionEngine_port_mapping(ActionEngine_port_mapping);
   FIFOF#(ActionSpec_port_mapping) fifo_in_action <- mkSizedFIFOF(1);
   FIFOF#(ActionInput_port_mapping) fifo_in_field <- mkSizedFIFOF(1);
   FIFOF#(ActionOutput_port_mapping) fifo_out_field <- mkSizedFIFOF(1);

   FIFOF#(Bit#(16)) ingress_metadata_bd <- mkSizedFIFOF(1);
   FIFOF#(Bit#(16)) res_ingress_metadata_bd <- mkSizedFIFOF(1);
   FIFOF#(Bit#(16)) action_data_bd <- mkSizedFIFOF(1);

   rule get_phv;
      let v <- toGet(fifo_in_field).get;
      ingress_metadata_bd.enq(v.ingress_metadata_bd);
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

   rule mk_header_field_port_mapping;
      let v_ingress_metadata_bd <- toGet(res_ingress_metadata_bd).get;
      ActionOutput_port_mapping data = defaultValue;
      data.ingress_metadata_bd = v_ingress_metadata_bd;
      fifo_out_field.enq(data);
   endrule

   interface PipeIn action_in = toPipeIn(fifo_in_field);
   interface PipeIn action_data = toPipeIn(fifo_in_action);
   interface PipeOut action_out = toPipeOut(fifo_out_field);
endmodule

(* synthesize *)
module mkActionEngine_bd(ActionEngine_bd);
   FIFOF#(ActionSpec_bd) fifo_in_action <- mkSizedFIFOF(1);
   FIFOF#(ActionInput_bd) fifo_in_field <- mkSizedFIFOF(1);
   FIFOF#(ActionOutput_bd) fifo_out_field <- mkSizedFIFOF(1);

   FIFOF#(Bit#(12)) ingress_metadata_vrf <- mkSizedFIFOF(1);
   FIFOF#(Bit#(12)) res_ingress_metadata_vrf <- mkSizedFIFOF(1);

   FIFOF#(Bit#(12)) action_data_vrf <- mkSizedFIFOF(1);

   rule get_phv;
      let v <- toGet(fifo_in_field).get;
      ingress_metadata_vrf.enq(v.ingress_metadata_vrf);
   endrule

   rule get_action_data;
      let v <- toGet(fifo_in_action).get;
      action_data_vrf.enq(v.vrf);
   endrule

   // Action Engine Operations
   rule modify_field_ingress_metadata_vrf;
      let field <- toGet(ingress_metadata_vrf).get;
      let action_data <- toGet(action_data_vrf).get;
      // modify field
      field = action_data;
      res_ingress_metadata_vrf.enq(field);
   endrule

   rule mk_header_field_bd;
      let v_ingress_metadata_vrf <- toGet(res_ingress_metadata_vrf).get;
      ActionOutput_bd data = defaultValue;
      data.ingress_metadata_vrf = v_ingress_metadata_vrf;
      fifo_out_field.enq(data);
   endrule

   interface PipeIn action_in = toPipeIn(fifo_in_field);
   interface PipeIn action_data = toPipeIn(fifo_in_action);
   interface PipeOut action_out = toPipeOut(fifo_out_field);
endmodule

