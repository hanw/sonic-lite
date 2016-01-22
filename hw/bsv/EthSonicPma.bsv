// Copyright (c) 2014 Cornell University.

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

package EthSonicPma;

import Clocks                               ::*;
import Vector                               ::*;
import Connectable                          ::*;
import FIFOF ::*;
import SpecialFIFOs ::*;
import Pipe ::*;
import GetPut ::*;

import ConnectalClocks                      ::*;
import Ethernet                             ::*;
import ALTERA_ETH_PMA_QSYS                 ::*;

`ifdef NUMBER_OF_10G_PORTS
typedef `NUMBER_OF_10G_PORTS NumPorts;
`else
typedef 4 NumPorts;
`endif

(* always_ready, always_enabled *)
interface PhyMgmtIfc;
(* prefix="" *) method Action      phy_mgmt_address( (* port="address" *) Bit#(7) v);
(* prefix="" *) method Action      phy_mgmt_read   ( (* port="read" *)    Bit#(1) v);
(* prefix="", result="readdata" *)    method Bit#(32)    phy_mgmt_readdata;
(* prefix="", result="waitrequest" *) method Bit#(1)     phy_mgmt_waitrequest;
(* prefix="" *) method Action      phy_mgmt_write  ( (* port="write" *)   Bit#(1) v);
(* prefix="" *) method Action      phy_mgmt_write_data( (* port="write_data" *) Bit#(32) v);
endinterface

(* always_ready, always_enabled *)
interface Status;
   method Bit#(1)     pll_locked;
   method Bit#(1)     rx_is_lockedtodata;
   method Bit#(1)     rx_is_lockedtoref;
endinterface

interface EthSonicPma#(numeric type numPorts);
   interface Vector#(numPorts, Status) status;
   interface Vector#(numPorts, PipeOut#(Bit#(66))) rx;
   interface Vector#(numPorts, PipeIn#(Bit#(66)))  tx;
   interface Vector#(numPorts, Clock) rx_clkout;
   interface Vector#(numPorts, Clock) tx_clkout;
   interface Vector#(numPorts, Reset) rx_reset;
   interface Vector#(numPorts, Reset) tx_reset;
   (*always_ready, always_enabled*)
   method Vector#(numPorts, Bit#(1)) serial_tx;
   (*always_ready, always_enabled*)
   method Action serial_rx(Vector#(numPorts, Bit#(1)) v);
   interface Vector#(numPorts, Bool)  rx_ready;
   interface Vector#(numPorts, Bool)  tx_ready;
endinterface

//(* always_ready, always_enabled *)
//interface EthSonicPmaTopIfc#(numeric type numPorts);
//   interface Vector#(numPorts, SerialIfc) serial;
//   interface Clock clk_phy;
//endinterface

//(* no_default_reset *)
module mkEthSonicPma#(Clock mgmt_clk, Clock pll_ref_clk, Clock clk_156_25, Reset rst_n)(EthSonicPma#(numPorts) intf);
   Clock defaultClock <- exposeCurrentClock();
   Reset invertedReset <- mkResetInverter(rst_n, clocked_by defaultClock);

   // Qsys version of sv_10g_pma, uses reset_n, bit-reversed inside
   EthSonicPmaWrap phy10g <- mkEthSonicPmaWrap(mgmt_clk, pll_ref_clk, clk_156_25, clk_156_25, clk_156_25, clk_156_25, rst_n, rst_n);
   // Megawiz generated pma uses active-high reset
   //EthSonicPmaWrap phy10g <- mkEthSonicPmaWrap(mgmt_clk, pll_ref_clk, invertedReset);

   Vector#(numPorts, Bool) rxReady = newVector;//unpack(phy10g.rx.ready0);
   Vector#(numPorts, Bool) txReady = newVector;//unpack(phy10g.tx.ready0);
   Vector#(numPorts, Reset) rxFifo_rst = newVector;
   Vector#(numPorts, Reset) txFifo_rst = newVector;
   Vector#(numPorts, Clock) rxFifo_clk = newVector;
   Vector#(numPorts, Clock) txFifo_clk = newVector;
   Vector#(numPorts, FIFOF#(Bit#(66))) rxFifo = newVector;
   Vector#(numPorts, FIFOF#(Bit#(66))) txFifo = newVector;

   // Rx Ready
   rxReady[0] = unpack(phy10g.rx.ready0);
`ifndef NUMBER_OF_ALTERA_PORTS
   rxReady[1] = unpack(phy10g.rx.ready1);
   rxReady[2] = unpack(phy10g.rx.ready2);
   rxReady[3] = unpack(phy10g.rx.ready3);
`endif

   // Tx Ready
   txReady[0] = unpack(phy10g.tx.ready0);
`ifndef NUMBER_OF_ALTERA_PORTS
   txReady[1] = unpack(phy10g.tx.ready1);
   txReady[2] = unpack(phy10g.tx.ready2);
   txReady[3] = unpack(phy10g.tx.ready3);
`endif

   // Tx Clock
   txFifo_clk[0] = phy10g.tx_clkout0;
`ifndef NUMBER_OF_ALTERA_PORTS
   txFifo_clk[1] = phy10g.tx_clkout1;
   txFifo_clk[2] = phy10g.tx_clkout2;
   txFifo_clk[3] = phy10g.tx_clkout3;
`endif

   // Rx Clock
   rxFifo_clk[0] = phy10g.rx_clkout0;
`ifndef NUMBER_OF_ALTERA_PORTS
   rxFifo_clk[1] = phy10g.rx_clkout1;
   rxFifo_clk[2] = phy10g.rx_clkout2;
   rxFifo_clk[3] = phy10g.rx_clkout3;
`endif

   for (Integer i=0; i<valueOf(numPorts); i=i+1) begin
      rxFifo_rst[i] <- mkAsyncReset(2, rst_n, rxFifo_clk[i]);
      txFifo_rst[i] <- mkAsyncReset(2, rst_n, clk_156_25);
      rxFifo[i] <- mkFIFOF(clocked_by rxFifo_clk[i], reset_by noReset);
      txFifo[i] <- mkFIFOF(clocked_by clk_156_25, reset_by noReset);
   end
   Vector#(numPorts, PipeOut#(Bit#(66))) vRxPipe = newVector;
   Vector#(numPorts, PipeIn#(Bit#(66))) vTxPipe = newVector;
   for (Integer i=0; i<valueOf(numPorts); i=i+1) begin
      vRxPipe[i] = toPipeOut(rxFifo[i]);
      vTxPipe[i] = toPipeIn(txFifo[i]);
   end

   rule receive0;
      rxFifo[0].enq(phy10g.rx.parallel_data0);
   endrule
`ifndef NUMBER_OF_ALTERA_PORTS
   rule receive1;
      rxFifo[1].enq(phy10g.rx.parallel_data1);
   endrule
   rule receive2;
      rxFifo[2].enq(phy10g.rx.parallel_data2);
   endrule
   rule receive3;
      rxFifo[3].enq(phy10g.rx.parallel_data3);
   endrule
`endif

   Wire#(Bit#(66)) tx_data0 <- mkDWire(0, clocked_by clk_156_25, reset_by noReset);
   rule getTxFifo0;
      let v <- toGet(txFifo[0]).get;
      tx_data0 <= v;
   endrule
   rule sendTxFifo0;
      phy10g.tx.parallel_data0(pack(tx_data0));
   endrule

`ifndef NUMBER_OF_ALTERA_PORTS
   Wire#(Bit#(66)) tx_data1 <- mkDWire(0, clocked_by clk_156_25, reset_by noReset);
   rule getTxFifo1;
      let v <- toGet(txFifo[1]).get;
      tx_data1 <= v;
   endrule
   rule sendTxFifo1;
      phy10g.tx.parallel_data1(pack(tx_data1));
   endrule

   Wire#(Bit#(66)) tx_data2 <- mkDWire(0, clocked_by clk_156_25, reset_by noReset);
   rule getTxFifo2;
      let v <- toGet(txFifo[2]).get;
      tx_data2 <= v;
   endrule
   rule sendTxFifo2;
      phy10g.tx.parallel_data2(pack(tx_data2));
   endrule

   Wire#(Bit#(66)) tx_data3 <- mkDWire(0, clocked_by clk_156_25, reset_by noReset);
   rule getTxFifo3;
      let v <- toGet(txFifo[3]).get;
      tx_data3 <= v;
   endrule
   rule sendTxFifo3;
      phy10g.tx.parallel_data3(pack(tx_data3));
   endrule
`endif

   Vector#(numPorts, Wire#(Bit#(1))) tx_serial <- replicateM(mkDWire(0));
   rule tx_serial0;
      tx_serial[0] <= phy10g.tx.serial_data0;
   endrule
`ifndef NUMBER_OF_ALTERA_PORTS
   rule tx_serial1;
      tx_serial[1] <= phy10g.tx.serial_data1;
   endrule
   rule tx_serial2;
      tx_serial[2] <= phy10g.tx.serial_data2;
   endrule
   rule tx_serial3;
      tx_serial[3] <= phy10g.tx.serial_data3;
   endrule
`endif

   Vector#(numPorts, Wire#(Bit#(1))) rx_serial_wire <- replicateM(mkDWire(0));
   rule rx_serial0;
      phy10g.rx.serial_data0(rx_serial_wire[0]);
   endrule
`ifndef NUMBER_OF_ALTERA_PORTS
   rule rx_serial1;
      phy10g.rx.serial_data1(rx_serial_wire[1]);
   endrule
   rule rx_serial2;
      phy10g.rx.serial_data2(rx_serial_wire[2]);
   endrule
   rule rx_serial3;
      phy10g.rx.serial_data3(rx_serial_wire[3]);
   endrule
`endif

   // Status
   Vector#(numPorts, Status) status_ifcs;
   status_ifcs[0] = interface Status;
       method Bit#(1) pll_locked;
          return phy10g.pll.locked0;
       endmethod
       method Bit#(1) rx_is_lockedtodata;
          return phy10g.rx.is_lockedtodata0;
       endmethod
       method Bit#(1) rx_is_lockedtoref;
          return phy10g.rx.is_lockedtoref0;
       endmethod
   endinterface;
`ifndef NUMBER_OF_ALTERA_PORTS
   status_ifcs[1] = interface Status;
       method Bit#(1) pll_locked;
          return phy10g.pll.locked1;
       endmethod
       method Bit#(1) rx_is_lockedtodata;
          return phy10g.rx.is_lockedtodata1;
       endmethod
       method Bit#(1) rx_is_lockedtoref;
          return phy10g.rx.is_lockedtoref1;
       endmethod
   endinterface;
   status_ifcs[2] = interface Status;
       method Bit#(1) pll_locked;
          return phy10g.pll.locked2;
       endmethod
       method Bit#(1) rx_is_lockedtodata;
          return phy10g.rx.is_lockedtodata2;
       endmethod
       method Bit#(1) rx_is_lockedtoref;
          return phy10g.rx.is_lockedtoref2;
       endmethod
   endinterface;
   status_ifcs[3] = interface Status;
       method Bit#(1) pll_locked;
          return phy10g.pll.locked3;
       endmethod
       method Bit#(1) rx_is_lockedtodata;
          return phy10g.rx.is_lockedtodata3;
       endmethod
       method Bit#(1) rx_is_lockedtoref;
          return phy10g.rx.is_lockedtoref3;
       endmethod
   endinterface;
`endif

   interface tx_clkout = txFifo_clk;
   interface rx_clkout = rxFifo_clk;
   interface rx_ready  = rxReady;
   interface tx_ready  = txReady;
   interface rx        = vRxPipe;
   interface tx        = vTxPipe;
   method serial_tx = readVReg(tx_serial);
   method serial_rx = writeVReg(rx_serial_wire);
   interface status    = status_ifcs;
   interface rx_reset  = rxFifo_rst;
   interface tx_reset  = txFifo_rst;
endmodule: mkEthSonicPma

/*module mkEthSonicPmaTop#(Clock mgmt_clk, Clock pll_refclk, Clock clk_156_25, Reset mgmt_reset)(EthSonicPmaTopIfc);
   EthSonicPma#(4) _a <- mkEthSonicPma(mgmt_clk, pll_refclk, clk_156_25, mgmt_reset);
   interface serial = _a.pmd;
   interface Clock clk_phy = mgmt_clk;
endmodule*/

endpackage: EthSonicPma
