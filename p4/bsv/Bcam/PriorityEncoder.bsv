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
import Vector::*;
import DefaultValue::*;
import Pipe::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import GetPut::*;
import Connectable::*;
import Arith::*;

interface PEnc#(numeric type n);
   interface PipeOut#(Bit#(TLog#(n))) bin;
   interface PipeOut#(Bool) vld;
endinterface
typeclass PriorityEncoder#(numeric type n);
   module mkPriorityEncoder#(PipeOut#(Bit#(n)) oht)
                            (PEnc#(n) out);
endtypeclass

instance PriorityEncoder#(2);
   module mkPriorityEncoder#(PipeOut#(Bit#(2)) oht)
                            (PEnc#(2));
      FIFOF#(Bit#(1)) binpipe <- mkFIFOF;
      FIFOF#(Bool) vldpipe <- mkFIFOF;

      rule set_output;
         let v <- toGet(oht).get;
         Bool output_vld = boolor(unpack(v[0]), unpack(v[1]));
         Bit#(1) output_bin = ~v[0];
         binpipe.enq(output_bin);
         vldpipe.enq(output_vld);
      endrule

      interface bin = toPipeOut(binpipe);
      interface vld = toPipeOut(vldpipe);
   endmodule
endinstance

instance PriorityEncoder#(n)
   provisos (Add#(TDiv#(n, 2), a__, n)
            ,Div#(n, 2, nhalf)
            ,Add#(1, TLog#(nhalf), TLog#(n))
            ,Log#(TDiv#(n, 2), TLog#(nhalf))
            ,PriorityEncoder::PriorityEncoder#(TDiv#(n, 2)));
   module mkPriorityEncoder#(PipeOut#(Bit#(n)) oht)
                            (PEnc#(n));
      FIFOF#(Bit#(TLog#(n))) binpipe <- mkFIFOF;
      FIFOF#(Bool) vldpipe <- mkFIFOF;
      FIFOF#(Bit#(nhalf)) p0_infifo <- mkBypassFIFOF;
      FIFOF#(Bit#(nhalf)) p1_infifo <- mkBypassFIFOF;

      PEnc#(TDiv#(n, 2)) p0 <- mkPriorityEncoder(toPipeOut(p0_infifo));
      PEnc#(TDiv#(n, 2)) p1 <- mkPriorityEncoder(toPipeOut(p1_infifo));

      rule set_input;
         let bin <- toGet(oht).get;
         p0_infifo.enq(bin[valueOf(nhalf)-1:0]);
         p1_infifo.enq(bin[valueOf(n)-1:valueOf(nhalf)]);
      endrule

      rule set_output;
         let valid0 <- toGet(p0.vld).get;
         let valid1 <- toGet(p1.vld).get;
         let bin0 <- toGet(p0.bin).get;
         let bin1 <- toGet(p1.bin).get;
         Bit#(TLog#(n)) output_bin = valid0 ? {1'b0, bin0} : {1'b1, bin1};
         Bool output_vld = boolor(valid0, valid1);
         binpipe.enq(output_bin);
         vldpipe.enq(output_vld);
      endrule

      interface bin = toPipeOut(binpipe);
      interface vld = toPipeOut(vldpipe);
   endmodule
endinstance
