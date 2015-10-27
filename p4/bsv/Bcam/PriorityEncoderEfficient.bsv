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

instance PriorityEncoder#(4);
   module mkPriorityEncoder(PEnc#(4));
      FIFO#(Bit#(2)) binpipe <- mkFIFO1;
      FIFO#(Bool) vldpipe <- mkFIFO1;

      interface Put oht;
         method Action put(Bit#(4) v);
            Bool output_vld = unpack(v[0]) || unpack(v[1]) || unpack(v[2]) || unpack(v[3]);
            Bit#(2) output_bin = {pack(!(unpack(v[0])||unpack(v[1]))), pack(!unpack(v[0]) && (unpack(v[1])||!unpack(v[2])))};
            binpipe.enq(output_bin);
            vldpipe.enq(output_vld);
         endmethod
      endinterface
      interface bin = fifoToGet(binpipe);
      interface vld = fifoToGet(vldpipe);
   endmodule
endinstance

instance PriorityEncoder#(16);
   module mkPriorityEncoder(PEnc#(16));
      Vector#(4, Wire#(Bit#(2))) binIR <- replicateM(mkDWire(0));
      FIFO#(Bool) vldpipe <- mkFIFO1;
      FIFO#(Bit#(4)) binpipe <- mkFIFO1;

      Vector#(4, PEnc#(4)) pe4_cam <- replicateM(mkPriorityEncoder());
      PEnc#(4) pe4_cam_out0 <- mkPriorityEncoder();

      rule bin_in;
         Bool vldI0 <- pe4_cam[0].vld.get;
         Bool vldI1 <- pe4_cam[1].vld.get;
         Bool vldI2 <- pe4_cam[2].vld.get;
         Bool vldI3 <- pe4_cam[3].vld.get;
         for (Integer i=0; i<4; i=i+1) begin
            Bit#(2) binI <- pe4_cam[i].bin.get;
            binIR[i] <= binI;
         end
         pe4_cam_out0.oht.put({pack(vldI3), pack(vldI2), pack(vldI1), pack(vldI0)});
      endrule

      rule vld_out;
         let v <- pe4_cam_out0.vld.get;
         vldpipe.enq(v);
      endrule

      rule bin_out;
         let v <- pe4_cam_out0.bin.get;
         binpipe.enq({v, binIR[v]});
      endrule

      interface Put oht;
         method Action put(Bit#(16) v);
            for (Integer i=0; i<4; i=i+1) begin
               pe4_cam[i].oht.put(v[16*(i+1)/4-1:16*i/4]);
            end
         endmethod
      endinterface
      interface bin = fifoToGet(binpipe);
      interface vld = fifoToGet(vldpipe);
   endmodule
endinstance

instance PriorityEncoder#(64);
   module mkPriorityEncoder(PEnc#(64));
      Vector#(4, Wire#(Bit#(4))) binIR <- replicateM(mkDWire(0));
      FIFO#(Bool) vldpipe <- mkFIFO1;
      FIFO#(Bit#(6)) binpipe <- mkFIFO1;

      Vector#(4, PEnc#(16)) pe4_cam <- replicateM(mkPriorityEncoder());
      PEnc#(4) pe4_cam_out0 <- mkPriorityEncoder();

      rule bin_in;
         Bool vldI0 <- pe4_cam[0].vld.get;
         Bool vldI1 <- pe4_cam[1].vld.get;
         Bool vldI2 <- pe4_cam[2].vld.get;
         Bool vldI3 <- pe4_cam[3].vld.get;
         for (Integer i=0; i<4; i=i+1) begin
            Bit#(4) binI <- pe4_cam[i].bin.get;
            binIR[i] <= binI;
         end
         pe4_cam_out0.oht.put({pack(vldI3), pack(vldI2), pack(vldI1), pack(vldI0)});
      endrule

      rule vld_out;
         let v <- pe4_cam_out0.vld.get;
         vldpipe.enq(v);
      endrule

      rule bin_out;
         let v <- pe4_cam_out0.bin.get;
         binpipe.enq({v, binIR[v]});
      endrule

      interface Put oht;
         method Action put(Bit#(64) v);
            for (Integer i=0; i<4; i=i+1) begin
               pe4_cam[i].oht.put(v[64*(i+1)/4-1:64*i/4]);
            end
         endmethod
      endinterface
      interface bin = fifoToGet(binpipe);
      interface vld = fifoToGet(vldpipe);
   endmodule
endinstance

instance PriorityEncoder#(256);
   module mkPriorityEncoder(PEnc#(256));
      Vector#(4, Wire#(Bit#(6))) binIR <- replicateM(mkDWire(0));
      FIFO#(Bool) vldpipe <- mkFIFO1;
      FIFO#(Bit#(8)) binpipe <- mkFIFO1;

      Vector#(4, PEnc#(64)) pe4_cam <- replicateM(mkPriorityEncoder());
      PEnc#(4) pe4_cam_out0 <- mkPriorityEncoder();

      rule bin_in;
         Bool vldI0 <- pe4_cam[0].vld.get;
         Bool vldI1 <- pe4_cam[1].vld.get;
         Bool vldI2 <- pe4_cam[2].vld.get;
         Bool vldI3 <- pe4_cam[3].vld.get;
         for (Integer i=0; i<4; i=i+1) begin
            Bit#(6) binI <- pe4_cam[i].bin.get;
            binIR[i] <= binI;
         end
         pe4_cam_out0.oht.put({pack(vldI3), pack(vldI2), pack(vldI1), pack(vldI0)});
      endrule

      rule vld_out;
         let v <- pe4_cam_out0.vld.get;
         vldpipe.enq(v);
      endrule

      rule bin_out;
         let v <- pe4_cam_out0.bin.get;
         binpipe.enq({v, binIR[v]});
      endrule

      interface Put oht;
         method Action put(Bit#(256) v);
            for (Integer i=0; i<4; i=i+1) begin
               pe4_cam[i].oht.put(v[256*(i+1)/4-1:256*i/4]);
            end
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

interface PEnc1024;
   interface Put#(Bit#(1024)) oht;
   interface Get#(Bit#(10)) bin;
   interface Get#(Bool) vld;
endinterface
(* synthesize *)
module mkPriorityEncoder1024(PEnc1024);
   Vector#(4, Reg#(Bit#(8))) binIR <- replicateM(mkReg(0));
   FIFO#(Bool) vldpipe <- mkFIFO1;
   FIFO#(Bit#(10)) binpipe <- mkFIFO1;

   Vector#(4, PEnc#(256)) pe4_cam <- replicateM(mkPriorityEncoder());
   PEnc#(4) pe4_cam_out0 <- mkPriorityEncoder();

   rule bin_in;
      Bool vldI0 <- pe4_cam[0].vld.get;
      Bool vldI1 <- pe4_cam[1].vld.get;
      Bool vldI2 <- pe4_cam[2].vld.get;
      Bool vldI3 <- pe4_cam[3].vld.get;
      for (Integer i=0; i<4; i=i+1) begin
         Bit#(8) binI <- pe4_cam[i].bin.get;
         binIR[i] <= binI;
      end
      pe4_cam_out0.oht.put({pack(vldI3), pack(vldI2), pack(vldI1), pack(vldI0)});
   endrule

   rule vld_out;
      let v <- pe4_cam_out0.vld.get;
      vldpipe.enq(v);
   endrule

   rule bin_out;
      let v <- pe4_cam_out0.bin.get;
      binpipe.enq({v, binIR[v]});
   endrule

   interface Put oht;
      method Action put(Bit#(1024) v);
         for (Integer i=0; i<4; i=i+1) begin
            pe4_cam[i].oht.put(v[1024*(i+1)/4-1:1024*i/4]);
         end
      endmethod
   endinterface
   interface bin = fifoToGet(binpipe);
   interface vld = fifoToGet(vldpipe);
endmodule

// Should never be used.. not efficient
instance PriorityEncoder#(2);
   module mkPriorityEncoder(PEnc#(2));
      FIFO#(Bit#(1)) binpipe <- mkFIFO1;
      FIFO#(Bool) vldpipe <- mkFIFO1;

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

//instance PriorityEncoder#(n)
//   provisos (Add#(TDiv#(n, 2), a__, n)
//            ,Div#(n, 2, nhalf)
//            ,Add#(1, TLog#(nhalf), TLog#(n))
//            ,Log#(TDiv#(n, 2), TLog#(nhalf))
//            ,PriorityEncoder#(TDiv#(n, 2)));
//   module mkPriorityEncoder(PEnc#(n));
//      FIFO#(Bit#(TLog#(n))) binpipe <- mkFIFO1;
//      FIFO#(Bool) vldpipe <- mkFIFO1;
//      FIFO#(Bit#(nhalf)) p0_infifo <- mkFIFO1;
//      FIFO#(Bit#(nhalf)) p1_infifo <- mkFIFO1;
//      FIFOF#(Bit#(n)) oht_fifo <- mkBypassFIFOF;
//
//      PEnc#(TDiv#(n, 2)) p0 <- mkPriorityEncoder();
//      PEnc#(TDiv#(n, 2)) p1 <- mkPriorityEncoder();
//
//      rule set_input;
//         let bin <- toGet(oht_fifo).get;
//         p0.oht.put(bin[valueOf(nhalf)-1:0]);
//         p1.oht.put(bin[valueOf(n)-1:valueOf(nhalf)]);
//      endrule
//
//      rule set_output;
//         let valid0 <- p0.vld.get;
//         let valid1 <- p1.vld.get;
//         let bin0 <- p0.bin.get;
//         let bin1 <- p1.bin.get;
//         Bit#(TLog#(n)) output_bin = valid0 ? {1'b0, bin0} : {1'b1, bin1};
//         Bool output_vld = boolor(valid0, valid1);
//         binpipe.enq(output_bin);
//         vldpipe.enq(output_vld);
//      endrule
//
//      interface Put oht;
//         method Action put(Bit#(n) v);
//            oht_fifo.enq(v);
//         endmethod
//      endinterface
//      interface bin = fifoToGet(binpipe);
//      interface vld = fifoToGet(vldpipe);
//   endmodule
//endinstance
//
//
