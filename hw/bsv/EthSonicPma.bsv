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

(* always_ready, always_enabled *)
interface EthSonicPmaInternal#(numeric type np);
   interface Vector#(np, Status)    status;
   interface Vector#(np, SerialIfc) pmd;
   interface Vector#(np, XCVR_PMA)  fpga;
endinterface

interface EthSonicPma#(numeric type numPorts);
   interface Vector#(numPorts, PipeOut#(Bit#(40))) rx;
   interface Vector#(numPorts, PipeIn#(Bit#(40)))  tx;
   interface Vector#(numPorts, Bool)  rx_ready;
   interface Vector#(numPorts, Clock) rx_clkout;
   interface Vector#(numPorts, Bool)  tx_ready;
   interface Vector#(numPorts, Clock) tx_clkout;
   interface Vector#(numPorts, SerialIfc) pmd;
endinterface

(* always_ready, always_enabled *)
interface EthSonicPmaTopIfc;
   interface Vector#(NumPorts, SerialIfc) serial;
   interface Clock clk_phy;
endinterface

//(* synthesize *)
module mkEthSonicPmaInternal#(Clock phy_mgmt_clk, Clock pll_ref_clk, Reset phy_mgmt_reset)(EthSonicPmaInternal#(NumPorts));

   //Clock defaultClock <- exposeCurrentClock();
   //Reset defaultReset <- exposeCurrentReset();

   EthSonicPmaWrap phy10g <- mkEthSonicPmaWrap(phy_mgmt_clk, pll_ref_clk, phy_mgmt_reset);

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

   // FPGA Fabric-Side Interface
   Vector#(NumPorts, Wire#(Bit#(40))) p_wires <- replicateM(mkDWire(0));
   Vector#(NumPorts, XCVR_PMA) xcvr_ifcs;
   for (Integer i=0; i < valueOf(NumPorts); i=i+1) begin
      xcvr_ifcs[i] = interface XCVR_PMA;
          interface XCVR_RX_PMA rx;
             method Bit#(1) rx_ready;
                return phy10g.rx_r.eady[i];
             endmethod
             method Bit#(1) rx_clkout;
                return phy10g.rx.clkout[i];
             endmethod
             method Bit#(40) rx_data;
                return phy10g.rx.parallel_data[39 + 40 * i : 40 * i];
             endmethod
          endinterface
          interface XCVR_TX_PMA tx;
             method Bit#(1) tx_ready;
                return phy10g.tx_r.eady[i];
             endmethod
             method Bit#(1) tx_clkout;
                return phy10g.tx.clkout[i];
             endmethod
             method Action tx_data (Bit#(40) v);
                p_wires[i] <= v;
             endmethod
          endinterface
       endinterface;
   end
   rule set_parallel_data;
      phy10g.tx.parallel_data(pack(readVReg(p_wires)));
   endrule

   interface status = status_ifcs;
   interface pmd    = serial_ifcs;
   interface fpga   = xcvr_ifcs;

endmodule: mkEthSonicPmaInternal

module mkEthSonicPma#(Clock mgmt_clk, Clock pll_ref_clk, Reset mgmt_clk_reset)(EthSonicPma#(NumPorts) intf);
   //Clock defaultClock <- exposeCurrentClock();
   //Reset defaultReset <- exposeCurrentReset();
   EthSonicPmaInternal#(NumPorts) pma <- mkEthSonicPmaInternal(mgmt_clk, pll_ref_clk, mgmt_clk_reset);

   Vector#(NumPorts, FIFOF#(Bit#(40))) rxFifo <- replicateM(mkFIFOF());
   Vector#(NumPorts, FIFOF#(Bit#(40))) txFifo <- replicateM(mkFIFOF());
   Vector#(NumPorts, PipeOut#(Bit#(40))) vRxPipe = newVector;
   Vector#(NumPorts, PipeIn#(Bit#(40))) vTxPipe = newVector;
   for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
      vRxPipe[i] = toPipeOut(rxFifo[i]);
      vTxPipe[i] = toPipeIn(txFifo[i]);
   end
   rule receive (True);
      for(Integer i=0; i<valueOf(NumPorts); i=i+1) begin
         rxFifo[i].enq(pma.fpga[i].rx.rx_data);
      end
   endrule
   rule transmit (True);
      for(Integer i=0; i<valueOf(NumPorts); i=i+1) begin
         let v <- toGet(txFifo[i]).get;
         pma.fpga[i].tx.tx_data(v);
      end
   endrule

   Vector#(NumPorts, Bool) rxReady = newVector;
   Vector#(NumPorts, Bool) txReady = newVector;
   for(Integer i=0; i<valueOf(NumPorts); i=i+1) begin
      rxReady[i] = unpack(pma.fpga[i].rx.rx_ready);
      txReady[i] = unpack(pma.fpga[i].tx.tx_ready);
   end

   Vector#(NumPorts, B2C1) tx_clk;
   Vector#(NumPorts, B2C1) rx_clk;
   for (Integer i=0; i < valueOf(NumPorts); i=i+1) begin
      tx_clk[i] <- mkB2C1();
      rx_clk[i] <- mkB2C1();
   end
   rule out_pma_clk;
      for (Integer i=0; i < valueOf(NumPorts); i=i+1) begin
         tx_clk[i].inputclock(pma.fpga[i].tx.tx_clkout);
         rx_clk[i].inputclock(pma.fpga[i].rx.rx_clkout);
      end
   endrule

   Vector#(NumPorts, Clock) out_tx_clk;
   Vector#(NumPorts, Clock) out_rx_clk;
   for (Integer i=0; i< valueOf(NumPorts); i=i+1) begin
      out_tx_clk[i] = tx_clk[i].c;
      out_rx_clk[i] = rx_clk[i].c;
   end

   interface tx_clkout = out_tx_clk;
   interface rx_clkout = out_rx_clk;
   interface rx_ready  = rxReady;
   interface tx_ready  = txReady;
   interface rx        = vRxPipe;
   interface tx        = vTxPipe;
   interface pmd       = pma.pmd;
endmodule: mkEthSonicPma

module mkEthSonicPmaTop#(Clock mgmt_clk, Clock pll_refclk, Reset mgmt_reset)(EthSonicPmaTopIfc);
   EthSonicPma#(4) _a <- mkEthSonicPma(mgmt_clk, pll_refclk, mgmt_reset);
   interface serial = _a.pmd;
   interface Clock clk_phy = mgmt_clk;
endmodule

endpackage: EthSonicPma
