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
import BRAMFIFO::*;
import DefaultValue::*;
import Vector::*;
import BuildVector::*;
import GetPut::*;
import ClientServer::*;
import Connectable::*;
import Clocks::*;
import Gearbox::*;
import Pipe::*;
import GetPutWithClocks::*;
import SpecialFIFOs::*;

`include "ConnectalProjectConfig.bsv"
import MemServerIndication::*;
//import MemMgmt::*;
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
import EthMac::*;
import HostInterface::*;

`ifdef BOARD_de5
import AlteraMacWrap::*;
import AlteraEthPhy::*;
import DE5Pins::*;
`endif

`ifdef BOARD_nfsume
import Xilinx10GE::*;
import XilinxMacWrap::*;
import XilinxEthPhy::*;
import NfsumePins::*;
`endif

`ifdef SIMULATION
import Sims::*;
`endif

import HostChannel::*;
import TxChannel::*;
import RxChannel::*;
import PktGenChannel::*;
import PktCapChannel::*;
import Ingress::*;
import Sims::*;
import PaxosTypes::*;
import ConnectalTypes::*;
import PktGen::*;

interface MemoryTest;
   interface MemoryTestRequest request;
   interface `PinType pins;
endinterface

module mkMemoryTest#(
                    HostInterface host,
                    MemoryTestIndication indication
                    ,ConnectalMemory::MemServerIndication memServerInd
                    )(MemoryTest);
   let verbose = True;

   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

`ifdef SIMULATION
   SimClocks clocks <- mkSimClocks();
   Clock txClock = clocks.clock_156_25;
   Clock phyClock = clocks.clock_644_53;
   Clock mgmtClock = clocks.clock_50;
   Clock rxClock = txClock;
   Reset txReset <- mkSyncReset(2, defaultReset, txClock);
   Reset phyReset <- mkSyncReset(2, defaultReset, phyClock);
   Reset mgmtReset <- mkSyncReset(2, defaultReset, mgmtClock);
   Reset rxReset = txReset;
`endif

   //-------------
   // DE5 MAC+PHY
   //-------------
`ifdef BOARD_de5
   De5Clocks clocks <- mkDe5Clocks();
   Clock txClock = clocks.clock_156_25;
   Clock phyClock = clocks.clock_644_53;
   Clock mgmtClock = clocks.clock_50;
   Reset txReset <- mkSyncReset(2, defaultReset, txClock);
   Reset phyReset <- mkSyncReset(2, defaultReset, phyClock);
   Reset mgmtReset <- mkSyncReset(2, defaultReset, mgmtClock);
   De5Leds leds <- mkDe5Leds(defaultClock, txClock, mgmtClock, phyClock);
   De5SfpCtrl#(4) sfpctrl <- mkDe5SfpCtrl();
   De5Buttons#(4) buttons <- mkDe5Buttons(clocked_by mgmtClock, reset_by mgmtReset);

   // Altera MAC + PHY module
   EthPhyIfc phys <- mkAlteraEthPhy(mgmtClock, phyClock, txClock, defaultReset);
   Clock rxClock = phys.rx_clkout[0];
   Reset rxReset <- mkSyncReset(2, defaultReset, rxClock);
   Vector#(4, EthMacIfc) mac <- replicateM(mkEthMac(mgmtClock, txClock, rxClock, txReset));

   // Connect MAC and PHY
   function Get#(Bit#(72)) getTx(EthMacIfc _mac); return _mac.tx; endfunction
   function Put#(Bit#(72)) getRx(EthMacIfc _mac); return _mac.rx; endfunction
   mapM(uncurry(mkConnection), zip(map(getTx, mac), phys.tx));
   mapM(uncurry(mkConnection), zip(phys.rx, map(getRx, mac)));
`endif

   //----------------
   // NFSUME MAC+PHY
   //----------------
