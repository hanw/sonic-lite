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
import DbgTypes::*;
import Ethernet::*;
import FIFO::*;
import GetPut::*;
import PaxosTypes::*;
import RegFile::*;

interface P4RegFile#(numeric type nReaders, numeric type nWriters, type addr, type data);
   interface Vector#(nReaders, Server#());
   interface Vector#(nWriters, Server#());
endinterface

module mkP4RegFile#(Vector#(nReaders, Client#() readers,
                    Vector#(nWriters, Client#() writers)))
                   (P4RegFile#(nReaders, nWriters, addr, data))
   provisos(Bits#(addr, asz), Bits#(data, dsz), Bounded#(addr));

   RegFile#(addr, data) regFile <- mkRegFileFull();

   rule process;
      let req <- toGet(reqFifo).get();
      if (req.write) begin
         regFile.upd(req.address, req.datain);
         if (req.responseOnWrite)
            responseFifo.enq(req.datain)
      end
      else begin
         let d = regFile.sub(req.address)
         responseFifo.enq(d);
      end
   endrule
endmodule

