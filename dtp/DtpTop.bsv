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

import NetTop::*;
import EthPorts::*;
import Ethernet::*;
import DtpController::*;
import MemTypes::*;
import MemReadEngine::*;
import MemWriteEngine::*;
import PacketBuffer::*;
import HostInterface::*;
import `PinTypeInclude::*;

import ConnectalClocks::*;
import ALTERA_SI570_WRAPPER::*;
import AlteraExtra::*;
import LedController::*;

interface DtpTop;
   interface DtpRequest request;
   interface `PinType pins;
endinterface

module mkDtpTop#(DtpIndication indication)(DtpTop);
   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

   Wire#(Bit#(1)) clk_644_wire <- mkDWire(0);
   Wire#(Bit#(1)) clk_50_wire <- mkDWire(0);

   De5Clocks clocks <- mkDe5Clocks(clk_50_wire, clk_644_wire);
   Clock txClock = clocks.clock_156_25;
   Clock phyClock = clocks.clock_644_53;
   Clock clock_50 = clocks.clock_50;
   Reset txReset <- mkSyncReset(1, defaultReset, txClock);
   Reset phyReset <- mkSyncReset(2, defaultReset, phyClock);

   De5SfpCtrl#(4) sfpctrl <- mkDe5SfpCtrl();

`ifndef SIMULATION
   DtpController dtp <- mkDtpController(indication, txClock, txReset, clocked_by defaultClock);

   Reset rst_api <- mkSyncReset(0, dtp.ifc.rst, txClock);
   Reset dtp_rst <- mkResetEither(txReset, rst_api, clocked_by txClock);

   NetTopIfc net <- mkNetTop(clock_50, txClock, phyClock, clocked_by txClock, reset_by dtp_rst);

   // Connecting DTP request/indication and DTP-PHY looks ugly
   mkConnection(net.api.timestamp, dtp.ifc.timestamp);
   mkConnection(net.api.globalOut, dtp.ifc.globalOut);
   mkConnection(dtp.ifc.switchMode, net.api.switchMode);
   for (Integer i=0; i<4; i=i+1) begin
      mkConnection(dtp.ifc.fromHost[i], net.api.phys[i].fromHost);
      mkConnection(net.api.phys[i].toHost, dtp.ifc.toHost[i]);
      mkConnection(net.api.phys[i].delayOut, dtp.ifc.delay[i]);
      mkConnection(net.api.phys[i].stateOut, dtp.ifc.state[i]);
      mkConnection(net.api.phys[i].jumpCount, dtp.ifc.jumpCount[i]);
      mkConnection(net.api.phys[i].cLocalOut, dtp.ifc.cLocal[i]);
      mkConnection(dtp.ifc.interval[i], net.api.phys[i].interval);
      mkConnection(net.api.phys[i].dtpErrCnt, dtp.ifc.dtpErrCnt[i]);
   end
`endif // SIMULATION

   interface request = dtp.request;

   interface `PinType pins;
      // Clocks
`ifndef SIMULATION
      method Action osc_50(Bit#(1) b3d, Bit#(1) b4a, Bit#(1) b4d, Bit#(1) b7a, Bit#(1) b7d, Bit#(1) b8a, Bit#(1) b8d);
         clk_50_wire <= b4a;
      endmethod
      method Action sfp(Bit#(1) refclk);
         clk_644_wire <= refclk;
      endmethod
`ifdef DEBUG_ETH
      method serial_tx_data = net.ifcs.serial_tx;
      method serial_rx = net.ifcs.serial_rx;
      interface i2c = clocks.i2c;
      interface sfpctrl = sfpctrl;
`endif  // DEBUG_ETH
      interface deleteme_unused_clock = defaultClock;
      interface deleteme_unused_clock2 = clock_50;
      interface deleteme_unused_clock3 = defaultClock;
      interface deleteme_unused_reset = defaultReset;
`endif // SIMULATION
   endinterface
endmodule
