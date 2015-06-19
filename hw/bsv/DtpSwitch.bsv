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

package DtpSwitch;

import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;
import FShow::*;
import Probe::*;
import Pipe::*;
import Ethernet::*;

interface DtpSwitch#(numeric type numPorts);
   interface Vector#(numPorts, PipeIn#(Bit#(53))) dtpLocalIn;
   interface Vector#(numPorts, PipeOut#(Bit#(53))) dtpGlobalOut;
   interface PipeOut#(Bit#(53)) globalOut;
   (* always_ready, always_enabled *)
   method Action switch_mode(Bool v);
endinterface

(* synthesize *)
module mkDtpSwitch(DtpSwitch#(numPorts))
   provisos(Add#(0, numPorts, 4));

   let verbose = True;
   Wire#(Bool) switch_mode_wire <- mkDWire(False);

   Vector#(numPorts, FIFOF#(Bit#(53))) dtpLocalInFifo <- replicateM(mkFIFOF);
   Vector#(numPorts, FIFOF#(Bit#(53))) dtpGlobalOutFifo <- replicateM(mkFIFOF);

   Reg#(Bit#(1))   mode <- mkReg(0); // mode=0 NIC, mode=1 SWITCH
   Reg#(Bit#(32))  cycle   <- mkReg(0);
   Reg#(Bit#(53)) c_global <- mkReg(0);
   Wire#(Bit#(53)) c_global_next <- mkDWire(0);
   FIFOF#(Bit#(53)) globalFifo <- mkSizedFIFOF(1); //export Fifo

   // Stage 1
   Vector#(2, FIFOF#(Bit#(53))) intermediateFifo <- replicateM(mkFIFOF);

   rule cyc;
      cycle <= cycle + 1;
   endrule

   rule set_switch_mode;
      mode <= pack(switch_mode_wire);
   endrule

   for (Integer i=0; i<2; i=i+1) begin
      rule stage1;
         let v0 <- toGet(dtpLocalInFifo[2*i]).get();
         let v1 <- toGet(dtpLocalInFifo[2*i+1]).get();
         //if(verbose) $display("%d: stage 1, group %d, %h %h", cycle, i, v0, v1);
         if (v0 > v1) begin
            intermediateFifo[i].enq(v0+1);
         end
         else begin
            intermediateFifo[i].enq(v1+1);
         end
      endrule
   end

   rule stage2;
      Bit#(53) vo = 0;
      let v0 <- toGet(intermediateFifo[0]).get();
      let v1 <- toGet(intermediateFifo[1]).get();
      if (v0 > v1) begin
         vo = v0;
      end
      else begin
         vo = v1;
      end

      //if(verbose) $display("%d: stage 2, %h %h", cycle, v0, v1);
      for (Integer i=0; i<valueOf(numPorts); i=i+1) begin
         if (mode == 1) begin
            dtpGlobalOutFifo[i].enq(vo+1);
         end
         else begin
            dtpGlobalOutFifo[i].enq(0);
         end
      end
   endrule

   rule export_globalOut;
      globalFifo.enq(c_global);
   endrule

   method Action switch_mode(Bool v);
      switch_mode_wire <= v;
   endmethod

   interface dtpLocalIn = map(toPipeIn,dtpLocalInFifo);
   interface dtpGlobalOut = map(toPipeOut,dtpGlobalOutFifo);
   interface globalOut = toPipeOut(globalFifo);
endmodule

endpackage

