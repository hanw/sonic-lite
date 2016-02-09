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

import HostInterface::*;
import ConnectalXilinxCells::*;
import Pipe::*;
import MemTypes::*;
import Ethernet::*;
import PacketBuffer::*;
import XilinxMacWrap::*;
import EthMac::*;
import StoreAndForward::*;
import NfsumePins::*;

interface TestIndication;
   method Action done(Bit#(32) matchCount);
endinterface

interface TestRequest;
   method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
endinterface

interface Test;
   interface TestRequest request;
   interface `PinType pins;
endinterface

module mkTest#(HostInterface host, TestIndication indication) (Test);
   let verbose = True;
   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();
   Wire#(Bit#(1)) sfp_refclk_p_w <- mkDWire(0);
   Wire#(Bit#(1)) sfp_refclk_n_w <- mkDWire(0);

   Clock txClock <- mkConnectalClockIBUFDS_GTE2(True, sfp_refclk_p_w, sfp_refclk_n_w);
   Clock mgmtClock = host.tsys_clk_200mhz_buf;

   Reset txReset <- mkSyncReset(2, defaultReset, txClock);
   Reset mgmtReset <- mkSyncReset(2, defaultReset, mgmtClock);

   Reg#(Bit#(32)) cycle <- mkReg(0, clocked_by txClock, reset_by txReset);

`ifndef SIMULATION
   NfsumeLeds leds <- mkNfsumeLeds(mgmtClock, txClock);
   //De5SfpCtrl#(4) sfpctrl <- mkDe5SfpCtrl();
   //De5Buttons#(4) buttons <- mkDe5Buttons(clocked_by mgmtClock, reset_by mgmtReset);

   //EthPhyIfc phys <- mkAlteraEthPhy(mgmtClock, phyClock, txClock, defaultReset);
//   Clock rxClock = phys.rx_clkout;
//   Reset rxReset <- mkSyncReset(2, defaultReset, rxClock);
//   Vector#(4, EthMacIfc) mac <- replicateM(mkEthMac(mgmtClock, txClock, rxClock, txReset, clocked_by txClock, reset_by txReset));
   Vector#(4, EthMacIfc) mac <- replicateM(mkEthMac(defaultClock, txClock, txClock, txReset, clocked_by txClock, reset_by txReset));

//   function Get#(Bit#(72)) getTx(EthMacIfc _mac); return _mac.tx; endfunction
//   function Put#(Bit#(72)) getRx(EthMacIfc _mac); return _mac.rx; endfunction
//   mapM(uncurry(mkConnection), zip(map(getTx, mac), phys.tx));
//   mapM(uncurry(mkConnection), zip(phys.rx, map(getRx, mac)));
`endif

   PacketBuffer buff <- mkPacketBuffer();
   StoreAndFwdFromRingToMac ringToMac <- mkStoreAndFwdFromRingToMac(txClock, txReset);
   mkConnection(ringToMac.readClient, buff.readServer);
   mkConnection(ringToMac.macTx, mac[0].packet_tx);

   interface TestRequest request;
      method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
         EtherData beat = defaultValue;
         beat.data = pack(reverse(data));
         beat.mask = pack(reverse(mask));
         beat.sop = unpack(sop);
         beat.eop = unpack(eop);
         buff.writeServer.writeData.put(beat);
      endmethod
   endinterface
`ifndef SIMULATION
   interface `PinType pins;
      method Action sfp(Bit#(1) refclk_p, Bit#(1) refclk_n);
         sfp_refclk_p_w <= refclk_p;
         sfp_refclk_n_w <= refclk_n;
      endmethod
//      method serial_tx_data = phys.serial_tx;
//      method serial_rx = phys.serial_rx;
      interface leds = leds.led_out;
//      interface sfpctrl = sfpctrl;
//      interface buttons = buttons.pins;
      interface deleteme_unused_clock = defaultClock;
//      interface deleteme_unused_clock2 = clocks.clock_50;
//      interface deleteme_unused_clock3 = defaultClock;
//      interface deleteme_unused_reset = defaultReset;
   endinterface
`endif
endmodule

