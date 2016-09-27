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
import PktGen::*;
import StoreAndForward::*;

import Ethernet::*;
import EthPhy::*;
import EthMac::*;
import DtpController::*;
import DtpPktGenAPI::*;
import MemTypes::*;
import MemReadEngine::*;
import MemWriteEngine::*;
import PacketBuffer::*;
import HostInterface::*;
import `PinTypeInclude::*;

import ConnectalClocks::*;
`ifdef SYNTHESIS
import ALTERA_SI570_WRAPPER::*;
import AlteraExtra::*;
`else
import Sims::*;
`endif
import LedController::*;

interface DtpPktGenTop;
   interface DtpRequest request1;
   interface DtpPktGenRequest request2;
   interface `PinType pins;
endinterface

module mkDtpPktGenTop#(DtpIndication indication1, DtpPktGenIndication indication2)(DtpPktGenTop);
   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

   Wire#(Bit#(1)) clk_644_wire <- mkDWire(0);
   Wire#(Bit#(1)) clk_50_wire <- mkDWire(0);

`ifdef SYNTHESIS
   De5Clocks clocks <- mkDe5Clocks();
   De5SfpCtrl#(4) sfpctrl <- mkDe5SfpCtrl();
`else
   SimClocks clocks <- mkSimClocks();
`endif
   Clock txClock = clocks.clock_156_25;
   Clock phyClock = clocks.clock_644_53;
   Clock mgmtClock = clocks.clock_50;

   MakeResetIfc dummyReset <- mkResetSync(0, False, defaultClock);
   Reset txReset <- mkAsyncReset(2, defaultReset, txClock);
   Reset dummyTxReset <- mkAsyncReset(2, dummyReset.new_rst, txClock);
   Reset mgmtReset <- mkAsyncReset(2, defaultReset, mgmtClock);

   DtpController dtpCtrl <- mkDtpController(indication1, txClock, dummyTxReset);
   Reset rst_api <- mkAsyncReset(2, dtpCtrl.ifc.rst, txClock);
   Reset dtp_rst <- mkResetEither(dummyTxReset, rst_api, clocked_by txClock);

   De5Leds leds <- mkDe5Leds(defaultClock, txClock, mgmtClock, phyClock);
   De5Buttons#(4) buttons <- mkDe5Buttons(clocked_by mgmtClock, reset_by mgmtReset);

   DtpPhyIfc dtpPhy <- mkEthPhy(mgmtClock, txClock, phyClock, clocked_by txClock, reset_by dtp_rst);

   Vector#(NumPorts, EthMacIfc) mac ;
   Vector#(NumPorts, PacketBuffer) pkt_buff <- replicateM(mkPacketBuffer(clocked_by txClock, reset_by dtp_rst));
   Vector#(NumPorts, StoreAndFwdFromRingToMac) ringToMac <- replicateM(mkStoreAndFwdFromRingToMac(txClock, dtp_rst, clocked_by txClock, reset_by dtp_rst));
   Vector#(NumPorts, StoreAndFwdFromMacToRing) macToRing;

   Reg#(Bit#(128)) cycle <- mkReg(0, clocked_by txClock, reset_by dtp_rst);
   FIFOF#(Bit#(128)) tsFifo <- mkFIFOF(clocked_by txClock, reset_by dtp_rst);

   for (Integer i = 0 ; i < valueOf(NumPorts) ; i=i+1) begin
      mac[i] <- mkEthMac(mgmtClock, txClock, dtpPhy.phys.rx_clkout[i], dtp_rst, clocked_by txClock, reset_by dtp_rst);
      Reset rx_rst<- mkAsyncReset(2, dtp_rst, dtpPhy.phys.rx_clkout[i]);
      macToRing[i] <- mkStoreAndFwdFromMacToRing(dtpPhy.phys.rx_clkout[i], rx_rst, clocked_by txClock, reset_by dtp_rst);

      // mac and phy
      mkConnection(mac[i].tx, toPut(dtpPhy.phys.tx[i]));
      mkConnection(toGet(dtpPhy.phys.rx[i]), mac[i].rx);
      if (i != 0) begin // port 0 is pkt_gen
         // mac and rx ring
         mkConnection(macToRing[i].macRx, mac[i].packet_rx);
         mkConnection(macToRing[i].writeClient, pkt_buff[i].writeServer);
         // mac and tx ring
         mkConnection(ringToMac[i].macTx, mac[i].packet_tx);
      end
   end

   // between port 0 and port 3
   mkConnection(ringToMac[3].readClient, pkt_buff[3].readServer);
   // between port 1 and port 2
   mkConnection(ringToMac[1].readClient, pkt_buff[2].readServer);
   mkConnection(ringToMac[2].readClient, pkt_buff[1].readServer);

   rule drain_mac0;
      let v <- toGet(mac[0].packet_rx).get;
   endrule

   mkConnection(dtpPhy.api, dtpCtrl.ifc);

   // port 0:Packet Generator
   PktGen pktgen <- mkPktGen(clocked_by txClock, reset_by dtp_rst);
   mkConnection(pktgen.writeClient, pkt_buff[0].writeServer);
   mkConnection(ringToMac[0].readClient, pkt_buff[0].readServer);
   mkConnection(ringToMac[0].macTx, mac[0].packet_tx);

   DtpPktGenAPI api <- mkDtpPktGenAPI(indication2, pktgen, pkt_buff, txClock, dtp_rst);

   // PktGen start/stop
   SyncFIFOIfc#(Tuple2#(Bit#(32),Bit#(32))) pktGenStartSyncFifo <- mkSyncFIFO(4, defaultClock, defaultReset, txClock);
   SyncFIFOIfc#(Bit#(1)) pktGenStopSyncFifo <- mkSyncFIFO(4, defaultClock, defaultReset, txClock);
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

   interface request1 = dtpCtrl.request;
   interface request2 = api.request;

`ifdef SYNTHESIS
   interface pins = mkDE5Pins(defaultClock, defaultReset, clocks, dtpPhy.phys, leds, sfpctrl, buttons);
`endif
endmodule
