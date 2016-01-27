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

import NetTop::*;
import EthPorts::*;
import Ethernet::*;
import EthPhy::*;
import EthMac::*;
import DtpController::*;
import PacketBuffer::*;
import DtpPktGenAPI::*;
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

   De5Clocks clocks <- mkDe5Clocks(clk_50_wire, clk_644_wire);
   Clock txClock = clocks.clock_156_25;
   Clock phyClock = clocks.clock_644_53;
   Clock mgmtClock = clocks.clock_50;
   Reset txReset <- mkSyncReset(2, defaultReset, txClock);
   Reset phyReset <- mkSyncReset(2, defaultReset, phyClock);
   Reset mgmtReset <- mkSyncReset(2, defaultReset, mgmtClock);

   De5SfpCtrl#(4) sfpctrl <- mkDe5SfpCtrl();

   DtpController dtp <- mkDtpController(indication1, txClock, txReset, clocked_by defaultClock);

   Reset rst_api <- mkSyncReset(0, dtp.ifc.rst, txClock);
   Reset dtp_rst <- mkResetEither(txReset, rst_api, clocked_by txClock);

//   NetTopIfc net <- mkNetTop(mgmtClock, txClock, phyClock, clocked_by txClock, reset_by dtp_rst);
   DtpPhyIfc#(4) phys <- mkEthPhy(mgmtClock, txClock, phyClock, clocked_by txClock, reset_by dtp_rst);

   Vector#(NumPorts, EthMacIfc) mac ;
   Vector#(NumPorts, FIFOF#(Bit#(72))) macToPhy <- replicateM(mkFIFOF, clocked_by txClock, reset_by dtp_rst);
   Vector#(NumPorts, FIFOF#(Bit#(72))) phyToMac;// <- replicateM(mkFIFOF, clocked_by txClock);

   Reg#(Bit#(128)) cycle <- mkReg(0, clocked_by txClock, reset_by dtp_rst);
   FIFOF#(Bit#(128)) tsFifo <- mkFIFOF(clocked_by txClock, reset_by dtp_rst);

   for (Integer i = 0 ; i < valueOf(NumPorts) ; i=i+1) begin
      mac[i] <- mkEthMac(mgmtClock, txClock, phys.rx_clkout[i], dtp_rst, clocked_by txClock, reset_by dtp_rst);

      mkConnection(mac[i].tx, toPut(phys.tx[i]));
      mkConnection(toGet(phys.rx[i]), mac[i].rx);
   end

   rule cyc;
      cycle <= cycle + 1;
   endrule

   rule send_dtp_timestamp; 
      tsFifo.enq(cycle);
   endrule

   // Connecting DTP request/indication and DTP-PHY looks ugly
   mkConnection(toPipeOut(tsFifo), dtp.ifc.timestamp);
   mkConnection(phys.globalOut, dtp.ifc.globalOut);
   mkConnection(dtp.ifc.switchMode, phys.switchMode);
   for (Integer i=0; i<4; i=i+1) begin
      mkConnection(dtp.ifc.fromHost[i], phys.api[i].fromHost);
      mkConnection(phys.api[i].toHost, dtp.ifc.toHost[i]);
      mkConnection(phys.api[i].delayOut, dtp.ifc.delay[i]);
      mkConnection(phys.api[i].stateOut, dtp.ifc.state[i]);
      mkConnection(phys.api[i].jumpCount, dtp.ifc.jumpCount[i]);
      mkConnection(phys.api[i].cLocalOut, dtp.ifc.cLocal[i]);
      mkConnection(dtp.ifc.interval[i], phys.api[i].interval);
      mkConnection(phys.api[i].dtpErrCnt, dtp.ifc.dtpErrCnt[i]);
      mkConnection(phys.tx_dbg[i], dtp.ifc.txPcsDbg[i]);
      mkConnection(phys.rx_dbg[i], dtp.ifc.rxPcsDbg[i]);
   end

   // Packet Generator
   PktGen pktgen <- mkPktGen(clocked_by txClock, reset_by dtp_rst);
   PacketBuffer pkt_buff <- mkPacketBuffer(clocked_by txClock, reset_by dtp_rst);
   StoreAndFwdFromRingToMac ringToMac <- mkStoreAndFwdFromRingToMac(txClock, dtp_rst, clocked_by txClock, reset_by dtp_rst);

   mkConnection(pktgen.writeClient, pkt_buff.writeServer);
   mkConnection(ringToMac.readClient, pkt_buff.readServer);
   mkConnection(ringToMac.macTx, mac[0].packet_tx);

   rule drain_mac_rx;
      let v <- toGet(mac[0].packet_rx).get;
   endrule

   DtpPktGenAPI api <- mkDtpPktGenAPI(indication2, pktgen);

   // PktGen start/stop
   SyncFIFOIfc#(Tuple2#(Bit#(32),Bit#(32))) pktGenStartSyncFifo <- mkSyncFIFO(4, defaultClock, defaultReset, txClock);
   SyncFIFOIfc#(void) pktGenStopSyncFifo <- mkSyncFIFO(4, defaultClock, defaultReset, txClock);
   SyncFIFOIfc#(EtherData) pktGenWriteSyncFifo <- mkSyncFIFO(4, defaultClock, defaultReset, txClock);
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

   interface request1 = dtp.request;
   interface request2 = api.request;

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
      interface deleteme_unused_clock2 = mgmtClock;
      interface deleteme_unused_clock3 = defaultClock;
      interface deleteme_unused_reset = defaultReset;
   endinterface
endmodule
