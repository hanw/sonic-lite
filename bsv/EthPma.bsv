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

package EthPma;

import Clocks                               ::*;
import Vector                               ::*;
import Connectable                          ::*;

import ConnectalClocks                      ::*;
import Ethernet                             ::*;

import ALTERA_ETH_PMA_WRAPPER               ::*;
import ALTERA_ETH_PMA_RECONFIG_WRAPPER      ::*;
import ALTERA_ETH_PMA_RESET_CONTROL_WRAPPER ::*;

`ifdef N_CHAN
typedef `N_CHAN N_CHAN;
`else
typedef 4 N_CHAN;
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
interface EthPmaIfc#(numeric type np);
   interface PhyMgmtIfc             phy_mgmt;
   interface Vector#(np, Status)    status;
   interface Vector#(np, SerialIfc) fiber;
   interface Vector#(np, XCVR_PMA)   fpga;
endinterface

(* synthesize *)
module mkEthPma#(Clock phy_mgmt_clk, Clock pll_ref_clk, Reset phy_mgmt_reset)(EthPmaIfc#(N_CHAN));

   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

   EthXcvrWrap         xcvr  <- mkEthXcvrWrap();
   EthXcvrReconfigWrap cfg   <- mkEthXcvrReconfigWrap(phy_mgmt_clk, phy_mgmt_reset, phy_mgmt_reset);
   EthXcvrResetWrap    rst   <- mkEthXcvrResetWrap(phy_mgmt_clk, phy_mgmt_reset, phy_mgmt_reset);

   C2B c2b <- mkC2B(pll_ref_clk);
   rule convert_clk_to_bit;
      xcvr.tx.pll_refclk(c2b.o);
      xcvr.rx.cdr_refclk(c2b.o);
   endrule

   rule connect_xcvr_reconfig;
      cfg.reconfig.from_xcvr(xcvr.reconfig.from_xcvr);
      xcvr.reconfig.to_xcvr(cfg.reconfig.to_xcvr);
   endrule

   rule connect_xcvr_and_reset_controller;
      xcvr.rx.analogreset(rst.rx.analogreset);
      xcvr.rx.digitalreset(rst.rx.digitalreset);
      xcvr.tx.analogreset(rst.tx.analogreset);
      xcvr.tx.digitalreset(rst.tx.digitalreset);
      rst.rx.cal_busy(xcvr.rx.cal_busy);
      rst.tx.cal_busy(xcvr.tx.cal_busy);
      rst.rx.is_lockedtodata(xcvr.rx.is_lockedtodata);
      rst.pll.locked(xcvr.pll.locked);
      xcvr.pll.powerdown(rst.pll.powerdown);
   endrule

   rule connect_any_constants;
      rst.pll.select(2'b11);
   endrule

   /* connect all three components */
//   Vector#(N_CHAN, B2C1) tx_clk;
//   Vector#(N_CHAN, B2C1) rx_clk;
//   for (Integer i=0; i < valueOf(N_CHAN); i=i+1) begin
//      tx_clk[i] <- mkB2C1();
//      rx_clk[i] <- mkB2C1();
//   end
//
//   rule out_pma_clk;
//      for (Integer i=0; i < valueOf(N_CHAN); i=i+1) begin
//         tx_clk[i].inputclock(xcvr.tx.pma_clkout[i]);
//         rx_clk[i].inputclock(xcvr.rx.pma_clkout[i]);
//      end
//   endrule
//
//   Vector#(N_CHAN, Clock) out_tx_clk;
//   Vector#(N_CHAN, Clock) out_rx_clk;
//   for (Integer i=0; i< valueOf(N_CHAN); i=i+1) begin
//      out_tx_clk[i] = tx_clk[i].c;
//      out_rx_clk[i] = rx_clk[i].c;
//   end
//   interface tx_clkout = out_tx_clk;
//   interface rx_clkout = out_rx_clk;

   // Status
   Vector#(N_CHAN, Status) status_ifcs;
   for (Integer i=0; i < valueOf(N_CHAN); i=i+1) begin
      status_ifcs[i] = interface Status;
          method Bit#(1) pll_locked;
             return xcvr.pll.locked[i];
          endmethod
          method Bit#(1) rx_is_lockedtodata;
             return xcvr.rx.is_lockedtodata[i];
          endmethod
          method Bit#(1) rx_is_lockedtoref;
             return xcvr.rx.is_lockedtoref[i];
          endmethod
       endinterface;
   end

   // Use Wire to pass data from interface expression to other rules.
   Vector#(N_CHAN, Wire#(Bit#(1))) wires <- replicateM(mkDWire(0));
   Vector#(N_CHAN, SerialIfc) serial_ifcs;
   for (Integer i=0; i < valueOf(N_CHAN); i=i+1) begin
       serial_ifcs[i] = interface SerialIfc;
          method Action rx (Bit#(1) v);
             wires[i] <= v;
          endmethod
          method Bit#(1) tx;
             return xcvr.tx.serial_data[i];
          endmethod
       endinterface;
   end
   rule set_serial_data;
      // Use readVReg to read Vector of Wires.
      xcvr.rx.serial_data(pack(readVReg(wires)));
   endrule

   // FPGA Fabric-Side Interface
   Vector#(N_CHAN, Wire#(Bit#(40))) p_wires <- replicateM(mkDWire(0));
   Vector#(N_CHAN, XCVR_PMA) xcvr_ifcs;
   for (Integer i=0; i < valueOf(N_CHAN); i=i+1) begin
      xcvr_ifcs[i] = interface XCVR_PMA;
          interface XCVR_RX_PMA rx;
             method Bit#(1) rx_ready;
                return rst.rx_r.eady[i];
             endmethod
             method Bit#(1) rx_clkout;
                return xcvr.rx.pma_clkout[i];
             endmethod
             method Bit#(40) rx_data;
                return xcvr.rx.pma_parallel_data[39 + 40 * i : 40 * i];
             endmethod
          endinterface
          interface XCVR_TX_PMA tx;
             method Bit#(1) tx_ready;
                return rst.tx_r.eady[i];
             endmethod
             method Bit#(1) tx_clkout;
                return xcvr.tx.pma_clkout[i];
             endmethod
             method Action tx_data (Bit#(40) v);
                p_wires[i] <= v;
             endmethod
          endinterface
       endinterface;
   end
   rule set_parallel_data;
      xcvr.tx.pma_parallel_data(pack(readVReg(p_wires)));
   endrule

   interface status = status_ifcs;
   interface fiber  = serial_ifcs;
   interface fpga   = xcvr_ifcs;

   interface PhyMgmtIfc phy_mgmt;
      method Action phy_mgmt_address(v);
         cfg.reconfig.mgmt_address(v);
      endmethod

      method Action phy_mgmt_read(v);
         cfg.reconfig.mgmt_read(v);
      endmethod

      method Bit#(32) phy_mgmt_readdata;
         return cfg.reconfig.mgmt_readdata;
      endmethod

      method Bit#(1) phy_mgmt_waitrequest;
         return cfg.reconfig.mgmt_waitrequest;
      endmethod

      method Action phy_mgmt_write(v);
         cfg.reconfig.mgmt_write(v);
      endmethod

      method Action phy_mgmt_write_data(v);
         cfg.reconfig.mgmt_writedata(v);
      endmethod
   endinterface

endmodule: mkEthPma
endpackage: EthPma
