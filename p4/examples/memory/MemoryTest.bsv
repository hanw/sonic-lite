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
import MemMgmt::*;
`ifdef DEBUG
import MemMgmtIndication::*;
import MMUIndication::*;
`endif
import MemTypes::*;
import Ethernet::*;
import MemoryAPI::*;
import PacketBuffer::*;
import SharedBuff::*;
import StoreAndForward::*;
import DbgTypes::*;

`ifdef SYNTHESIS
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

module mkMemoryTest#(MemoryTestIndication indication
                    ,ConnectalMemory::MemServerIndication memServerIndication
`ifdef DEBUG
                    ,MemMgmtIndication memTestInd
                    ,ConnectalMemory::MMUIndication mmuInd
`endif
                    )(MemoryTest);
   let verbose = False;

   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

   Wire#(Bit#(1)) clk_644_wire <- mkDWire(0);
   Wire#(Bit#(1)) clk_50_wire <- mkDWire(0);

`ifdef SYNTHESIS
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

`ifdef SYNTHESIS
   // DE5 Pins
   De5Leds leds <- mkDe5Leds(defaultClock, txClock, mgmtClock, phyClock);
   De5SfpCtrl#(4) sfpctrl <- mkDe5SfpCtrl();
   De5Buttons#(4) buttons <- mkDe5Buttons(clocked_by mgmtClock, reset_by mgmtReset);

   EthPhyIfc phys <- mkAlteraEthPhy(mgmtClock, phyClock, txClock, defaultReset);
   Clock rxClock = phys.rx_clkout;
   Reset rxReset <- mkSyncReset(2, defaultReset, rxClock);
   Vector#(4, EthMacIfc) mac <- replicateM(mkEthMac(mgmtClock, txClock, rxClock, txReset));

   function Get#(Bit#(72)) getTx(EthMacIfc _mac); return _mac.tx; endfunction
   function Put#(Bit#(72)) getRx(EthMacIfc _mac); return _mac.rx; endfunction
   mapM(uncurry(mkConnection), zip(map(getTx, mac), phys.tx));
   mapM(uncurry(mkConnection), zip(phys.rx, map(getRx, mac)));
`endif

   PacketBuffer incoming_buff <- mkPacketBuffer();
   StoreAndFwdFromRingToMem ringToMem <- mkStoreAndFwdFromRingToMem(
`ifdef DEBUG
                                                                    memTestInd
`endif
                                                                   );

   PacketBuffer outgoing_buff <- mkPacketBuffer();
   StoreAndFwdFromMemToRing memToRing <- mkStoreAndFwdFromMemToRing();

   SharedBuffer#(12, 128, 1) mem <- mkSharedBuffer(vec(memToRing.readClient)
                                                  ,vec(memToRing.free)
                                                  ,vec(ringToMem.writeClient)
                                                  ,vec(ringToMem.malloc)
                                                  ,memServerIndication
`ifdef DEBUG
                                                  ,memTestInd
                                                  ,mmuInd
`endif
                                                  );

   mkConnection(ringToMem.readClient, incoming_buff.readServer);
   mkConnection(memToRing.writeClient, outgoing_buff.writeServer);
   mkConnection(ringToMem.eventPktCommitted, memToRing.eventPktSend);

   StoreAndFwdFromRingToMac ringToMac <- mkStoreAndFwdFromRingToMac(txClock, txReset);
   mkConnection(ringToMac.readClient, outgoing_buff.readServer);

`ifdef SYNTHESIS
   mkConnection(ringToMac.macTx, mac[0].packet_tx);
`else
   rule drain_mac;
      let v <- toGet(ringToMac.macTx).get;
      if (verbose) $display("memory::MemoryTest:: tx data %h", v);
   endrule
`endif

   MemoryAPI api <- mkMemoryAPI(indication, incoming_buff);

   interface request = api.request;
`ifdef BOARD_de5
   interface pins = mkDE5Pins(defaultClock, defaultReset, clocks, phys, leds, sfpctrl, buttons);
`endif
endmodule
endpackage

