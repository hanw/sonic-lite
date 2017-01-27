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

import BRAMFIFO::*;
import FIFO::*;
import FIFOF::*;
import DefaultValue::*;
import DbgDefs::*;
import Vector::*;
import BuildVector::*;
import GetPut::*;
import ClientServer::*;
import Connectable::*;
import Clocks::*;
import RegFile::*;

import Ethernet::*;
import EthMac::*;
import MemServerIndication::*;
`ifdef DEBUG
import MMUIndication::*;
`endif
import MemTypes::*;
import MemoryAPI::*;
import MemMgmt::*;
import PacketBuffer::*;
import PktGen::*;
import TdmPipeline::*;
import TdmTypes::*;

`ifdef SYNTHESIS
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

module mkMemoryTest#(MemoryTestIndication indication
                   ,ConnectalMemory::MemServerIndication memServerInd
`ifdef DEBUG
                   ,MemMgmtIndication memTestInd
                   ,ConnectalMemory::MMUIndication mmuInd
`endif
                   )(MemoryTest);
   let verbose = True;

   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

`ifdef SYNTHESIS
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

`ifdef SYNTHESIS
   // DE5 Pins
   De5Leds leds <- mkDe5Leds(defaultClock, txClock, mgmtClock, phyClock);
   De5SfpCtrl#(4) sfpctrl <- mkDe5SfpCtrl();
   De5Buttons#(4) buttons <- mkDe5Buttons(clocked_by mgmtClock, reset_by mgmtReset);

   EthPhyIfc phys <- mkAlteraEthPhy(mgmtClock, phyClock, txClock, defaultReset);
   Clock rxClock = phys.rx_clkout;
   Reset rxReset <- mkSyncReset(2, defaultReset, rxClock);
   Vector#(4, EthMacIfc) mac <- replicateM(mkEthMac(mgmtClock, txClock, rxClock, txReset, clocked_by txClock, reset_by txReset));

   function Get#(Bit#(72)) getTx(EthMacIfc _mac); return _mac.tx; endfunction
   function Put#(Bit#(72)) getRx(EthMacIfc _mac); return _mac.rx; endfunction
   mapM(uncurry(mkConnection), zip(map(getTx, mac), phys.tx));
   mapM(uncurry(mkConnection), zip(phys.rx, map(getRx, mac)));
`else
   Clock rxClock = txClock;
   Reset rxReset = txReset;
`endif

   // Host Packet Generator
   PktGen pktgen <- mkPktGen(clocked_by txClock, reset_by txReset);
   SyncFIFOIfc#(ByteStream#(16)) txSyncFifo <- mkSyncBRAMFIFO(6, txClock, txReset, defaultClock, defaultReset);

   TdmPipeline tdm <- mkTdmPipeline(txClock, txReset
                                 ,rxClock, rxReset
                                 ,indication
                                 ,memServerInd
`ifdef DEBUG 
                                 ,memTestInd
                                 ,mmuInd
`endif
                                 );

   function PktWriteServer genWriteServer = (interface PktWriteServer;
      interface writeData = toPut(txSyncFifo);
   endinterface);
   function PktWriteClient genWriteClient = (interface PktWriteClient;
      interface writeData = toGet(txSyncFifo);
   endinterface);
   mkConnection(pktgen.writeClient, genWriteServer);
   mkConnection(genWriteClient, tdm.writeServer);

   // connect mac to tdm
`ifdef SYNTHESIS
   mkConnection(tdm.macTx, mac[0].packet_tx);
   mkConnection(mac[0].packet_rx, tdm.macRx);
`else
   rule drainMac;
      let v <- tdm.macTx.get;
      if (verbose) $display("tx data %h", v.data);
   endrule
`endif

   MemoryAPI api <- mkMemoryAPI(indication, tdm);

   // PktGen start/stop
   SyncFIFOIfc#(Tuple2#(Bit#(32),Bit#(32))) pktGenStartSyncFifo <- mkSyncFIFO(4, defaultClock, defaultReset, txClock);
   SyncFIFOIfc#(void) pktGenStopSyncFifo <- mkSyncFIFO(4, defaultClock, defaultReset, txClock);
   SyncFIFOIfc#(ByteStream#(16)) pktGenWriteSyncFifo <- mkSyncFIFO(4, defaultClock, defaultReset, txClock);
   mkConnection(api.pktGenStart, toPut(pktGenStartSyncFifo));
   mkConnection(api.pktGenStop, toPut(pktGenStopSyncFifo));
   mkConnection(api.pktGenWrite, toPut(pktGenWriteSyncFifo));
   rule req_start;
      let v <- toGet(pktGenStartSyncFifo).get;
      pktgen.start(tpl_1(v), tpl_2(v));
   endrule

   rule req_stop;
      let v <- toGet(pktGenStopSyncFifo).get;
      pktgen.stop();
   endrule

   rule req_write;
      let v <- toGet(pktGenWriteSyncFifo).get;
      pktgen.writeServer.writeData.put(v);
   endrule

   interface request = api.request;
`ifdef BOARD_de5
   interface pins = mkDE5Pins(defaultClock, defaultReset, clocks, phys, leds, sfpctrl, buttons);
`endif
endmodule
endpackage

