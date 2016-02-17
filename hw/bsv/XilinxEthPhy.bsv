
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

package XilinxEthPhy;

import Clocks::*;
import Vector::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Connectable::*;
import GetPut::*;
import Pipe::*;
import XilinxPhyWrap::*; 

(*always_ready, always_enabled*)
interface EthPhyIfc;
   interface Vector#(4, Put#(Bit#(72))) tx;
   interface Vector#(4, Get#(Bit#(72))) rx;
   method Vector#(4, Bit#(1)) serial_tx_p;
   method Vector#(4, Bit#(1)) serial_tx_n;
   method Action serial_rx_p(Vector#(4, Bit#(1)) v);
   method Action serial_rx_n(Vector#(4, Bit#(1)) v);
   interface Vector#(4, Clock) rx_clkout;
   interface Clock tx_clkout;
   method Action refclk(Bit#(1) p, Bit#(1) n);
endinterface

module mkXilinxEthPhy#(Clock mgmtClock)(EthPhyIfc);
   Vector#(4, FIFOF#(Bit#(72))) txFifo = newVector;
   Vector#(4, FIFOF#(Bit#(72))) rxFifo = newVector;
   Vector#(4, Clock) rxClocks = newVector;
   Clock defaultClock <- exposeCurrentClock;
   Reset defaultReset <- exposeCurrentReset;

   PhyWrapShared phy0 <- mkPhyWrapShared(mgmtClock);
   Clock clk_156_25 = phy0.coreclk;

   Wire#(Bit#(1)) qplllock_w <- mkDWire(0);
   Wire#(Bit#(1)) qplloutclk_w <- mkDWire(0);
   Wire#(Bit#(1)) qplloutrefclk_w <- mkDWire(0);
   Wire#(Bit#(1)) txusrclk_w <- mkDWire(0);
   Wire#(Bit#(1)) txusrclk2_w <- mkDWire(0);
   Wire#(Bit#(1)) txuserrdy_w <- mkDWire(0);
   Wire#(Bit#(1)) gtrxreset_w <- mkDWire(0);
   Wire#(Bit#(1)) gttxreset_w <- mkDWire(0);
   Wire#(Bit#(1)) reset_counter_done_w <- mkDWire(0);

   Reset invertedReset <- mkResetInverter(defaultReset, clocked_by defaultClock);
   PhyWrapNonShared phy1 <- mkPhyWrapNonShared(clk_156_25, mgmtClock, invertedReset, invertedReset);
   PhyWrapNonShared phy2 <- mkPhyWrapNonShared(clk_156_25, mgmtClock, invertedReset, invertedReset);
   PhyWrapNonShared phy3 <- mkPhyWrapNonShared(clk_156_25, mgmtClock, invertedReset, invertedReset);

   rule phy0_qplllock;
      qplllock_w <= phy0.qplllock_out();
   endrule

   rule phyx_qplllock;
      phy1.qplllock(qplllock_w);
      phy2.qplllock(qplllock_w);
      phy3.qplllock(qplllock_w);
   endrule

   rule phy0_qplloutclk;
      qplloutclk_w <= phy0.qplloutclk_out();
   endrule

   rule phyx_qplloutclk;
      phy1.qplloutclk(qplloutclk_w);
      phy2.qplloutclk(qplloutclk_w);
      phy3.qplloutclk(qplloutclk_w);
   endrule

   rule phy0_qplloutrefclk;
      qplloutrefclk_w <= phy0.qplloutrefclk_out();
   endrule

   rule phyx_qplloutrefclk;
      phy1.qplloutrefclk(qplloutrefclk_w);
      phy2.qplloutrefclk(qplloutrefclk_w);
      phy3.qplloutrefclk(qplloutrefclk_w);
   endrule

   rule phy0_txusrclk;
      txusrclk_w <= phy0.txusrclk_out();
   endrule

   rule phyx_txusrclk;
      phy1.txusrclk(txusrclk_w);
      phy2.txusrclk(txusrclk_w);
      phy3.txusrclk(txusrclk_w);
   endrule

   rule phy0_txusrclk2;
      txusrclk2_w <= phy0.txusrclk2_out();
   endrule

   rule phyx_txusrclk2;
      phy1.txusrclk2(txusrclk2_w);
      phy2.txusrclk2(txusrclk2_w);
      phy3.txusrclk2(txusrclk2_w);
   endrule

   rule phy0_txuserrdy;
      txuserrdy_w <= phy0.txuserrdy_out();
   endrule

   rule phyx_txuserrdy;
      phy1.txuserrdy(txuserrdy_w);
      phy2.txuserrdy(txuserrdy_w);
      phy3.txuserrdy(txuserrdy_w);
   endrule

   rule phy0_gtrxreset;
      gtrxreset_w <= phy0.gtrxreset_out();
   endrule

   rule phyx_gtrxreset;
      phy1.gtrxreset(gtrxreset_w);
      phy2.gtrxreset(gtrxreset_w);
      phy3.gtrxreset(gtrxreset_w);
   endrule

   rule phy0_gttxreset;
      gttxreset_w <= phy0.gttxreset_out();
   endrule

   rule phyx_gttxreset;
      phy1.gttxreset(gttxreset_w);
      phy2.gttxreset(gttxreset_w);
      phy3.gttxreset(gttxreset_w);
   endrule

   rule phy0_reset_counter_done;
      reset_counter_done_w <= phy0.reset_counter_done_out();
   endrule

   rule phyx_reset_counter_done;
      phy1.reset_counter_done(reset_counter_done_w);
      phy2.reset_counter_done(reset_counter_done_w);
      phy3.reset_counter_done(reset_counter_done_w);
   endrule

   for (Integer i=0; i<4; i=i+1) begin
      txFifo[i] <- mkUGFIFOF(clocked_by clk_156_25, reset_by noReset);
      rule tx_mac;
         let v <- toGet(txFifo[i]).get;
         case (i)
            0: begin
               phy0.xgmii.txd(v[71:8]);
               phy0.xgmii.txc(v[7:0]);
            end
            1: begin
               phy1.xgmii.txd(v[71:8]);
               phy1.xgmii.txc(v[7:0]);
            end
            2: begin
               phy2.xgmii.txd(v[71:8]);
               phy2.xgmii.txc(v[7:0]);
            end
            3: begin
               phy3.xgmii.txd(v[71:8]);
               phy3.xgmii.txc(v[7:0]);
            end
         endcase
      endrule
   end

   rxFifo[0] <- mkUGFIFOF(clocked_by phy0.rxrecclk, reset_by noReset);
   rxFifo[1] <- mkUGFIFOF(clocked_by phy1.rxrecclk, reset_by noReset);
   rxFifo[2] <- mkUGFIFOF(clocked_by phy2.rxrecclk, reset_by noReset);
   rxFifo[3] <- mkUGFIFOF(clocked_by phy3.rxrecclk, reset_by noReset);
   for (Integer i=0; i<4; i=i+1) begin
      rule rx_mac;
         case(i)
            0: begin
               rxFifo[0].enq({phy0.xgmii.rxd, phy0.xgmii.rxc});
            end
            1: begin
               rxFifo[1].enq({phy1.xgmii.rxd, phy1.xgmii.rxc});
            end
            2: begin
               rxFifo[2].enq({phy2.xgmii.rxd, phy2.xgmii.rxc});
            end
            3: begin
               rxFifo[3].enq({phy3.xgmii.rxd, phy3.xgmii.rxc});
            end
         endcase
      endrule
   end

   Vector#(4, Wire#(Bit#(1))) tx_serial_p <- replicateM(mkDWire(0));
   Vector#(4, Wire#(Bit#(1))) tx_serial_n <- replicateM(mkDWire(0));
   rule tx_serial0;
      tx_serial_p[0] <= phy0.tx_serial.txp;
      tx_serial_n[0] <= phy0.tx_serial.txn;
   endrule
   rule tx_serial1;
      tx_serial_p[1] <= phy1.tx_serial.txp;
      tx_serial_n[1] <= phy1.tx_serial.txn;
   endrule
   rule tx_serial2;
      tx_serial_p[2] <= phy2.tx_serial.txp;
      tx_serial_n[2] <= phy2.tx_serial.txn;
   endrule
   rule tx_serial3;
      tx_serial_p[3] <= phy3.tx_serial.txp;
      tx_serial_n[3] <= phy3.tx_serial.txn;
   endrule

   Vector#(4, Wire#(Bit#(1))) rx_serial_wire_p <- replicateM(mkDWire(0));
   Vector#(4, Wire#(Bit#(1))) rx_serial_wire_n <- replicateM(mkDWire(0));

   rule rx_serial0;
      phy0.rx_serial.rxp(rx_serial_wire_p[0]);
      phy0.rx_serial.rxn(rx_serial_wire_n[0]);
   endrule
   rule rx_serial1;
      phy1.rx_serial.rxp(rx_serial_wire_p[1]);
      phy1.rx_serial.rxn(rx_serial_wire_n[1]);
   endrule
   rule rx_serial2;
      phy2.rx_serial.rxp(rx_serial_wire_p[2]);
      phy2.rx_serial.rxn(rx_serial_wire_n[2]);
   endrule
   rule rx_serial3;
      phy3.rx_serial.rxp(rx_serial_wire_p[3]);
      phy3.rx_serial.rxn(rx_serial_wire_n[3]);
   endrule

   rxClocks[0] = phy0.rxrecclk;
   rxClocks[1] = phy1.rxrecclk;
   rxClocks[2] = phy2.rxrecclk;
   rxClocks[3] = phy3.rxrecclk;

   interface tx = map(toPut, txFifo);
   interface rx = map(toGet, rxFifo);
   method serial_tx_p = readVReg(tx_serial_p);
   method serial_tx_n = readVReg(tx_serial_n);
   method serial_rx_p = writeVReg(rx_serial_wire_p);
   method serial_rx_n = writeVReg(rx_serial_wire_n);
   interface rx_clkout = rxClocks;
   interface tx_clkout = phy0.coreclk;
   method Action refclk (Bit#(1) p, Bit#(1) n);
      phy0.refclk_p(p);
      phy0.refclk_n(n);
   endmethod
endmodule
endpackage
