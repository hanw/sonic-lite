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
import ALTERA_ETH_PMA_WRAPPER               ::*;
import ALTERA_ETH_PMA_RECONFIG_WRAPPER      ::*;
import ALTERA_ETH_PMA_RESET_CONTROL_WRAPPER ::*;

interface PhyMgmtIfc;
   method Action      phy_mgmt_address(Bit#(7) v);
   method Action      phy_mgmt_read(Bit#(1) v);
   method Bit#(32)    phy_mgmt_readdata;
   method Bit#(1)     phy_mgmt_waitrequest;
   method Action      phy_mgmt_write(Bit#(1) v);
   method Action      phy_mgmt_write_data(Bit#(32) v);
endinterface

interface Status#(numeric type np);
   method Vector#(np, Bit#(1))     tx_ready;
   method Vector#(np, Bit#(1))     rx_ready;
   method Vector#(np, Bit#(1))     pll_locked;
   method Vector#(np, Bit#(1))     rx_is_lockedtodata;
   method Vector#(np, Bit#(1))     rx_is_lockedtoref;
endinterface

interface Serial#(numeric type np);
   method Bit#(np)    tx_serial_data;
`ifdef USE_4_PORTS
   method Action      rx_serial_data(Bit#(4) v);
`elsif USE_2_PORTS
   method Action      rx_serial_data(Bit#(2) v);
`endif
endinterface

interface Parallel#(numeric type np);
   method Vector#(np, Bit#(40)) rx_parallel_data;
`ifdef USE_4_PORTS
   method Action                tx_parallel_data(Vector#(np, Bit#(40)) v);
`elsif USE_2_PORTS
   method Action                tx_parallel_data(Vector#(np, Bit#(40)) v);
`endif
endinterface

(* always_ready, always_enabled *)
interface EthPmaIfc#(numeric type np);
   interface Vector#(np, Clock) tx_clkout;
   interface Vector#(np, Clock) rx_clkout;
   interface PhyMgmtIfc         phy_mgmt;
   interface Status#(np)        status;
   interface Serial#(np)        serial;
   interface Parallel#(np)      parallel;
endinterface

module mkEthPma#(Clock phy_mgmt_clk, Clock pll_ref_clk, Reset phy_mgmt_reset, Reset pll_ref_reset)(EthPmaIfc#(np));

   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

   EthXcvrWrap         xcvr  <- mkEthXcvrWrap();
   EthXcvrReconfigWrap cfg   <- mkEthXcvrReconfigWrap(phy_mgmt_clk, phy_mgmt_reset, phy_mgmt_reset);
   EthXcvrResetWrap    rst   <- mkEthXcvrResetWrap(phy_mgmt_clk, phy_mgmt_reset, phy_mgmt_reset);

   C2B c2b <- mkC2B(pll_ref_clk);
   rule xcvr_clk;
      xcvr.tx.pll_refclk(c2b.o);
      xcvr.rx.cdr_refclk(c2b.o);
   endrule

   rule xcvr_reconfig;
      cfg.reconfig.from_xcvr(xcvr.reconfig.from_xcvr);
      xcvr.reconfig.to_xcvr(cfg.reconfig.to_xcvr);
   endrule

   rule xcvr_reset;
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

   rule xcvr_const;
      rst.pll.select(2'b11);
      xcvr.rx.set_locktodata(4'b0);
      xcvr.rx.set_locktoref(4'b0);
   endrule

   /* connect all three components */
   Vector#(np, B2C1) tx_clk;
   Vector#(np, B2C1) rx_clk;
   for (Integer i=0; i < valueOf(np); i=i+1) begin
      tx_clk[i] <- mkB2C1();
      rx_clk[i] <- mkB2C1();
   end

   rule out_pma_clk;
      for (Integer i=0; i < valueOf(np); i=i+1) begin
         tx_clk[i].inputclock(xcvr.tx.pma_clkout[i]);
         rx_clk[i].inputclock(xcvr.rx.pma_clkout[i]);
      end
   endrule

   Vector#(np, Clock) out_tx_clk;
   Vector#(np, Clock) out_rx_clk;
   for (Integer i=0; i< valueOf(np); i=i+1) begin
      out_tx_clk[i] = tx_clk[i].c;
      out_rx_clk[i] = rx_clk[i].c;
   end

   Vector#(np, Wire#(Bit#(1))) rx_serial_wires <- replicateM(mkDWire(0));

   interface tx_clkout = out_tx_clk;
   interface rx_clkout = out_rx_clk;

   interface Status status;
      method Vector#(np, Bit#(1)) rx_ready();
         Vector#(np, Bit#(1)) ret_val;
         for(Integer i=0; i< valueOf(np); i=i+1) begin
            ret_val[i] = rst.rx.ready[i];
         end
         return ret_val;
      endmethod

      method Vector#(np, Bit#(1)) tx_ready();
         Vector#(np, Bit#(1)) ret_val;
         for(Integer i=0; i< valueOf(np); i=i+1) begin
            ret_val[i] = rst.tx.ready[i];
         end
         return ret_val;
      endmethod

      method Vector#(np, Bit#(1)) pll_locked();
         Vector#(np, Bit#(1)) ret_val;
         for(Integer i=0; i< valueOf(np); i=i+1) begin
            ret_val[i] = xcvr.pll.locked[i];
         end
         return ret_val;
      endmethod

      method Vector#(np, Bit#(1)) rx_is_lockedtodata();
         Vector#(np, Bit#(1)) ret_val;
         for(Integer i=0; i< valueOf(np); i=i+1) begin
            ret_val[i] = xcvr.rx.is_lockedtodata[i];
         end
         return ret_val;
      endmethod

      method Vector#(np, Bit#(1)) rx_is_lockedtoref();
         Vector#(np, Bit#(1)) ret_val;
         for(Integer i=0; i< valueOf(np); i=i+1) begin
            ret_val[i] = xcvr.rx.is_lockedtoref[i];
         end
         return ret_val;
      endmethod
   endinterface

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


   interface Serial serial;
      method Bit#(np) tx_serial_data;
         Vector#(np, Bit#(1)) ret;
         for (Integer i=0; i < valueOf(np); i=i+1) begin //Rewrite with map
            ret[i] = xcvr.tx.serial_data[i];
         end
         return pack(ret);
      endmethod

      method Action rx_serial_data (v);
         xcvr.rx.serial_data(v);
      endmethod
   endinterface

   interface Parallel parallel;
      method Vector#(np, Bit#(40)) rx_parallel_data;
         Vector#(np, Bit#(40)) ret_val;
         for(Integer i=0; i < valueOf(np); i = i+1) begin
            ret_val[i] = unpack(xcvr.rx.pma_parallel_data)[39:0];
         end
         return ret_val;
      endmethod

//      method Action tx_parallel_data(v);
//         Vector#(np, Bit#(40)) ret_val;
//         for(Integer i=0; i < valueOf(np); i = i+1) begin
//            ret_val[i] = v[i];
//         end
//         xcvr.tx.pma_parallel_data(ret_val);
//      endmethod
   endinterface
endmodule

`ifdef USE_4_PORTS
typedef EthPmaIfc#(4) EthPmaIfc4;
(* synthesize *)
module mkEthPma4#(Clock mgmt_clk, Clock ref_clk, Reset mgmt_reset, Reset ref_reset) (EthPmaIfc4);
   EthPmaIfc4 _a <- mkEthPma(mgmt_clk, ref_clk, mgmt_reset, ref_reset); return _a;
endmodule
`elsif USE_2_PORTS
typedef EthPmaIfc#(2) EthPmaIfc2;
(* synthesize *)
module mkEthPma2#(Clock mgmt_clk, Clock ref_clk, Reset mgmt_reset, Reset ref_reset) (EthPmaIfc2);
   EthPmaIfc2 _a <- mkEthPma(mgmt_clk, ref_clk, mgmt_reset, ref_reset); return _a;
endmodule
`endif

endpackage: EthPma
