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

import FIFO::*;
import MMU::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;

module mkSimpleMMU(MMU#(addrWidth))
   provisos(Add#(a__, addrWidth, 44));
   let verbose = True;

   Reg#(Bit#(32)) cycle <- mkReg(0);
   rule every1 if (verbose);
      cycle <= cycle + 1;
   endrule

   Vector#(2, FIFO#(ReqTup)) incomingReqs <- replicateM(mkFIFO);

   Vector#(2, Server#(ReqTup, Bit#(addrWidth))) addrServers;
   for (Integer i=0; i < 2; i=i+1) begin
      addrServers[i] =
      (interface Server#(ReqTup, Bit#(addrWidth));
          interface Put request;
             method Action put(ReqTup req);
                $display("%d: Put MMU request %x %x", cycle, req.id, req.off);
                incomingReqs[i].enq(req);
             endmethod
          endinterface
          interface Get response;
             method ActionValue#(Bit#(addrWidth)) get();
                let rv <- toGet(incomingReqs[i]).get;
                Bit#(addrWidth) offset = truncate(rv.off);
                $display("%d: Get MMU response %x", cycle, offset);
                return offset;
             endmethod
          endinterface
       endinterface);
   end
   interface addr = addrServers;
endmodule


