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
   interface Put#(Bit#(n)) oht;
   interface Get#(Bit#(TLog#(n))) bin;
   interface Get#(Bool) vld;
endinterface
typeclass PriorityEncoder#(numeric type n);
   module mkPriorityEncoder(PEnc#(n));
endtypeclass

instance PriorityEncoder#(2);
   module mkPriorityEncoder(PEnc#(2));
      FIFO#(Bit#(1)) binpipe <- mkFIFO;
      FIFO#(Bool) vldpipe <- mkFIFO;

      interface Put oht;
         method Action put(Bit#(2) v);
            Bool output_vld = boolor(unpack(v[0]), unpack(v[1]));
            Bit#(1) output_bin = ~v[0];
            binpipe.enq(output_bin);
            vldpipe.enq(output_vld);
         endmethod
      endinterface
      interface bin = fifoToGet(binpipe);
      interface vld = fifoToGet(vldpipe);
   endmodule
endinstance

instance PriorityEncoder#(1024);
   module mkPriorityEncoder(PEnc#(1024));
      PEnc1024 pe <- mkPriorityEncoder1024();
      interface Put oht;
         method Action put(Bit#(1024) v);
            pe.oht.put(v);
         endmethod
      endinterface
      interface bin = pe.bin;
      interface vld = pe.vld;
   endmodule
endinstance

instance PriorityEncoder#(n)
   provisos (Add#(TDiv#(n, 2), a__, n)
            ,Div#(n, 2, nhalf)
            ,Add#(1, TLog#(nhalf), TLog#(n))
            ,Log#(TDiv#(n, 2), TLog#(nhalf))
            ,PriorityEncoder::PriorityEncoder#(TDiv#(n, 2)));
   module mkPriorityEncoder(PEnc#(n));
      FIFO#(Bit#(TLog#(n))) binpipe <- mkFIFO;
      FIFO#(Bool) vldpipe <- mkFIFO;
      FIFO#(Bit#(nhalf)) p0_infifo <- mkFIFO;
      FIFO#(Bit#(nhalf)) p1_infifo <- mkFIFO;
      FIFOF#(Bit#(n)) oht_fifo <- mkBypassFIFOF;

      PEnc#(TDiv#(n, 2)) p0 <- mkPriorityEncoder();
      PEnc#(TDiv#(n, 2)) p1 <- mkPriorityEncoder();

      rule set_input;
         let bin <- toGet(oht_fifo).get;
         p0.oht.put(bin[valueOf(nhalf)-1:0]);
         p1.oht.put(bin[valueOf(n)-1:valueOf(nhalf)]);
      endrule

      rule set_output;
         let valid0 <- p0.vld.get;
         let valid1 <- p1.vld.get;
         let bin0 <- p0.bin.get;
         let bin1 <- p1.bin.get;
         Bit#(TLog#(n)) output_bin = valid0 ? {1'b0, bin0} : {1'b1, bin1};
         Bool output_vld = boolor(valid0, valid1);
         binpipe.enq(output_bin);
         vldpipe.enq(output_vld);
      endrule

      interface Put oht;
         method Action put(Bit#(n) v);
            oht_fifo.enq(v);
         endmethod
      endinterface
      interface bin = fifoToGet(binpipe);
      interface vld = fifoToGet(vldpipe);
   endmodule
endinstance

interface PEnc8;
   interface Put#(Bit#(8)) oht;
   interface Get#(Bit#(3)) bin;
   interface Get#(Bool) vld;
endinterface
(* synthesize *)
module mkPriorityEncoder8(PEnc8);
  FIFO#(Bit#(TLog#(8))) binpipe <- mkFIFO;
  FIFO#(Bool) vldpipe <- mkFIFO;
  FIFO#(Bit#(4)) p0_infifo <- mkFIFO;
  FIFO#(Bit#(4)) p1_infifo <- mkFIFO;
  FIFOF#(Bit#(8)) oht_fifo <- mkBypassFIFOF;

  PEnc#(4) p0 <- mkPriorityEncoder();
  PEnc#(4) p1 <- mkPriorityEncoder();

  rule set_input;
     let bin <- toGet(oht_fifo).get;
     p0.oht.put(bin[3:0]);
     p1.oht.put(bin[7:4]);
  endrule

  rule set_output;
     let valid0 <- p0.vld.get;
     let valid1 <- p1.vld.get;
     let bin0 <- p0.bin.get;
     let bin1 <- p1.bin.get;
     Bit#(TLog#(8)) output_bin = valid0 ? {1'b0, bin0} : {1'b1, bin1};
     Bool output_vld = boolor(valid0, valid1);
     binpipe.enq(output_bin);
     vldpipe.enq(output_vld);
  endrule

  interface Put oht;
     method Action put(Bit#(8) v);
        oht_fifo.enq(v);
     endmethod
  endinterface
  interface bin = fifoToGet(binpipe);
  interface vld = fifoToGet(vldpipe);
endmodule

interface PEnc16;
   interface Put#(Bit#(16)) oht;
   interface Get#(Bit#(4)) bin;
   interface Get#(Bool) vld;
endinterface
(* synthesize *)
module mkPriorityEncoder16(PEnc16);
  FIFO#(Bit#(TLog#(16))) binpipe <- mkFIFO;
  FIFO#(Bool) vldpipe <- mkFIFO;
  FIFO#(Bit#(8)) p0_infifo <- mkFIFO;
  FIFO#(Bit#(8)) p1_infifo <- mkFIFO;
  FIFOF#(Bit#(16)) oht_fifo <- mkBypassFIFOF;

  PEnc8 p0 <- mkPriorityEncoder8();
  PEnc8 p1 <- mkPriorityEncoder8();

  rule set_input;
     let bin <- toGet(oht_fifo).get;
     p0.oht.put(bin[7:0]);
     p1.oht.put(bin[15:8]);
  endrule

  rule set_output;
     let valid0 <- p0.vld.get;
     let valid1 <- p1.vld.get;
     let bin0 <- p0.bin.get;
     let bin1 <- p1.bin.get;
     Bit#(TLog#(16)) output_bin = valid0 ? {1'b0, bin0} : {1'b1, bin1};
     Bool output_vld = boolor(valid0, valid1);
     binpipe.enq(output_bin);
     vldpipe.enq(output_vld);
  endrule

  interface Put oht;
     method Action put(Bit#(16) v);
        oht_fifo.enq(v);
     endmethod
  endinterface
  interface bin = fifoToGet(binpipe);
  interface vld = fifoToGet(vldpipe);
endmodule

interface PEnc32;
   interface Put#(Bit#(32)) oht;
   interface Get#(Bit#(5)) bin;
   interface Get#(Bool) vld;
endinterface
(* synthesize *)
module mkPriorityEncoder32(PEnc32);
  FIFO#(Bit#(TLog#(32))) binpipe <- mkFIFO;
  FIFO#(Bool) vldpipe <- mkFIFO;
  FIFO#(Bit#(16)) p0_infifo <- mkFIFO;
  FIFO#(Bit#(16)) p1_infifo <- mkFIFO;
  FIFOF#(Bit#(32)) oht_fifo <- mkBypassFIFOF;

  PEnc16 p0 <- mkPriorityEncoder16();
  PEnc16 p1 <- mkPriorityEncoder16();

  rule set_input;
     let bin <- toGet(oht_fifo).get;
     p0.oht.put(bin[15:0]);
     p1.oht.put(bin[31:16]);
  endrule

  rule set_output;
     let valid0 <- p0.vld.get;
     let valid1 <- p1.vld.get;
     let bin0 <- p0.bin.get;
     let bin1 <- p1.bin.get;
     Bit#(TLog#(32)) output_bin = valid0 ? {1'b0, bin0} : {1'b1, bin1};
     Bool output_vld = boolor(valid0, valid1);
     binpipe.enq(output_bin);
     vldpipe.enq(output_vld);
  endrule

  interface Put oht;
     method Action put(Bit#(32) v);
        oht_fifo.enq(v);
     endmethod
  endinterface
  interface bin = fifoToGet(binpipe);
  interface vld = fifoToGet(vldpipe);
endmodule

interface PEnc64;
   interface Put#(Bit#(64)) oht;
   interface Get#(Bit#(6)) bin;
   interface Get#(Bool) vld;
endinterface
(* synthesize *)
module mkPriorityEncoder64(PEnc64);
  FIFO#(Bit#(TLog#(64))) binpipe <- mkFIFO;
  FIFO#(Bool) vldpipe <- mkFIFO;
  FIFO#(Bit#(32)) p0_infifo <- mkFIFO;
  FIFO#(Bit#(32)) p1_infifo <- mkFIFO;
  FIFOF#(Bit#(64)) oht_fifo <- mkBypassFIFOF;

  PEnc32 p0 <- mkPriorityEncoder32();
  PEnc32 p1 <- mkPriorityEncoder32();

  rule set_input;
     let bin <- toGet(oht_fifo).get;
     p0.oht.put(bin[31:0]);
     p1.oht.put(bin[63:32]);
  endrule

  rule set_output;
     let valid0 <- p0.vld.get;
     let valid1 <- p1.vld.get;
     let bin0 <- p0.bin.get;
     let bin1 <- p1.bin.get;
     Bit#(TLog#(64)) output_bin = valid0 ? {1'b0, bin0} : {1'b1, bin1};
     Bool output_vld = boolor(valid0, valid1);
     binpipe.enq(output_bin);
     vldpipe.enq(output_vld);
  endrule

  interface Put oht;
     method Action put(Bit#(64) v);
        oht_fifo.enq(v);
     endmethod
  endinterface
  interface bin = fifoToGet(binpipe);
  interface vld = fifoToGet(vldpipe);
endmodule

interface PEnc128;
   interface Put#(Bit#(128)) oht;
   interface Get#(Bit#(7)) bin;
   interface Get#(Bool) vld;
endinterface
(* synthesize *)
module mkPriorityEncoder128(PEnc128);
  FIFO#(Bit#(TLog#(128))) binpipe <- mkFIFO;
  FIFO#(Bool) vldpipe <- mkFIFO;
  FIFO#(Bit#(64)) p0_infifo <- mkFIFO;
  FIFO#(Bit#(64)) p1_infifo <- mkFIFO;
  FIFOF#(Bit#(128)) oht_fifo <- mkBypassFIFOF;

  PEnc64 p0 <- mkPriorityEncoder64();
  PEnc64 p1 <- mkPriorityEncoder64();

  rule set_input;
     let bin <- toGet(oht_fifo).get;
     p0.oht.put(bin[63:0]);
     p1.oht.put(bin[127:64]);
  endrule

  rule set_output;
     let valid0 <- p0.vld.get;
     let valid1 <- p1.vld.get;
     let bin0 <- p0.bin.get;
     let bin1 <- p1.bin.get;
     Bit#(TLog#(128)) output_bin = valid0 ? {1'b0, bin0} : {1'b1, bin1};
     Bool output_vld = boolor(valid0, valid1);
     binpipe.enq(output_bin);
     vldpipe.enq(output_vld);
  endrule

  interface Put oht;
     method Action put(Bit#(128) v);
        oht_fifo.enq(v);
     endmethod
  endinterface
  interface bin = fifoToGet(binpipe);
  interface vld = fifoToGet(vldpipe);
endmodule

interface PEnc256;
   interface Put#(Bit#(256)) oht;
   interface Get#(Bit#(8)) bin;
   interface Get#(Bool) vld;
endinterface
(* synthesize *)
module mkPriorityEncoder256(PEnc256);
  FIFO#(Bit#(TLog#(256))) binpipe <- mkFIFO;
  FIFO#(Bool) vldpipe <- mkFIFO;
  FIFO#(Bit#(128)) p0_infifo <- mkFIFO;
  FIFO#(Bit#(128)) p1_infifo <- mkFIFO;
  FIFOF#(Bit#(256)) oht_fifo <- mkBypassFIFOF;

  PEnc128 p0 <- mkPriorityEncoder128();
  PEnc128 p1 <- mkPriorityEncoder128();

  rule set_input;
     let bin <- toGet(oht_fifo).get;
     p0.oht.put(bin[127:0]);
     p1.oht.put(bin[255:128]);
  endrule

  rule set_output;
     let valid0 <- p0.vld.get;
     let valid1 <- p1.vld.get;
     let bin0 <- p0.bin.get;
     let bin1 <- p1.bin.get;
     Bit#(TLog#(256)) output_bin = valid0 ? {1'b0, bin0} : {1'b1, bin1};
     Bool output_vld = boolor(valid0, valid1);
     binpipe.enq(output_bin);
     vldpipe.enq(output_vld);
  endrule

  interface Put oht;
     method Action put(Bit#(256) v);
        oht_fifo.enq(v);
     endmethod
  endinterface
  interface bin = fifoToGet(binpipe);
  interface vld = fifoToGet(vldpipe);
endmodule

interface PEnc512;
   interface Put#(Bit#(512)) oht;
   interface Get#(Bit#(9)) bin;
   interface Get#(Bool) vld;
endinterface
(* synthesize *)
module mkPriorityEncoder512(PEnc512);
  FIFO#(Bit#(TLog#(512))) binpipe <- mkFIFO;
  FIFO#(Bool) vldpipe <- mkFIFO;
  FIFO#(Bit#(256)) p0_infifo <- mkFIFO;
  FIFO#(Bit#(256)) p1_infifo <- mkFIFO;
  FIFOF#(Bit#(512)) oht_fifo <- mkBypassFIFOF;

  PEnc256 p0 <- mkPriorityEncoder256();
  PEnc256 p1 <- mkPriorityEncoder256();

  rule set_input;
     let bin <- toGet(oht_fifo).get;
     p0.oht.put(bin[255:0]);
     p1.oht.put(bin[511:256]);
  endrule

  rule set_output;
     let valid0 <- p0.vld.get;
     let valid1 <- p1.vld.get;
     let bin0 <- p0.bin.get;
     let bin1 <- p1.bin.get;
     Bit#(TLog#(512)) output_bin = valid0 ? {1'b0, bin0} : {1'b1, bin1};
     Bool output_vld = boolor(valid0, valid1);
     binpipe.enq(output_bin);
     vldpipe.enq(output_vld);
  endrule

  interface Put oht;
     method Action put(Bit#(512) v);
        oht_fifo.enq(v);
     endmethod
  endinterface
  interface bin = fifoToGet(binpipe);
  interface vld = fifoToGet(vldpipe);
endmodule

interface PEnc1024;
   interface Put#(Bit#(1024)) oht;
   interface Get#(Bit#(10)) bin;
   interface Get#(Bool) vld;
endinterface
(* synthesize *)
module mkPriorityEncoder1024(PEnc1024);
  FIFO#(Bit#(TLog#(1024))) binpipe <- mkFIFO;
  FIFO#(Bool) vldpipe <- mkFIFO;
  FIFO#(Bit#(512)) p0_infifo <- mkFIFO;
  FIFO#(Bit#(512)) p1_infifo <- mkFIFO;
  FIFOF#(Bit#(1024)) oht_fifo <- mkBypassFIFOF;

  PEnc512 p0 <- mkPriorityEncoder512();
  PEnc512 p1 <- mkPriorityEncoder512();

  rule set_input;
     let bin <- toGet(oht_fifo).get;
     p0.oht.put(bin[511:0]);
     p1.oht.put(bin[1023:512]);
  endrule

  rule set_output;
     let valid0 <- p0.vld.get;
     let valid1 <- p1.vld.get;
     let bin0 <- p0.bin.get;
     let bin1 <- p1.bin.get;
     Bit#(TLog#(1024)) output_bin = valid0 ? {1'b0, bin0} : {1'b1, bin1};
     Bool output_vld = boolor(valid0, valid1);
     binpipe.enq(output_bin);
     vldpipe.enq(output_vld);
  endrule

  interface Put oht;
     method Action put(Bit#(1024) v);
        oht_fifo.enq(v);
     endmethod
  endinterface
  interface bin = fifoToGet(binpipe);
  interface vld = fifoToGet(vldpipe);
endmodule

