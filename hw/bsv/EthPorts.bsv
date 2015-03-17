
// Copyright (c) 2014 Cornell University.

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

package EthPorts;

import Clocks::*;
import Vector::*;
import Connectable::*;
import GetPut::*;
import Pipe::*;

import Ethernet::*;
import EthMac::*;
import EthPhy::*;
import EthPktCtrl::*;
import Avalon2ClientServer::*;
import AvalonStreaming::*;

`ifdef NUMBER_OF_10G_PORTS
typedef `NUMBER_OF_10G_PORTS NumPorts;
`else
typedef 4 NumPorts;
`endif

interface SfpCtrlIfc#(numeric type numPorts);
   method Action los(Bit#(numPorts) v);
   method Action mod0_presnt_n(Bit#(numPorts) v);
   // SCL/SDA not implemented
   method Bit#(numPorts) ratesel0();
   method Bit#(numPorts) ratesel1();
   method Bit#(numPorts) txdisable();
   method Action txfault(Bit#(numPorts) v);
endinterface

(* always_ready, always_enabled *)
interface EthPortIfc;
   interface AvalonSlaveIfc#(24) avs;
   interface Vector#(NumPorts, SerialIfc) serial;
   interface SfpCtrlIfc#(NumPorts) sfpctrl;
endinterface

(* synthesize *)
(* clock_family = "default_clock, clk_156_25" *)
module mkEthPorts#(Clock clk_50, Clock clk_156_25, Clock clk_644)(EthPortIfc);
   Clock defaultClock <- exposeCurrentClock;
   Reset defaultReset <- exposeCurrentReset;
   Reset rst_50     <- mkAsyncResetFromCR(2, clk_50);
   Reset rst_156_25_n <- mkAsyncReset(2, defaultReset, clk_156_25);

//   Vector#(NumPorts, EthPktCtrlIfc) pktctrls <- replicateM(mkEthPktCtrl(clk_156_25, rst_156_25, clocked_by clk_156_25, reset_by rst_156_25));
//
   //EthMacIfc#(NumPorts) macs <- mkEthMac(clk_50, clk_156_25, clocked_by clk_156_25, reset_by rst_156_25);
   EthPhyIfc#(NumPorts) phys <- mkEthPhy(clk_50, clk_156_25, clk_644, rst_156_25_n);//, clocked_by clk_156_25, reset_by rst_156_25);

//   for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
//      mkConnection(macs.tx[i], phys.tx[i]);
//      mkConnection(phys.rx[i], macs.rx[i]);
//   end

   rule drain;
      let v0 <- toGet(phys.rx[0]).get;
      let v1 <- toGet(phys.rx[1]).get;
      let v2 <- toGet(phys.rx[2]).get;
      let v3 <- toGet(phys.rx[3]).get;
   endrule

   rule source;
      for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
         if (phys.tx[i].notFull) begin
            phys.tx[i].enq(72'h83c1e0f0783c1e0f07);
         end
      end
   endrule

   interface serial = phys.serial;
   interface sfpctrl = (interface SfpCtrlIfc;
      method Action los (Bit#(NumPorts) v);
      endmethod
      method Action mod0_presnt_n(Bit#(NumPorts) v);
      endmethod
      method Bit#(NumPorts) ratesel0();
         return 4'hf;
      endmethod
      method Bit#(NumPorts) ratesel1();
         return 4'hf;
      endmethod
      method Bit#(NumPorts) txdisable();
         return 4'h0;
      endmethod
      method Action txfault(Bit#(NumPorts) v);
      endmethod
   endinterface);
//   interface avs = pktctrls[0].avs;

endmodule: mkEthPorts
endpackage: EthPorts
