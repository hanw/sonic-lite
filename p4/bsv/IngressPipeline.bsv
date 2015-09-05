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
   interface PipeOut#(PHV_bd)          phvOut;
endinterface

module mkIngressPipeline_port_mapping(Pipeline_port_mapping);
   FIFOF#(PHV_port_mapping) fifo_in_phv <- mkSizedFIFOF(1);
   FIFOF#(PHV_bd) fifo_out_phv <- mkSizedFIFOF(1);

   // Rules to forward bypass signals.
   // can further optimized
   rule build_phvOut;
      let v <- toGet(fifo_in_phv).get;
      PHV_bd bd = defaultValue;
      bd.ingress_metadata_vrf = v.ingress_metadata_vrf;
      bd.ingress_metadata_bd = v.ingress_metadata_bd;
      bd.ipv4_dstAddr = v.ipv4_dstAddr;
      bd.ingress_metadata_nexthop_index = v.ingress_metadata_nexthop_index;
      bd.header_addr = v.header_addr;
      bd.payload_addr = v.payload_addr;
      bd.payload_len = v.payload_len;
      fifo_out_phv.enq(bd);
   endrule

   // generate table specific interface
   MatchTable_port_mapping matchTable <- mkSimpleMatchTable();
   ActionEngine_port_mapping actionEngine <- mkSimpleActionEngine();

   mkConnection(matchTable.action_data, actionEngine.action_data);

   interface PipeIn phvIn = toPipeIn(fifo_in_phv);
   interface PipeOut phvOut = toPipeOut(fifo_out_phv);
endmodule

