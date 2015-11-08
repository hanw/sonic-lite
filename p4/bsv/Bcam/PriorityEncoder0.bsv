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
      Reg#(Bit#(1)) binpipe <- mkReg(0);
      Reg#(Bool) vldpipe <- mkReg(False);

      interface Put oht;
         method Action put(Bit#(2) v);
            Bool output_vld = boolor(unpack(v[0]), unpack(v[1]));
            Bit#(1) output_bin = ~v[0];
            binpipe <= output_bin;
            vldpipe <= output_vld;
         endmethod
      endinterface
      interface Get bin;
         method ActionValue#(Bit#(1)) get();
            return binpipe;
         endmethod
      endinterface
      interface Get vld;
         method ActionValue#(Bool) get();
            return vldpipe;
         endmethod
      endinterface
   endmodule
endinstance

//instance PriorityEncoder#(1024);
//   module mkPriorityEncoder(PEnc#(1024));
//      PEnc1024 pe <- mkPriorityEncoder1024();
//      interface Put oht;
//         method Action put(Bit#(1024) v);
//            pe.oht.put(v);
//         endmethod
//      endinterface
//      interface bin = pe.bin;
//      interface vld = pe.vld;
//   endmodule
//endinstance

instance PriorityEncoder#(n)
   provisos (Add#(TDiv#(n, 2), a__, n)
            ,Div#(n, 2, nhalf)
            ,Add#(1, TLog#(nhalf), TLog#(n))
            ,Log#(TDiv#(n, 2), TLog#(nhalf))
            ,PriorityEncoder::PriorityEncoder#(TDiv#(n, 2)));
   module mkPriorityEncoder(PEnc#(n));
      Wire#(Bool) valid0_wire <- mkDWire(False);
      Wire#(Bool) valid1_wire <- mkDWire(False);

      PEnc#(TDiv#(n, 2)) p0 <- mkPriorityEncoder();
      PEnc#(TDiv#(n, 2)) p1 <- mkPriorityEncoder();

      rule set_output;
         let valid0 <- p0.vld.get;
         let valid1 <- p1.vld.get;
         valid0_wire <= valid0;
         valid1_wire <= valid1;
      endrule

      interface Put oht;
         method Action put(Bit#(n) v);
            p0.oht.put(v[valueOf(nhalf)-1:0]);
            p1.oht.put(v[valueOf(n)-1:valueOf(nhalf)]);
         endmethod
      endinterface
      interface Get bin;
         method ActionValue#(Bit#(TLog#(n))) get();
            let bin0 <- p0.bin.get;
            let bin1 <- p1.bin.get;
            Bit#(TLog#(n)) output_bin = valid0_wire ? {1'b0, bin0} : {1'b1, bin1};
            return output_bin;
         endmethod
      endinterface
      interface Get vld;
         method ActionValue#(Bool) get();
            Bool output_vld = boolor(valid0_wire, valid1_wire);
            return output_vld;
         endmethod
      endinterface
   endmodule
endinstance

interface PEnc8;
   interface Put#(Bit#(8)) oht;
   interface Get#(Bit#(3)) bin;
   interface Get#(Bool) vld;
endinterface
(* synthesize *)
module mkPriorityEncoder8(PEnc8);
  Wire#(Bool) valid0_wire <- mkDWire(False);
  Wire#(Bool) valid1_wire <- mkDWire(False);
  PEnc#(4) p0 <- mkPriorityEncoder();
  PEnc#(4) p1 <- mkPriorityEncoder();

  rule set_output;
     let valid0 <- p0.vld.get;
     let valid1 <- p1.vld.get;
     valid0_wire <= valid0;
     valid1_wire <= valid1;
  endrule

  interface Put oht;
     method Action put(Bit#(8) v);
        p0.oht.put(v[3:0]);
        p1.oht.put(v[7:4]);
     endmethod
  endinterface
  interface Get bin;
     method ActionValue#(Bit#(3)) get();
        let bin0 <- p0.bin.get;
        let bin1 <- p1.bin.get;
        Bit#(3) output_bin = valid0_wire ? {1'b0, bin0} : {1'b1, bin1};
        return output_bin;
     endmethod
  endinterface
  interface Get vld;
     method ActionValue#(Bool) get();
        Bool output_vld = boolor(valid0_wire, valid1_wire);
        return output_vld;
     endmethod
  endinterface
endmodule

interface PEnc16;
   interface Put#(Bit#(16)) oht;
   interface Get#(Bit#(4)) bin;
   interface Get#(Bool) vld;
endinterface
(* synthesize *)
module mkPriorityEncoder16(PEnc16);
  Wire#(Bool) valid0_wire <- mkDWire(False);
  Wire#(Bool) valid1_wire <- mkDWire(False);
  PEnc8 p0 <- mkPriorityEncoder8();
  PEnc8 p1 <- mkPriorityEncoder8();

  rule set_output;
     let valid0 <- p0.vld.get;
     let valid1 <- p1.vld.get;
     valid0_wire <= valid0;
     valid1_wire <= valid1;
  endrule

  interface Put oht;
     method Action put(Bit#(16) v);
        p0.oht.put(v[7:0]);
        p1.oht.put(v[15:8]);
     endmethod
  endinterface
  interface Get bin;
     method ActionValue#(Bit#(4)) get();
        let bin0 <- p0.bin.get;
        let bin1 <- p1.bin.get;
        Bit#(4) output_bin = valid0_wire ? {1'b0, bin0} : {1'b1, bin1};
        return output_bin;
     endmethod
  endinterface
  interface Get vld;
     method ActionValue#(Bool) get();
        Bool output_vld = boolor(valid0_wire, valid1_wire);
        return output_vld;
     endmethod
  endinterface

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
  FIFO#(Bit#(16)) p0_infifo <- mkBypassFIFO;
  FIFO#(Bit#(16)) p1_infifo <- mkBypassFIFO;

  Wire#(Bool) valid0_wire <- mkDWire(False);
  Wire#(Bool) valid1_wire <- mkDWire(False);

  PEnc16 p0 <- mkPriorityEncoder16();
  PEnc16 p1 <- mkPriorityEncoder16();

  rule set_output;
     let valid0 <- p0.vld.get;
     let valid1 <- p1.vld.get;
     valid0_wire <= valid0;
     valid1_wire <= valid1;
  endrule

  interface Put oht;
     method Action put(Bit#(32) v);
        p0.oht.put(v[15:0]);
        p1.oht.put(v[31:16]);
     endmethod
  endinterface
  interface Get bin;
     method ActionValue#(Bit#(5)) get();
        let bin0 <- p0.bin.get;
        let bin1 <- p1.bin.get;
        Bit#(5) output_bin = valid0_wire ? {1'b0, bin0} : {1'b1, bin1};
        return output_bin;
     endmethod
  endinterface
  interface Get vld;
     method ActionValue#(Bool) get();
        Bool output_vld = boolor(valid0_wire, valid1_wire);
        return output_vld;
     endmethod
  endinterface
endmodule

