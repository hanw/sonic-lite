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

import Ehr::*;
import FIFO::*;
import GetPut::*;
import ClientServer::*;
import ClientServerHelper::*;
import Vector::*;

interface CAM#(numeric type n, type idx_t, type dta_t);
   interface Put#(Tuple2#(idx_t,dta_t)) writePort;
   interface Server#(dta_t, Maybe#(idx_t)) readPort;
endinterface

module mkCAM(CAM#(n, idx_t, dta_t))
   provisos(Eq#(dta_t),
            Add#(n, 1, n1),
            Log#(n1, sz),
            Add#(sz, 1, sz1),
            Bits#(idx_t, idxSz),
            Bits#(dta_t, dtaSz));
   Integer ni = valueOf(n);

   Bit#(sz1) nb = fromInteger(ni);
   Bit#(sz1) n2 = 2*nb;
   Vector#(n, Reg#(Bool)) valids <- replicateM(mkReg(False));
   Vector#(n, Reg#(idx_t)) contents <- replicateM(mkRegU);
   Vector#(n, Reg#(dta_t)) data <- replicateM(mkRegU);

   Ehr#(1, Bit#(sz1)) enqP <- mkEhr(0);
   Reg#(Bit#(sz1)) deqP <- mkReg(0);

   Bit#(sz1) cnt0 = enqP[0] >= deqP? enqP[0] - deqP: (enqP[0]%nb + nb) - deqP%nb;

   FIFO#(Maybe#(Bit#(sz1))) immQ <- mkFIFO;
   FIFO#(Maybe#(idx_t)) respQ <- mkFIFO;

   rule delEntry if ( cnt0 > nb );
      deqP <= (deqP + 1)%n2;
   endrule

   rule doRead;
      let v <- toGet(immQ).get();
      if ( isValid(v) ) begin
         respQ.enq(tagged Valid contents[fromMaybe(?, v)]);
      end
      else begin
         respQ.enq(tagged Invalid);
      end
   endrule

   FIFO#(Tuple2#(Bit#(sz1), dta_t)) immQ_wr <- mkFIFO;

   rule doWrite;
      let v <- toGet(immQ_wr).get();
      data[tpl_1(v)] <= tpl_2(v);
   endrule

   interface Put writePort;
      method Action put(Tuple2#(idx_t, dta_t) v);
         valids[enqP[0]%nb] <= True;
         contents[enqP[0]%nb] <= tpl_1(v);
         immQ_wr.enq(tuple2(enqP[0]%nb, tpl_2(v)));
         enqP[0] <= (enqP[0] + 1) % n2;
      endmethod
   endinterface

   interface Server readPort;
      interface Put request;
         method Action put(dta_t v);
            Maybe#(Bit#(sz1)) ret = tagged Invalid;
            for(Bit#(sz1) i = 0; i < nb; i = i + 1)
               begin
                  let ptr = (deqP + i)%nb;
                  if( v == data[ptr] && valids[ptr] && i < cnt0) begin
                     ret = tagged Valid ptr;
                     //valids[ptr] <= False;
                  end
               end
            immQ.enq(ret);
         endmethod
      endinterface

      interface Get response = toGet(respQ);
   endinterface
endmodule
