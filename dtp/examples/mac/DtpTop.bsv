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
import EthPhy::*;
import EthMac::*;
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

interface DummyIndication;
   method Action read_version_resp(Bit#(32) version);
endinterface

interface DummyRequest;
   method Action read_version();
endinterface

interface DtpTop;
   interface DummyRequest request;
   interface `PinType pins;
endinterface

module mkDtpTop#(DummyIndication indication)(DtpTop);
   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

   Wire#(Bit#(1)) clk_644_wire <- mkDWire(0);
   Wire#(Bit#(1)) clk_50_wire <- mkDWire(0);

   De5Clocks clocks <- mkDe5Clocks(clk_50_wire, clk_644_wire);
   Clock txClock = clocks.clock_156_25;
   Clock phyClock = clocks.clock_644_53;
   Clock clock_50 = clocks.clock_50;
   Reset txReset <- mkSyncReset(2, defaultReset, txClock);
   Reset phyReset <- mkSyncReset(2, defaultReset, phyClock);

   De5SfpCtrl#(4) sfpctrl <- mkDe5SfpCtrl();

   EthPhyIfc#(NumPorts) phys <- mkEthPhy(clock_50, txClock, phyClock, clocked_by txClock, reset_by txReset);

   Clock rxClock = phys.rx_clkout[0];

   function Clock getRxClock (Vector#(N, Clock) clocks, i);
      return clocks[i];
   endfunction

   Vector#(NumPorts, EthMacIfc) mac ;
   Vector#(NumPorts, FIFOF#(Bit#(72))) macToPhy <- replicateM(mkFIFOF, clocked_by txClock, reset_by txReset);
   Vector#(NumPorts, FIFOF#(Bit#(72))) phyToMac;// <- replicateM(mkFIFOF, clocked_by txClock);
   for (Integer i = 0 ; i < valueOf(NumPorts) ; i=i+1) begin
      mac[i] <- mkEthMac(defaultClock, txClock, phys.rx_clkout[i], txReset);
      Reset rx_rst<- mkSyncReset(2, defaultReset, phys.rx_clkout[i]);
      phyToMac[i] <- mkFIFOF(clocked_by phys.rx_clkout[i], reset_by rx_rst);

      mkConnection(toPipeOut(macToPhy[i]), phys.tx[i]);
      mkConnection(phys.rx[i], toPipeIn(phyToMac[i]));

      rule mac_phy_tx;
         macToPhy[i].enq(mac[i].tx);
      endrule

      rule mac_phy_rx;
         let v = phyToMac[i].first;
         mac[i].rx(v);
         phyToMac[i].deq;
      endrule
   end

   interface DummyRequest request;
      method Action read_version();
         let v=`DtpVersion;
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
      method serial_tx_data = phys.serial_tx;
      method serial_rx = phys.serial_rx;
      interface i2c = clocks.i2c;
      interface sfpctrl = sfpctrl;
      interface deleteme_unused_clock = defaultClock;
      interface deleteme_unused_clock2 = clock_50;
      interface deleteme_unused_clock3 = defaultClock;
      interface deleteme_unused_reset = defaultReset;
   endinterface
endmodule
