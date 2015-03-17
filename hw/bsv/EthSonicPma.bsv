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
import ALTERA_ETH_SONIC_PMA                 ::*;

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
   interface Vector#(numPorts, PipeOut#(Bit#(40))) rx;
   interface Vector#(numPorts, PipeIn#(Bit#(40)))  tx;
   interface Vector#(numPorts, Bool)  rx_ready;
   interface Vector#(numPorts, Clock) rx_clkout;
   interface Vector#(numPorts, Bool)  tx_ready;
   interface Vector#(numPorts, Clock) tx_clkout;
   interface Vector#(numPorts, Reset) rx_reset;
   interface Vector#(numPorts, Reset) tx_reset;
   interface Vector#(numPorts, SerialIfc) pmd;
endinterface

(* always_ready, always_enabled *)
interface EthSonicPmaTopIfc;
   interface Vector#(NumPorts, SerialIfc) serial;
   interface Clock clk_phy;
endinterface

//(* no_default_reset *)
module mkEthSonicPma#(Clock mgmt_clk, Clock xgmii_clk, Clock pll_ref_clk, Reset rst_n)(EthSonicPma#(NumPorts) intf);
   Clock defaultClock <- exposeCurrentClock();
   Reset invertedReset <- mkResetInverter(rst_n, clocked_by defaultClock);

   EthSonicPmaWrap phy10g <- mkEthSonicPmaWrap(mgmt_clk, pll_ref_clk, invertedReset);

   Vector#(NumPorts, Bool) rxReady = map(unpack, unpack(phy10g.rx.ready0));
   Vector#(NumPorts, Bool) txReady = map(unpack, unpack(phy10g.tx.ready0));
   Vector#(NumPorts, Reset) rxFifo_rst = newVector;
   Vector#(NumPorts, Reset) txFifo_rst = newVector;
   Vector#(NumPorts, Clock) rxFifo_clk = newVector;
   Vector#(NumPorts, Clock) txFifo_clk = newVector;
   Vector#(NumPorts, FIFOF#(Bit#(40))) rxFifo = newVector;
   Vector#(NumPorts, FIFOF#(Bit#(40))) txFifo = newVector;

   txFifo_clk[0] = phy10g.tx_clkout0;
   txFifo_clk[1] = phy10g.tx_clkout1;
   txFifo_clk[2] = phy10g.tx_clkout2;
   txFifo_clk[3] = phy10g.tx_clkout3;
   rxFifo_clk[0] = phy10g.rx_clkout0;
   rxFifo_clk[1] = phy10g.rx_clkout1;
   rxFifo_clk[2] = phy10g.rx_clkout2;
   rxFifo_clk[3] = phy10g.rx_clkout3;

   for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
      rxFifo_rst[i] <- mkAsyncReset(2, rst_n, rxFifo_clk[i]);
      txFifo_rst[i] <- mkAsyncReset(2, rst_n, txFifo_clk[i]);
      rxFifo[i] <- mkFIFOF(clocked_by rxFifo_clk[i], reset_by noReset);
      txFifo[i] <- mkFIFOF(clocked_by txFifo_clk[i], reset_by noReset);
   end
   Vector#(NumPorts, PipeOut#(Bit#(40))) vRxPipe = newVector;
   Vector#(NumPorts, PipeIn#(Bit#(40))) vTxPipe = newVector;
   for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
      vRxPipe[i] = toPipeOut(rxFifo[i]);
      vTxPipe[i] = toPipeIn(txFifo[i]);
   end

   rule receive0;
      rxFifo[0].enq(phy10g.rx.parallel_data0);
   endrule
   rule receive1;
      rxFifo[1].enq(phy10g.rx.parallel_data1);
   endrule
   rule receive2;
      rxFifo[2].enq(phy10g.rx.parallel_data2);
   endrule
   rule receive3;
      rxFifo[3].enq(phy10g.rx.parallel_data3);
   endrule

   rule transmit0;
      Bit#(40) p_wires;
      p_wires <- toGet(txFifo[0]).get;
      phy10g.tx.parallel_data0(pack(p_wires));
   endrule
   rule transmit1;
      Bit#(40) p_wires;
      p_wires <- toGet(txFifo[1]).get;
      phy10g.tx.parallel_data1(pack(p_wires));
   endrule
   rule transmit2;
      Bit#(40) p_wires;
      p_wires <- toGet(txFifo[2]).get;
      phy10g.tx.parallel_data2(pack(p_wires));
   endrule
   rule transmit3;
      Bit#(40) p_wires;
      p_wires <- toGet(txFifo[3]).get;
      phy10g.tx.parallel_data3(pack(p_wires));
   endrule

   // Use Wire to pass data from interface expression to other rules.
   Vector#(NumPorts, Wire#(Bit#(1))) wires <- replicateM(mkDWire(0));
   Vector#(NumPorts, SerialIfc) serial_ifcs;
   for (Integer i=0; i < valueOf(NumPorts); i=i+1) begin
       serial_ifcs[i] = interface SerialIfc;
          method Action rx (Bit#(1) v);
             wires[i] <= v;
          endmethod
          method Bit#(1) tx;
             return phy10g.tx.serial_data[i];
          endmethod
       endinterface;
   end
   rule set_serial_data;
      // Use readVReg to read Vector of Wires.
      phy10g.rx.serial_data(pack(readVReg(wires)));
   endrule

   // Status
   Vector#(NumPorts, Status) status_ifcs;
   for (Integer i=0; i < valueOf(NumPorts); i=i+1) begin
      status_ifcs[i] = interface Status;
          method Bit#(1) pll_locked;
             return phy10g.pll.locked[i];
          endmethod
          method Bit#(1) rx_is_lockedtodata;
             return phy10g.rx.is_lockedtodata[i];
          endmethod
          method Bit#(1) rx_is_lockedtoref;
             return phy10g.rx.is_lockedtoref[i];
          endmethod
       endinterface;
   end

   interface tx_clkout = txFifo_clk;
   interface rx_clkout = rxFifo_clk;
   interface rx_ready  = rxReady;
   interface tx_ready  = txReady;
   interface rx        = vRxPipe;
   interface tx        = vTxPipe;
   interface pmd       = serial_ifcs;
   interface status    = status_ifcs;
   interface rx_reset  = rxFifo_rst;
   interface tx_reset  = txFifo_rst;
endmodule: mkEthSonicPma

module mkEthSonicPmaTop#(Clock mgmt_clk, Clock xgmii_clk, Clock pll_refclk, Reset mgmt_reset)(EthSonicPmaTopIfc);
   EthSonicPma#(4) _a <- mkEthSonicPma(mgmt_clk, xgmii_clk, pll_refclk, mgmt_reset);
   interface serial = _a.pmd;
   interface Clock clk_phy = mgmt_clk;
endmodule

endpackage: EthSonicPma
