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
import LedController::*;
import Xilinx10GE::*;

import HostInterface::*;
import ConnectalXilinxCells::*;
import Pipe::*;
import MemTypes::*;
import Ethernet::*;
import PacketBuffer::*;
import XilinxMacWrap::*;
import XilinxEthPhy::*;
import EthMac::*;
import StoreAndForward::*;
import NfsumePins::*;
import DbgTypes::*;

interface TestIndication;
   method Action read_version_resp(Bit#(32) version);
   method Action readRingBuffCntrsResp(Bit#(64) sopEnq, Bit#(64) eopEnq, Bit#(64) sopDeq, Bit#(64) eopDeq);
   method Action readTxThruCntrsResp(Bit#(64) goodputCount, Bit#(64) idleCount);
   method Action readRxCycleCntResp(Bit#(64) p0_cycle_cnt, Bit#(64) p1_cycle_cnt);
endinterface

interface TestRequest;
   method Action read_version();
   method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
   method Action readRingBuffCntrs(Bit#(8) id);
   method Action readTxThruCntrs();
   method Action readRxCycleCnt();
endinterface

interface Test;
   interface TestRequest request;
   interface `PinType pins;
endinterface

module mkTest#(HostInterface host, TestIndication indication) (Test);
   let verbose = True;
   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

   Clock mgmtClock = host.tsys_clk_200mhz_buf;
   Reset mgmtReset <- mkSyncReset(2, defaultReset, mgmtClock);

   // Synthesis
`ifndef SIMULATION
   EthPhyIfc phys <- mkXilinxEthPhy(mgmtClock);
   Clock txClock = phys.tx_clkout;
   Reset txReset <- mkSyncReset(2, defaultReset, txClock);
   Vector#(4, EthMacIfc) mac <- replicateM(mkEthMac(mgmtClock, txClock, txReset, clocked_by txClock, reset_by txReset));
   function Get#(XGMIIData) getTx(EthMacIfc _mac); return _mac.tx; endfunction
   function Put#(XGMIIData) getRx(EthMacIfc _mac); return _mac.rx; endfunction
   mapM(uncurry(mkConnection), zip(map(getTx, mac), phys.tx));
   mapM(uncurry(mkConnection), zip(phys.rx, map(getRx, mac)));
   NfsumeLeds leds <- mkNfsumeLeds(mgmtClock, txClock);
   NfsumeSfpCtrl sfpctrl <- mkNfsumeSfpCtrl(phys);
`endif

   // Simulation
`ifdef SIMULATION
   Clock txClock = defaultClock;
   Reset txReset <- mkSyncReset(2, defaultReset, txClock);
   Vector#(4, EthMacIfc) mac <- replicateM(mkEthMac(mgmtClock, txClock, txReset, clocked_by txClock, reset_by txReset));
   mkConnection(mac[0].tx, mac[1].rx);
   mkConnection(mac[1].tx, mac[0].rx);
`endif

   Reg#(Bit#(64)) p0_cycle_cnt <- mkReg(0, clocked_by txClock, reset_by txReset);
   Reg#(Bit#(64)) p1_cycle_cnt <- mkReg(0, clocked_by txClock, reset_by txReset);
   ReadOnly#(Bit#(64)) p0_crossed <- mkNullCrossingWire(defaultClock, p0_cycle_cnt);
   ReadOnly#(Bit#(64)) p1_crossed <- mkNullCrossingWire(defaultClock, p1_cycle_cnt);

   PacketBuffer buff <- mkPacketBuffer();
   StoreAndFwdFromRingToMac ringToMac <- mkStoreAndFwdFromRingToMac(txClock, txReset);
   mkConnection(ringToMac.readClient, buff.readServer);
   mkConnection(ringToMac.macTx, mac[0].packet_tx);

   rule rx_packet0;
      let v <- toGet(mac[0].packet_rx).get;
      p0_cycle_cnt <= p0_cycle_cnt + 1;
      mac[1].packet_tx.put(v);
   endrule

   rule rx_packet1;
      let v <- toGet(mac[1].packet_rx).get;
      p1_cycle_cnt <= p1_cycle_cnt + 1;
      mac[0].packet_tx.put(v);
      $display("rx1: v=", fshow(v));
   endrule

   interface TestRequest request;
      method Action read_version();
         let v= `NicVersion;
         indication.read_version_resp(v);
      endmethod
      method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
         EtherData beat = defaultValue;
         beat.data = pack(reverse(data));
         beat.mask = pack(reverse(mask));
         beat.sop = unpack(sop);
         beat.eop = unpack(eop);
         buff.writeServer.writeData.put(beat);
      endmethod
      method Action readRingBuffCntrs(Bit#(8) id);
         let v = buff.dbg();
         indication.readRingBuffCntrsResp(v.sopEnq, v.eopEnq, v.sopDeq, v.eopDeq);
      endmethod
      method Action readTxThruCntrs();
         let v = ringToMac.dbg();
         indication.readTxThruCntrsResp(v.goodputCount, v.idleCount);
      endmethod
      method Action readRxCycleCnt();
         indication.readRxCycleCntResp(p0_crossed, p1_crossed);
      endmethod
   endinterface
`ifndef SIMULATION
   interface `PinType pins;
      method Action sfp(Bit#(1) refclk_p, Bit#(1) refclk_n);
         phys.refclk(refclk_p, refclk_n);
      endmethod
      method serial_tx_p = pack(phys.serial_tx_p);
      method serial_tx_n = pack(phys.serial_tx_n);
      method serial_rx_p = phys.serial_rx_p;
      method serial_rx_n = phys.serial_rx_n;
      interface leds = leds.led_out;
      interface led_grn = phys.tx_leds;
      interface led_ylw = phys.rx_leds;
      interface deleteme_unused_clock = defaultClock;
      interface sfpctrl = sfpctrl;
   endinterface
`endif
endmodule