`ifdef BOARD_nfsume
   Clock mgmtClock = host.tsys_clk_200mhz_buf;
   Reset mgmtReset <- mkSyncReset(2, defaultReset, mgmtClock);
   EthPhyIfc phys <- mkXilinxEthPhy(mgmtClock);
   Clock txClock = phys.tx_clkout;
   Reset txReset <- mkSyncReset(2, defaultReset, txClock);
   Clock rxClock = txClock;
   Reset rxReset = txReset;
   Vector#(4, EthMacIfc) mac <- replicateM(mkEthMac(mgmtClock, txClock, txReset, clocked_by txClock, reset_by txReset));
   function Get#(XGMIIData) getTx(EthMacIfc _mac); return _mac.tx; endfunction
   function Put#(XGMIIData) getRx(EthMacIfc _mac); return _mac.rx; endfunction
   mapM(uncurry(mkConnection), zip(map(getTx, mac), phys.tx));
   mapM(uncurry(mkConnection), zip(phys.rx, map(getRx, mac)));
   NfsumeLeds leds <- mkNfsumeLeds(mgmtClock, txClock);
   NfsumeSfpCtrl sfpctrl <- mkNfsumeSfpCtrl(phys);
`endif

   // One P4 Channel
   HostChannel hostchan <- mkHostChannel();
   TxChannel txchan <- mkTxChannel(txClock, txReset);
   RxChannel rxchan <- mkRxChannel(rxClock, rxReset);
   Ingress ingress <- mkIngress(vec(hostchan.next, rxchan.next));

   SharedBuffer#(12, 128, 1) mem <- mkSharedBuffer(vec(txchan.readClient)
                                                  ,vec(txchan.freeClient)
                                                  ,vec(hostchan.writeClient, rxchan.writeClient)
                                                  ,vec(hostchan.mallocClient, rxchan.mallocClient)
                                                  ,memServerInd
                                                  );
   // ingress to one tx channel, could be more
   mkConnection(ingress.next, txchan.prev);

   PktGenChannel pktgen <- mkPktGenChannel(txClock, txReset);
   PktCapChannel pktcap <- mkPktCapChannel(rxClock, rxReset);

`ifdef SIMULATION
   SyncFIFOIfc#(PacketDataT#(64)) recvFifo <- mkSyncFIFO(4, rxClock, rxReset, defaultClock);
   rule drain_mac;
      let v <- toGet(txchan.macTx).get;
      //if (verbose) $display("(%0d) tx data ", $time, fshow(v));
      // NOTE: indication might be a slow path
      recvFifo.enq(v);
      // pktcap is a faster path
      //pktcap.macRx.put(v);
   endrule
   rule writePcap;
      let v <- toGet(recvFifo).get;
      indication.writePacketData(v.data, v.mask, v.sop, v.eop);
   endrule
   rule drain_pktgen;
      let v <- toGet(pktgen.macTx).get;
      if (verbose) $display("(%0d) pktgen data", $time, fshow(v));
      rxchan.macRx.put(v);
   endrule
`else
   // process p0 -> p0
   mkConnection(txchan.macTx, mac[0].packet_tx);
   mkConnection(mac[0].packet_rx, rxchan.macRx);
   // bypass p1 -> p0
   // mkConnectionWithClocks(mac[1].packet_rx, mac[0].packet_tx, rxClock, rxReset, txClock, txReset);
   // pktgen p2
   mkConnection(pktgen.macTx, mac[2].packet_tx);
   // pktcap p3
   mkConnection(mac[3].packet_rx, pktcap.macRx);
`endif

   // Control Interface
   MemoryAPI api <- mkMemoryAPI(indication, hostchan, txchan, rxchan, ingress, pktgen, pktcap);
   interface request = api.request;

`ifdef BOARD_de5
   interface pins = mkDE5Pins(defaultClock, defaultReset, clocks, phys, leds, sfpctrl, buttons);
`endif
`ifdef BOARD_nfsume
   interface pins = mkNfsumePins(defaultClock, phys, leds, sfpctrl);
`endif
endmodule
endpackage
