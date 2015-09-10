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
import FIFOF::*;
import SpecialFIFOs::*;
import GetPut::*;
import Connectable::*;

typedef struct {
   Bit#(TLog#(width)) bin;
   Bit#(1) vld;
} PE#(numeric type width) deriving(Bits, Eq);
instance DefaultValue#(PE#(width));
   defaultValue =
   PE {
      bin : 0,
      vld : 0
   };
endinstance

function PE#(4) pe4_cam(Bit#(4) oht);
   PE#(4) pe = defaultValue;
   pe.bin = {~(oht[0] | oht[1]), ~oht[0] & (oht[1] | ~oht[2])};
   pe.vld = |oht;
   return pe;
endfunction

interface PrioEnc#(numeric type width);
   interface PipeIn#(Bit#(width)) oht;
   interface PipeOut#(PE#(width)) pe;
endinterface

module mkPrioEnc16(PrioEnc#(16));

   FIFOF#(Bit#(16)) oht_fifo_in <- mkBypassFIFOF();
   FIFOF#(PE#(16)) pe_fifo_out <- mkBypassFIFOF();

   FIFOF#(Bit#(4)) vld_fifo_s1 <- mkFIFOF();
   Vector#(4, FIFOF#(Bit#(2))) bin_fifo_s1 <- replicateM(mkFIFOF());

   rule pe_s1;
      let v <- toGet(oht_fifo_in).get;
      Vector#(16, Bit#(1)) oht = unpack(v);
      Vector#(4, Bit#(1)) vld = replicate(0);
      Vector#(4, Bit#(4)) val = replicate(0);
      for (Integer i=0; i<4; i=i+1) begin
         PE#(4) pe4 = defaultValue;
         val[i] = pack(takeAt(i*4, oht));
         pe4 = pe4_cam(val[i]);
         bin_fifo_s1[i].enq(pe4.bin);
         vld[i] = pe4.vld;
      end
      vld_fifo_s1.enq(pack(vld));
   endrule

   FIFOF#(Bit#(2)) bin_fifo_s2 <- mkBypassFIFOF();
   FIFOF#(Bit#(2)) bin_fifo_s2_ <- mkBypassFIFOF();
   FIFOF#(Bit#(1)) vld_fifo_s2 <- mkBypassFIFOF();

   rule pe_s2;
      let v <- toGet(vld_fifo_s1).get;
      PE#(4) pe4 = defaultValue;
      pe4 = pe4_cam(v);
      bin_fifo_s2.enq(pe4.bin);
      vld_fifo_s2.enq(pe4.vld);
   endrule

   FIFOF#(Bit#(2)) bin_fifo_s3 <- mkBypassFIFOF();

   rule pe_s3;
      Bit#(2) bin = defaultValue;
      let v <- toGet(bin_fifo_s2).get;
      let bin0 <- toGet(bin_fifo_s1[0]).get;
      let bin1 <- toGet(bin_fifo_s1[1]).get;
      let bin2 <- toGet(bin_fifo_s1[2]).get;
      let bin3 <- toGet(bin_fifo_s1[3]).get;
      case(v) matches
         2'b00: bin = bin0;
         2'b01: bin = bin1;
         2'b10: bin = bin2;
         2'b11: bin = bin3;
      endcase
      bin_fifo_s2_.enq(v);
      bin_fifo_s3.enq(bin);
   endrule

   rule pe_s4;
      let bin0 <- toGet(bin_fifo_s3).get;
      let bin1 <- toGet(bin_fifo_s2_).get;
      let vld <- toGet(vld_fifo_s2).get;
      PE#(16) pe = defaultValue;
      pe.bin = {bin0, bin1};
      pe.vld = vld;
      pe_fifo_out.enq(pe);
   endrule

   interface PipeIn oht = toPipeIn(oht_fifo_in);
   interface PipeOut pe = toPipeOut(pe_fifo_out);
endmodule

module mkPrioEnc64(PrioEnc#(64));

   FIFOF#(Bit#(64)) oht_fifo_in <- mkBypassFIFOF();
   FIFOF#(PE#(64)) pe_fifo_out <- mkBypassFIFOF();

   FIFOF#(Bit#(4)) vld_fifo_s1 <- mkFIFOF();
   Vector#(4, FIFOF#(Bit#(4))) bin_fifo_s1 <- replicateM(mkFIFOF());

   Vector#(4, PrioEnc#(16)) pe16 <- replicateM(mkPE16());
   Vector#(4, FIFOF#(Bit#(16))) pe16_oht_fifo_in <- replicateM(mkBypassFIFOF());
   Vector#(4, FIFOF#(PE#(16))) pe16_fifo_out <- replicateM(mkBypassFIFOF());

   for (Integer i=0; i<4; i=i+1) begin
      mkConnection(toPipeOut(pe16_oht_fifo_in[i]), pe16[i].oht);
      mkConnection(pe16[i].pe, toPipeIn(pe16_fifo_out[i]));
   end

   rule pe_s1;
      let v <- toGet(oht_fifo_in).get;
      Vector#(64, Bit#(1)) oht = unpack(v);
      Vector#(4, Bit#(16)) val = replicate(0);

      for (Integer i=0; i<4; i=i+1) begin
         val[i] = pack(takeAt(i*16, oht));
         pe16_oht_fifo_in[i].enq(val[i]);
      end
   endrule

   rule pe_s11;
      //Vector#(4, PE#(16)) v <- replicateM(defaultValue);
      Vector#(4, Bit#(1)) vld = replicate(0);
      for (Integer i=0; i<4; i=i+1) begin
         let v <- toGet(pe16_fifo_out[i]).get;
         bin_fifo_s1[i].enq(v.bin);
         vld[i] = v.vld;
      end
      vld_fifo_s1.enq(pack(vld));
   endrule

   FIFOF#(Bit#(2)) bin_fifo_s2 <- mkBypassFIFOF();
   FIFOF#(Bit#(2)) bin_fifo_s2_ <- mkBypassFIFOF();
   FIFOF#(Bit#(1)) vld_fifo_s2 <- mkBypassFIFOF();

   rule pe_s2;
      let v <- toGet(vld_fifo_s1).get;
      PE#(4) pe4 = defaultValue;
      pe4 = pe4_cam(v);
      bin_fifo_s2.enq(pe4.bin);
      vld_fifo_s2.enq(pe4.vld);
   endrule

   FIFOF#(Bit#(4)) bin_fifo_s3 <- mkBypassFIFOF();

   rule pe_s3;
      Bit#(4) bin = defaultValue;
      let v <- toGet(bin_fifo_s2).get;
      let bin0 <- toGet(bin_fifo_s1[0]).get;
      let bin1 <- toGet(bin_fifo_s1[1]).get;
      let bin2 <- toGet(bin_fifo_s1[2]).get;
      let bin3 <- toGet(bin_fifo_s1[3]).get;
      case(v) matches
         2'b00: bin = bin0;
         2'b01: bin = bin1;
         2'b10: bin = bin2;
         2'b11: bin = bin3;
      endcase
      bin_fifo_s2_.enq(v);
      bin_fifo_s3.enq(bin);
   endrule

   rule pe_s4;
      let bin0 <- toGet(bin_fifo_s3).get;
      let bin1 <- toGet(bin_fifo_s2_).get;
      let vld <- toGet(vld_fifo_s2).get;
      PE#(64) pe = defaultValue;
      pe.bin = {bin0, bin1};
      pe.vld = vld;
      pe_fifo_out.enq(pe);
   endrule

   interface PipeIn oht = toPipeIn(oht_fifo_in);
   interface PipeOut pe = toPipeOut(pe_fifo_out);
endmodule

module mkPrioEnc256(PrioEnc#(256));

   FIFOF#(Bit#(256)) oht_fifo_in <- mkBypassFIFOF();
   FIFOF#(PE#(256)) pe_fifo_out <- mkBypassFIFOF();

   FIFOF#(Bit#(4)) vld_fifo_s1 <- mkFIFOF();
   Vector#(4, FIFOF#(Bit#(6))) bin_fifo_s1 <- replicateM(mkFIFOF());

   Vector#(4, PrioEnc#(64)) pe64 <- replicateM(mkPE64());
   Vector#(4, FIFOF#(Bit#(64))) pe64_oht_fifo_in <- replicateM(mkBypassFIFOF());
   Vector#(4, FIFOF#(PE#(64))) pe64_fifo_out <- replicateM(mkBypassFIFOF());

   for (Integer i=0; i<4; i=i+1) begin
      mkConnection(toPipeOut(pe64_oht_fifo_in[i]), pe64[i].oht);
      mkConnection(pe64[i].pe, toPipeIn(pe64_fifo_out[i]));
   end

   rule pe_s1;
      let v <- toGet(oht_fifo_in).get;
      Vector#(256, Bit#(1)) oht = unpack(v);
      Vector#(4, Bit#(64)) val = replicate(0);

      for (Integer i=0; i<4; i=i+1) begin
         val[i] = pack(takeAt(i*64, oht));
         pe64_oht_fifo_in[i].enq(val[i]);
      end
   endrule

   rule pe_s11;
      //Vector#(4, PE#(16)) v <- replicateM(defaultValue);
      Vector#(4, Bit#(1)) vld = replicate(0);
      for (Integer i=0; i<4; i=i+1) begin
         let v <- toGet(pe64_fifo_out[i]).get;
         bin_fifo_s1[i].enq(v.bin);
         vld[i] = v.vld;
      end
      vld_fifo_s1.enq(pack(vld));
   endrule

   FIFOF#(Bit#(2)) bin_fifo_s2 <- mkBypassFIFOF();
   FIFOF#(Bit#(2)) bin_fifo_s2_ <- mkBypassFIFOF();
   FIFOF#(Bit#(1)) vld_fifo_s2 <- mkBypassFIFOF();

   rule pe_s2;
      let v <- toGet(vld_fifo_s1).get;
      PE#(4) pe4 = defaultValue;
      pe4 = pe4_cam(v);
      bin_fifo_s2.enq(pe4.bin);
      vld_fifo_s2.enq(pe4.vld);
   endrule

   FIFOF#(Bit#(6)) bin_fifo_s3 <- mkBypassFIFOF();

   rule pe_s3;
      Bit#(6) bin = defaultValue;
      let v <- toGet(bin_fifo_s2).get;
      let bin0 <- toGet(bin_fifo_s1[0]).get;
      let bin1 <- toGet(bin_fifo_s1[1]).get;
      let bin2 <- toGet(bin_fifo_s1[2]).get;
      let bin3 <- toGet(bin_fifo_s1[3]).get;
      case(v) matches
         2'b00: bin = bin0;
         2'b01: bin = bin1;
         2'b10: bin = bin2;
         2'b11: bin = bin3;
      endcase
      bin_fifo_s2_.enq(v);
      bin_fifo_s3.enq(bin);
   endrule

   rule pe_s4;
      let bin0 <- toGet(bin_fifo_s3).get;
      let bin1 <- toGet(bin_fifo_s2_).get;
      let vld <- toGet(vld_fifo_s2).get;
      PE#(256) pe = defaultValue;
      pe.bin = {bin0, bin1};
      pe.vld = vld;
      pe_fifo_out.enq(pe);
   endrule

   interface PipeIn oht = toPipeIn(oht_fifo_in);
   interface PipeOut pe = toPipeOut(pe_fifo_out);
endmodule

module mkPrioEnc1024(PrioEnc#(1024));

   FIFOF#(Bit#(1024)) oht_fifo_in <- mkBypassFIFOF();
   FIFOF#(PE#(1024)) pe_fifo_out <- mkBypassFIFOF();

   FIFOF#(Bit#(4)) vld_fifo_s1 <- mkFIFOF();
   Vector#(4, FIFOF#(Bit#(8))) bin_fifo_s1 <- replicateM(mkFIFOF());

   Vector#(4, PrioEnc#(256)) pe64 <- replicateM(mkPE256());
   Vector#(4, FIFOF#(Bit#(256))) pe64_oht_fifo_in <- replicateM(mkBypassFIFOF());
   Vector#(4, FIFOF#(PE#(256))) pe64_fifo_out <- replicateM(mkBypassFIFOF());

   for (Integer i=0; i<4; i=i+1) begin
      mkConnection(toPipeOut(pe64_oht_fifo_in[i]), pe64[i].oht);
      mkConnection(pe64[i].pe, toPipeIn(pe64_fifo_out[i]));
   end

   rule pe_s1;
      let v <- toGet(oht_fifo_in).get;
      Vector#(1024, Bit#(1)) oht = unpack(v);
      Vector#(4, Bit#(256)) val = replicate(0);

      for (Integer i=0; i<4; i=i+1) begin
         val[i] = pack(takeAt(i*256, oht));
         pe64_oht_fifo_in[i].enq(val[i]);
      end
   endrule

   rule pe_s11;
      //Vector#(4, PE#(16)) v <- replicateM(defaultValue);
      Vector#(4, Bit#(1)) vld = replicate(0);
      for (Integer i=0; i<4; i=i+1) begin
         let v <- toGet(pe64_fifo_out[i]).get;
         bin_fifo_s1[i].enq(v.bin);
         vld[i] = v.vld;
      end
      vld_fifo_s1.enq(pack(vld));
   endrule

   FIFOF#(Bit#(2)) bin_fifo_s2 <- mkBypassFIFOF();
   FIFOF#(Bit#(2)) bin_fifo_s2_ <- mkBypassFIFOF();
   FIFOF#(Bit#(1)) vld_fifo_s2 <- mkBypassFIFOF();

   rule pe_s2;
      let v <- toGet(vld_fifo_s1).get;
      PE#(4) pe4 = defaultValue;
      pe4 = pe4_cam(v);
      bin_fifo_s2.enq(pe4.bin);
      vld_fifo_s2.enq(pe4.vld);
   endrule

   FIFOF#(Bit#(8)) bin_fifo_s3 <- mkBypassFIFOF();

   rule pe_s3;
      Bit#(8) bin = defaultValue;
      let v <- toGet(bin_fifo_s2).get;
      let bin0 <- toGet(bin_fifo_s1[0]).get;
      let bin1 <- toGet(bin_fifo_s1[1]).get;
      let bin2 <- toGet(bin_fifo_s1[2]).get;
      let bin3 <- toGet(bin_fifo_s1[3]).get;
      case(v) matches
         2'b00: bin = bin0;
         2'b01: bin = bin1;
         2'b10: bin = bin2;
         2'b11: bin = bin3;
      endcase
      bin_fifo_s2_.enq(v);
      bin_fifo_s3.enq(bin);
   endrule

   rule pe_s4;
      let bin0 <- toGet(bin_fifo_s3).get;
      let bin1 <- toGet(bin_fifo_s2_).get;
      let vld <- toGet(vld_fifo_s2).get;
      PE#(1024) pe = defaultValue;
      pe.bin = {bin0, bin1};
      pe.vld = vld;
      pe_fifo_out.enq(pe);
   endrule

   interface PipeIn oht = toPipeIn(oht_fifo_in);
   interface PipeOut pe = toPipeOut(pe_fifo_out);
endmodule

(* synthesize *)
module mkPE16(PrioEnc#(16));
   PrioEnc#(16) _a <- mkPrioEnc16(); return _a;
endmodule

(* synthesize *)
module mkPE64(PrioEnc#(64));
   PrioEnc#(64) _a <- mkPrioEnc64(); return _a;
endmodule

(* synthesize *)
module mkPE256(PrioEnc#(256));
   PrioEnc#(256) _a <- mkPrioEnc256(); return _a;
endmodule

(* synthesize *)
module mkPE1024(PrioEnc#(1024));
   PrioEnc#(1024) _a <- mkPrioEnc1024(); return _a;
endmodule

(* synthesize *)
module mkPE32(PrioEnc#(32));
   FIFOF#(Bit#(32)) oht_fifo_in <- mkFIFOF();
   FIFOF#(PE#(32)) pe_fifo_out <- mkFIFOF();

   PrioEnc#(64) _a <- mkPrioEnc64();

   rule convert;
      let v <- toGet(_a.pe).get;
      PE#(32) pe = defaultValue;
      pe.bin = v.bin[4:0];
      pe.vld = v.vld;
      pe_fifo_out.enq(pe);
   endrule

   rule convert2;
      let v <- toGet(oht_fifo_in).get;
      Bit#(64) val = {32'b0, v};
      _a.oht.enq(val);
   endrule

   interface PipeIn oht = toPipeIn(oht_fifo_in);
   interface PipeOut pe = toPipeOut(pe_fifo_out);
endmodule
