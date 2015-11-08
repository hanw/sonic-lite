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
      Vector#(4, Reg#(Bit#(2))) binIR <- replicateM(mkReg(0));
      Vector#(4, PEnc#(4)) pe4_cam <- replicateM(mkPriorityEncoder());
      PEnc#(4) pe4_cam_out0 <- mkPriorityEncoder();

      rule vld_in;
         Bool vldI0 <- pe4_cam[0].vld.get;
         Bool vldI1 <- pe4_cam[1].vld.get;
         Bool vldI2 <- pe4_cam[2].vld.get;
         Bool vldI3 <- pe4_cam[3].vld.get;
         pe4_cam_out0.oht.put({pack(vldI3), pack(vldI2), pack(vldI1), pack(vldI0)});
      endrule

      rule bin_in;
         for (Integer i=0; i<4; i=i+1) begin
            Bit#(2) binI <- pe4_cam[i].bin.get;
            binIR[i] <= binI;
         end
      endrule

      interface Put oht;
         method Action put(Bit#(16) v);
            for (Integer i=0; i<4; i=i+1) begin
               pe4_cam[i].oht.put(v[16*(i+1)/4-1:16*i/4]);
            end
         endmethod
      endinterface
      interface Get bin;
         method ActionValue#(Bit#(4)) get();
            let v <- pe4_cam_out0.bin.get;
            let out = {v, binIR[v]};
            return out;
         endmethod
      endinterface
      interface vld = pe4_cam_out0.vld;
   endmodule
endinstance

instance PriorityEncoder#(64);
   module mkPriorityEncoder(PEnc#(64));
      Vector#(4, Reg#(Bit#(4))) binIR <- replicateM(mkReg(0));
      Vector#(4, PEnc#(16)) pe4_cam <- replicateM(mkPriorityEncoder());
      PEnc#(4) pe4_cam_out0 <- mkPriorityEncoder();

      rule vld_in;
         Bool vldI0 <- pe4_cam[0].vld.get;
         Bool vldI1 <- pe4_cam[1].vld.get;
         Bool vldI2 <- pe4_cam[2].vld.get;
         Bool vldI3 <- pe4_cam[3].vld.get;
         pe4_cam_out0.oht.put({pack(vldI3), pack(vldI2), pack(vldI1), pack(vldI0)});
      endrule

      rule bin_in;
         for (Integer i=0; i<4; i=i+1) begin
            Bit#(4) binI <- pe4_cam[i].bin.get;
            binIR[i] <= binI;
         end
      endrule

      interface Put oht;
         method Action put(Bit#(64) v);
            for (Integer i=0; i<4; i=i+1) begin
               pe4_cam[i].oht.put(v[64*(i+1)/4-1:64*i/4]);
            end
         endmethod
      endinterface
      interface Get bin;
         method ActionValue#(Bit#(6)) get();
            let v <- pe4_cam_out0.bin.get;
            let out = {v, binIR[v]};
            return out;
         endmethod
      endinterface
      interface vld = pe4_cam_out0.vld;
   endmodule
endinstance

instance PriorityEncoder#(256);
   module mkPriorityEncoder(PEnc#(256));
      Vector#(4, Reg#(Bit#(6))) binIR <- replicateM(mkReg(0));

      Vector#(4, PEnc#(64)) pe4_cam <- replicateM(mkPriorityEncoder());
      PEnc#(4) pe4_cam_out0 <- mkPriorityEncoder();

      rule vld_in;
         Bool vldI0 <- pe4_cam[0].vld.get;
         Bool vldI1 <- pe4_cam[1].vld.get;
         Bool vldI2 <- pe4_cam[2].vld.get;
         Bool vldI3 <- pe4_cam[3].vld.get;
         pe4_cam_out0.oht.put({pack(vldI3), pack(vldI2), pack(vldI1), pack(vldI0)});
      endrule

      rule bin_in;
         for (Integer i=0; i<4; i=i+1) begin
            Bit#(6) binI <- pe4_cam[i].bin.get;
            binIR[i] <= binI;
         end
      endrule

      interface Put oht;
         method Action put(Bit#(256) v);
            for (Integer i=0; i<4; i=i+1) begin
               pe4_cam[i].oht.put(v[256*(i+1)/4-1:256*i/4]);
            end
         endmethod
      endinterface
      interface Get bin;
         method ActionValue#(Bit#(8)) get();
            let v <- pe4_cam_out0.bin.get;
            let out = {v, binIR[v]};
            return out;
         endmethod
      endinterface
      interface vld = pe4_cam_out0.vld;
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
   Vector#(4, PEnc#(256)) pe4_cam <- replicateM(mkPriorityEncoder());
   PEnc#(4) pe4_cam_out0 <- mkPriorityEncoder();

   rule vld_in;
      Bool vldI0 <- pe4_cam[0].vld.get;
      Bool vldI1 <- pe4_cam[1].vld.get;
      Bool vldI2 <- pe4_cam[2].vld.get;
      Bool vldI3 <- pe4_cam[3].vld.get;
      pe4_cam_out0.oht.put({pack(vldI3), pack(vldI2), pack(vldI1), pack(vldI0)});
   endrule

   rule bin_in;
      for (Integer i=0; i<4; i=i+1) begin
         Bit#(8) binI <- pe4_cam[i].bin.get;
         binIR[i] <= binI;
      end
   endrule

   interface Put oht;
      method Action put(Bit#(1024) v);
         for (Integer i=0; i<4; i=i+1) begin
            pe4_cam[i].oht.put(v[1024*(i+1)/4-1:1024*i/4]);
         end
      endmethod
   endinterface
   interface Get bin;
      method ActionValue#(Bit#(10)) get();
         let v <- pe4_cam_out0.bin.get;
         let out = {v, binIR[v]};
         return out;
      endmethod
   endinterface
   interface vld = pe4_cam_out0.vld;
endmodule

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

