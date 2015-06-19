
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
import FIFO::*;
import FIFOF::*;
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

interface EthPortIfc;
   (* always_ready, always_enabled *)
   interface Vector#(NumPorts, SerialIfc) serial;
   (* always_ready, always_enabled *)
   interface SfpCtrlIfc#(NumPorts) sfpctrl;
   (* always_ready, always_enabled *)
   interface Vector#(NumPorts, Clock) tx_clkout;
   (* always_ready, always_enabled *)
   interface LoopbackIfc loopback;
   (* always_ready, always_enabled *)
   interface SwitchIfc switchctrl;
   interface Vector#(NumPorts, Bool) led_rx_ready;
   interface NetToConnectalIfc api;
endinterface

(* synthesize *)
(* clock_family = "default_clock, clk_156_25" *)
module mkEthPorts#(Clock clk_50, Clock clk_156_25, Clock clk_644)(EthPortIfc);

   let use_mac = True;

   Clock defaultClock <- exposeCurrentClock;
   Reset defaultReset <- exposeCurrentReset;
   Reset rst_50     <- mkAsyncResetFromCR(2, clk_50);
   Reset rst_156_25_n <- mkAsyncReset(2, defaultReset, clk_156_25);

   Reg#(Bit#(128)) cycle <- mkReg(0);
   FIFOF#(Bit#(128)) tsFifo <- mkFIFOF();

//   Vector#(NumPorts, EthPktCtrlIfc) pktctrls <- replicateM(mkEthPktCtrl(clk_156_25, rst_156_25, clocked_by clk_156_25, reset_by rst_156_25));
//
   EthPhyIfc#(NumPorts) phys <- mkEthPhy(clk_50, clk_156_25, clk_644, rst_156_25_n, clocked_by clk_156_25, reset_by rst_156_25_n);

   if (use_mac) begin
      EthMacIfc#(NumPorts) macs <- mkEthMac(clk_50, clk_156_25, phys.rx_clkout, rst_156_25_n, clocked_by clk_156_25, reset_by rst_156_25_n);
      for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
         mkConnection(macs.tx[i], phys.tx[i]);
         mkConnection(phys.rx[i], macs.rx[i]);
      end
   end
   else begin
      for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
         rule source;
            phys.tx[i].enq(72'h83c1e0f0783c1e0f07);
         endrule
         rule drain;
            let v0 <- toGet(phys.rx[i]).get;
         endrule
      end
   end

   // Implement export Timestamp to dtp pipeout;
   rule cyc;
      cycle <= cycle + 1;
   endrule

   rule send_dtp_timestamp;
      tsFifo.enq(cycle);
   endrule

   interface api = (interface NetToConnectalIfc;
      interface timestamp = toPipeOut(tsFifo);
      interface globalOut = phys.globalOut;
      interface phys = phys.api;
   endinterface);

   interface loopback = phys.loopback;
   interface switchctrl = phys.switchctrl;
   interface tx_clkout = phys.tx_clkout;
   interface serial = phys.serial;
   interface led_rx_ready = phys.led_rx_ready;
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

endmodule: mkEthPorts
endpackage: EthPorts
