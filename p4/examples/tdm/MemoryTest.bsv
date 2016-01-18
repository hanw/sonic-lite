// Copyright (c) 2016 Cornell University.

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

package MemoryTest;

import FIFO::*;
import FIFOF::*;
import DefaultValue::*;
import Vector::*;
import BuildVector::*;
import GetPut::*;
import ClientServer::*;
import Connectable::*;
import Clocks::*;
import Gearbox::*;
import Pipe::*;

import MemServerIndication::*;
import MMUIndication::*;
import MemTypes::*;
import Ethernet::*;
import MemoryAPI::*;
import PacketBuffer::*;
import SharedBuff::*;
import StoreAndForward::*;
import PktGen::*;
import TDM::*;
import EthMac::*;
import MMU::*;
import MemMgmt::*;
import IPv4Parser::*;

`ifndef SIMULATION
import AlteraMacWrap::*;
import AlteraEthPhy::*;
import DE5Pins::*;
`else
import Sims::*;
`endif

interface MemoryTest;
   interface MemoryTestRequest request;
   interface `PinType pins;
endinterface

module mkMemoryTest#(MemoryTestIndication indication, MemMgmtIndication memTestInd, ConnectalMemory::MemServerIndication memServerInd, ConnectalMemory::MMUIndication mmuInd)(MemoryTest);
   let verbose = False;

   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

   Wire#(Bit#(1)) clk_644_wire <- mkDWire(0);
   Wire#(Bit#(1)) clk_50_wire <- mkDWire(0);

`ifndef SIMULATION
   De5Clocks clocks <- mkDe5Clocks(clk_50_wire, clk_644_wire);
`else
   SimClocks clocks <- mkSimClocks();
`endif

   Clock txClock = clocks.clock_156_25;
   Clock phyClock = clocks.clock_644_53;
   Clock mgmtClock = clocks.clock_50;
   Reset txReset <- mkSyncReset(2, defaultReset, txClock);
   Reset phyReset <- mkSyncReset(2, defaultReset, phyClock);
   Reset mgmtReset <- mkSyncReset(2, defaultReset, mgmtClock);

`ifndef SIMULATION
   // DE5 Pins
   De5Leds leds <- mkDe5Leds(defaultClock, txClock, mgmtClock, phyClock);
   De5SfpCtrl#(4) sfpctrl <- mkDe5SfpCtrl();
   De5Buttons#(4) buttons <- mkDe5Buttons(clocked_by mgmtClock, reset_by mgmtReset);

   EthPhyIfc phys <- mkAlteraEthPhy(defaultClock, phyClock, txClock, defaultReset);
   Clock rxClock = phys.rx_clkout;
   Reset rxReset <- mkSyncReset(2, defaultReset, rxClock);
   Vector#(4, EthMacIfc) mac <- replicateM(mkEthMac(defaultClock, txClock, rxClock, txReset));

   function Get#(Bit#(72)) getTx(EthMacIfc _mac); return _mac.tx; endfunction
   function Put#(Bit#(72)) getRx(EthMacIfc _mac); return _mac.rx; endfunction
   mapM(uncurry(mkConnection), zip(map(getTx, mac), phys.tx));
   mapM(uncurry(mkConnection), zip(phys.rx, map(getRx, mac)));
`endif

   // Port One
   PktGen pktgen <- mkPktGen();
   PacketBuffer incoming_buff <- mkPacketBuffer();
   PacketBuffer outgoing_buff <- mkPacketBuffer();
   Parser ipv4Parser <- mkParser();
   StoreAndFwdFromRingToMem ingress <- mkStoreAndFwdFromRingToMem(ipv4Parser, memTestInd);
   StoreAndFwdFromMemToRing egress <- mkStoreAndFwdFromMemToRing();
   StoreAndFwdFromRingToMac ringToMac <- mkStoreAndFwdFromRingToMac(txClock, txReset);
   SharedBuffer#(12, 128, 1) mem <- mkSharedBuffer(vec(egress.readClient), vec(ingress.writeClient), memTestInd, memServerInd, mmuInd);


   mkConnection(pktgen.writeClient, incoming_buff.writeServer);
   mkConnection(ingress.readClient, incoming_buff.readServer);
   mkConnection(ingress.mallocReq, mem.mallocReq);
   mkConnection(mem.mallocDone, ingress.mallocDone);
//   mkConnection(egress.writeClient, outgoing_buff.writeServer);
//   mkConnection(ringToMac.readClient, outgoing_buff.readServer);
//   mkConnection(ingress.eventPktCommitted, egress.eventPktSend);

   TDM sched <- mkTDM(ingress, egress);

`ifndef SIMULATION
   mkConnection(ringToMac.macTx, mac[0].packet_tx);
`else
   rule drainMac;
      let v <- ringToMac.macTx.get;
      $display("tx data %h", v.data);
   endrule
`endif

   MemoryAPI api <- mkMemoryAPI(indication, pktgen, mem);

   interface request = api.request;
`ifndef SIMULATION
   interface `PinType pins;
      method Action osc_50(Bit#(1) b3d, Bit#(1) b4a, Bit#(1) b4d, Bit#(1) b7a, Bit#(1) b7d, Bit#(1) b8a, Bit#(1) b8d);
         clk_50_wire <= b4a;
      endmethod
      method serial_tx_data = phys.serial_tx;
      method serial_rx = phys.serial_rx;
      method Action sfp(Bit#(1) refclk);
         clk_644_wire <= refclk;
      endmethod
      interface i2c = clocks.i2c;
      interface led = leds.led_out;
      interface led_bracket = leds.led_out;
      interface sfpctrl = sfpctrl;
      interface buttons = buttons.pins;
      interface deleteme_unused_clock = defaultClock;
      interface deleteme_unused_clock2 = clocks.clock_50;
      interface deleteme_unused_clock3 = defaultClock;
      interface deleteme_unused_reset = defaultReset;
   endinterface
`endif
endmodule
endpackage

