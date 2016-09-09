// Copyright (c) 2016 Cornell University.

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

import ClientServer::*;
import Ethernet::*;
import PacketBuffer::*;
import Vector::*;
import FIFOF::*;
import GetPut::*;

import `TYPEDEF::*;
typedef 4 PortMax;

typedef Bit#(TLog#(PortMax)) PortNum;

typedef struct {
   PortNum ingress;
   PortNum egress;
   MetadataT meta;
} MetaPkt deriving (Bits, Eq);

interface Xbar;
   interface Server#(MetadataRequest, MetadataResponse) prev;
endinterface

module mkXbar#(Vector#(PortMax, PktReadClient) clients, Vector#(PortMax, PktReadServer) servers)(Xbar);
   Vector#(PortMax, FIFOF#(MetadataT)) out_queue <- replicateM(mkFIFOF);
   Vector#(PortMax, Reg#(Bool)) output_port_free <- replicateM(mkReg(False));
   Vector#(PortMax, Reg#(Bool)) input_port_free <- replicateM(mkReg(False));

   Vector#(PortMax, FIFOF#(Bit#(EtherLen))) req_in_ff <- replicateM(mkGFIFOF(False, True)); // unguarded deq

   // recording active egress for each ingress.
   Vector#(PortMax, Reg#(
      Maybe #(Tuple2 #(
         PortNum, Bit#(EtherLen))))) binfo <- replicateM(mkReg(tagged Invalid));

   // enqueue request to egress fifof
   //rule dequeue_input_port_0;
   //   let pkt_inst = out_queue.first;
   //   out_queue.deq;
   //endrule

   // four rules for each input
   // active[i] == j
   // what if active[i+1] == j ??
   // req[j] == i
   //rule readData_dispatch if (active[i] == j && req[j] == i);
   //   let readData = servers[i].readData.get;
   //   clients[j].readData.put(readData);
   //   if (readData.eop) begin
   //      input_port_free[i] <= True;
   //   end
   //endrule

   // set req[j] = i
   //rule readReq_arbit if (req_in_ff[i].notEmpty()); // arbitrate between four outputs
   //   let readReq = clients[i].readReq.get;
   //   servers[i].readReq.put(readReq);
   //endrule

   // len is basically descriptor...
   for (Integer i_src = 0; i_src < valueOf(PortMax); i_src = i_src + 1) begin
      rule readLen_dispatch;// (servers[i_src].readLen.notEmpty);
         let req = out_queue[i_src].first;
         out_queue[i_src].deq;
         let readLen <- servers[i_src].readLen.get;
         // decode dest from metadata
         if (req.standard_metadata$egress_port matches tagged Valid .egress) begin
            clients[egress].readLen.put(readLen);
            binfo[i_src] <= tagged Valid tuple2(truncate(egress), readLen);
         end
      endrule
   end

   interface prev = (interface Server#(MetadataRequest, MetadataResponse);
      interface request = (interface Put;
         method Action put (MetadataRequest req);
            // enqueue to one of the output queue, based on ingress and egress port.
            if (req.meta.standard_metadata$ingress_port matches tagged Valid .ingress) begin
               out_queue[ingress].enq(req.meta);
            end
            else begin
               $display("Invalid Ingress");
            end
         endmethod
      endinterface);
   endinterface);
endmodule

