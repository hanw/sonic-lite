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
import Vector            :: *;
import Clocks            :: *;
import GetPut            :: *;
import FIFO              :: *;
import LedTop ::*;
import NetTop ::*;
import ALTERA_SI570_WRAPPER          ::*;

(* always_ready, always_enabled *)
interface PinsTopIfc;
   (* prefix="" *)
   interface NetExportIfc eth;
   (* prefix="i2c" *)
   interface Si570wrapI2c i2c;
   interface Bit#(1) led0;
   interface Bit#(1) led1;
   interface Bit#(1) led2;
   interface Bit#(1) led3;
   interface Bit#(4) led_bracket;
   (* prefix="" *)
   interface ButtonInIfc buttons;
   interface Clock clk_b4a;
endinterface

interface ButtonInIfc;
   method Action button0(Bit#(1) v);
   method Action button1(Bit#(1) v);
   method Action button2(Bit#(1) v);
   method Action button3(Bit#(1) v);
endinterface

interface ButtonOutIfc;
   method Bit#(1) getButton0();
   method Bit#(1) getButton1();
   method Bit#(1) getButton2();
   method Bit#(1) getButton3();
endinterface

interface ButtonIfc;
   interface ButtonOutIfc out;
   interface ButtonInIfc  in;
endinterface

module mkButton(ButtonIfc);
   Vector#(4, Wire#(Bit#(1))) buttons <- replicateM(mkDWire(0));

   interface out = (interface ButtonOutIfc;
      method Bit#(1) getButton0();
         return buttons[0];
      endmethod
      method Bit#(1) getButton1();
         return buttons[1];
      endmethod
      method Bit#(1) getButton2();
         return buttons[2];
      endmethod
      method Bit#(1) getButton3();
         return buttons[3];
      endmethod
   endinterface);

   interface in = (interface ButtonInIfc;
      method Action button0 (Bit#(1) v);
         buttons[0] <= v;
      endmethod
      method Action button1 (Bit#(1) v);
         buttons[1] <= v;
      endmethod
      method Action button2 (Bit#(1) v);
         buttons[2] <= v;
      endmethod
      method Action button3 (Bit#(1) v);
         buttons[3] <= v;
      endmethod
   endinterface);
endmodule

