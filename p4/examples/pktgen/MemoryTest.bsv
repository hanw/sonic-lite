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

`ifndef SIMULATION
import AlteraMacWrap::*;
import EthMac::*;
import AlteraEthPhy::*;
import DE5Pins::*;
`else
import Sims::*;
`endif

interface MemoryTest;
   interface MemoryTestRequest request;
   interface `PinType pins;
endinterface

module mkMemoryTest#(MemoryTestIndication indication, ConnectalMemory::MemServerIndication memServerIndication)(MemoryTest);
   let verbose = False;

   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

`ifndef SIMULATION
   De5Clocks clocks <- mkDe5Clocks();
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
   Clock rxClock = phys.rx_clkout[0];
   Reset rxReset <- mkSyncReset(2, defaultReset, rxClock);
   Vector#(4, EthMacIfc) mac <- replicateM(mkEthMac(defaultClock, txClock, rxClock, txReset));

   function Get#(Bit#(72)) getTx(EthMacIfc _mac); return _mac.tx; endfunction
   function Put#(Bit#(72)) getRx(EthMacIfc _mac); return _mac.rx; endfunction
   mapM(uncurry(mkConnection), zip(map(getTx, mac), phys.tx));
   mapM(uncurry(mkConnection), zip(phys.rx, map(getRx, mac)));
`endif

   PktGen pktgen <- mkPktGen();

`ifndef SIMULATION
   PacketBuffer outgoing_buff <- mkPacketBuffer();
   StoreAndFwdFromMemToRing memToRing <- mkStoreAndFwdFromMemToRing();

   mkConnection(memToRing.writeClient, outgoing_buff.writeServer);

   StoreAndFwdFromRingToMac ringToMac <- mkStoreAndFwdFromRingToMac(txClock, txReset);
   mkConnection(ringToMac.readClient, outgoing_buff.readServer);
   mkConnection(ringToMac.macTx, mac[0].packet_tx);
`else
   rule drain_pktgen;
      let v <- pktgen.writeClient.writeData.get;
      if (verbose) $display("pktgen::MemoryTest:: tx data", fshow(v));
   endrule
`endif

   MemoryAPI api <- mkMemoryAPI(indication, pktgen);

   interface request = api.request;
`ifdef BOARD_de5
   interface pins = mkDE5Pins(defaultClock, defaultReset, clocks, phys, leds, sfpctrl, buttons);
`endif
endmodule
endpackage

