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

import Arith ::*;
import BuildVector::*;
import ClientServer::*;
import Clocks::*;
import ConfigCounter::*;
import Connectable::*;
import DefaultValue::*;
import FIFO ::*;
import FIFOF ::*;
import GetPut ::*;
import Gearbox ::*;
import Pipe ::*;
import SpecialFIFOs ::*;
import Vector ::*;
import ConnectalConfig::*;

import EthSonicPma::*;
import MemTypes::*;
import MemReadEngine::*;
import MemWriteEngine::*;
import HostInterface::*;
import `PinTypeInclude::*;

import ConnectalClocks::*;
import ALTERA_SI570_WRAPPER::*;
import AlteraExtra::*;
import LedController::*;

interface PmaTestRequest;
   method Action read_version();
endinterface

interface PmaTestTop;
   interface PmaTestRequest request;
   interface `PinType pins;
endinterface

interface PmaTestIndication;
   method Action read_version_resp(Bit#(32)version);
endinterface

module mkPmaTestTop#(PmaTestIndication indication)(PmaTestTop);
   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

   Wire#(Bit#(1)) clk_644_wire <- mkDWire(0);
   Wire#(Bit#(1)) clk_50_wire <- mkDWire(0);

   De5Clocks clocks <- mkDe5Clocks(clk_50_wire, clk_644_wire);
   Clock txClock = clocks.clock_156_25;
   Clock phyClock = clocks.clock_644_53;
   Clock mgmtClock = clocks.clock_50;
   Reset txReset <- mkAsyncReset(2, defaultReset, txClock);
   Reset phyReset <- mkAsyncReset(2, defaultReset, phyClock);
   Reset mgmtReset <- mkAsyncReset(2, defaultReset, mgmtClock);

   De5SfpCtrl#(4) sfpctrl <- mkDe5SfpCtrl();

   EthSonicPma#(4) pma4 <- mkEthSonicPma(mgmtClock, phyClock, txClock, mgmtReset, clocked_by mgmtClock, reset_by mgmtReset);

   for(Integer i=0 ; i < 4 ; i=i+1) begin
      rule rx_pma;
         let v <- toGet(pma4.rx[i]).get;
      endrule

      rule tx_pmac;
         Bit#(66) count = 66'hAAAAA55555AAAAAA;
         pma4.tx[i].enq(count);
      endrule
   end

   interface PmaTestRequest request;
      method Action read_version();
         let v = `DtpVersion; //Defined in Makefile as time of compilation.
         indication.read_version_resp(v);
      endmethod
   endinterface

   interface `PinType pins;
      // Clocks
      method Action osc_50(Bit#(1) b3d, Bit#(1) b4a, Bit#(1) b4d, Bit#(1) b7a, Bit#(1) b7d, Bit#(1) b8a, Bit#(1) b8d);
         clk_50_wire <= b4a;
      endmethod
      method Action sfp(Bit#(1) refclk);
         clk_644_wire <= refclk;
      endmethod
      method serial_tx_data = pma4.serial_tx;
      method serial_rx = pma4.serial_rx;
      interface i2c = clocks.i2c;
      interface sfpctrl = sfpctrl;
      interface deleteme_unused_clock = defaultClock;
      interface deleteme_unused_clock2 = mgmtClock;
      interface deleteme_unused_clock3 = defaultClock;
      interface deleteme_unused_reset = defaultReset;
   endinterface
endmodule
