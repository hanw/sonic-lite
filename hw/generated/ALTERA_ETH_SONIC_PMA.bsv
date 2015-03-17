
/*
   ./importbvi.py
   -o
   ALTERA_ETH_SONIC_PMA.bsv
   -I
   EthSonicPmaWrap
   -P
   EthSonicPmaWrap
   -c
   pll_ref_clk
   -r
   phy_mgmt_clk_reset
   -c
   phy_mgmt_clk
   -f
   phy_mgmt
   -f
   tx_r
   -f
   rx_r
   -f
   tx
   -f
   rx
   -f
   reconfig
   ../../verilog/altera/sonic_pma_v1_05.v
*/

import Clocks::*;
import DefaultValue::*;
import XilinxCells::*;
import GetPut::*;

(* always_ready, always_enabled *)
interface EthsonicpmawrapPhy_mgmt;
    method Action      address(Bit#(9) v);
    method Action      read(Bit#(1) v);
    method Bit#(32)    readdata();
    method Bit#(1)     waitrequest();
    method Action      write(Bit#(1) v);
    method Action      writedata(Bit#(32) v);
endinterface
(* always_ready, always_enabled *)
interface EthsonicpmawrapPll;
    method Bit#(4)     locked();
endinterface
(* always_ready, always_enabled *)
interface EthsonicpmawrapRx;
    method Bit#(4)     is_lockedtodata();
    method Bit#(4)     is_lockedtoref();
    method Bit#(4)     ready0();
    method Bit#(40)    parallel_data0();
    method Bit#(40)    parallel_data1();
    method Bit#(40)    parallel_data2();
    method Bit#(40)    parallel_data3();
    method Action      serial_data(Bit#(4) v);
endinterface
(* always_ready, always_enabled *)
interface EthsonicpmawrapTx;
    method Action      parallel_data0(Bit#(40) v);
    method Action      parallel_data1(Bit#(40) v);
    method Action      parallel_data2(Bit#(40) v);
    method Action      parallel_data3(Bit#(40) v);
    method Bit#(4)     serial_data();
    method Bit#(4)     ready0();
endinterface
(* always_ready, always_enabled *)
interface EthSonicPmaWrap;
    interface EthsonicpmawrapPhy_mgmt  phy_mgmt;
    interface EthsonicpmawrapPll       pll;
    interface EthsonicpmawrapRx        rx;
    interface EthsonicpmawrapTx        tx;
    interface Clock                    tx_clkout0;
    interface Clock                    tx_clkout1;
    interface Clock                    tx_clkout2;
    interface Clock                    tx_clkout3;
    interface Clock                    rx_clkout0;
    interface Clock                    rx_clkout1;
    interface Clock                    rx_clkout2;
    interface Clock                    rx_clkout3;
endinterface
import "BVI" sonic_pma_v1_05 =
module mkEthSonicPmaWrap#(Clock phy_mgmt_clk, Clock pll_ref_clk, Reset phy_mgmt_clk_reset)(EthSonicPmaWrap);
    default_clock clk();
    default_reset rst();
    input_clock phy_mgmt_clk(phy_mgmt_clk) = phy_mgmt_clk;
    input_reset phy_mgmt_clk_reset(phy_mgmt_clk_reset) = phy_mgmt_clk_reset;
    input_clock pll_ref_clk(pll_ref_clk) = pll_ref_clk;

    output_clock tx_clkout0(tx_clkout0);
    output_clock tx_clkout1(tx_clkout1);
    output_clock tx_clkout2(tx_clkout2);
    output_clock tx_clkout3(tx_clkout3);
    output_clock rx_clkout0(rx_clkout0);
    output_clock rx_clkout1(rx_clkout1);
    output_clock rx_clkout2(rx_clkout2);
    output_clock rx_clkout3(rx_clkout3);
    interface EthsonicpmawrapPhy_mgmt     phy_mgmt;
        method address(phy_mgmt_address) clocked_by (phy_mgmt_clk) reset_by (phy_mgmt_clk_reset) enable((*inhigh*) EN_phy_mgmt_address);
        method read(phy_mgmt_read) clocked_by (phy_mgmt_clk) reset_by (phy_mgmt_clk_reset) enable((*inhigh*) EN_phy_mgmt_read);
        method phy_mgmt_readdata readdata() clocked_by (phy_mgmt_clk) reset_by (phy_mgmt_clk_reset);
        method phy_mgmt_waitrequest waitrequest() clocked_by (phy_mgmt_clk) reset_by (phy_mgmt_clk_reset);
        method write(phy_mgmt_write) clocked_by (phy_mgmt_clk) reset_by (phy_mgmt_clk_reset) enable((*inhigh*) EN_phy_mgmt_write);
        method writedata(phy_mgmt_writedata) clocked_by (phy_mgmt_clk) reset_by (phy_mgmt_clk_reset) enable((*inhigh*) EN_phy_mgmt_writedata);
    endinterface
    interface EthsonicpmawrapPll     pll;
        method pll_locked locked() clocked_by (pll_ref_clk);
    endinterface
    interface EthsonicpmawrapRx     rx;
        method rx_is_lockedtodata is_lockedtodata();
        method rx_is_lockedtoref is_lockedtoref();
        method rx_parallel_data0 parallel_data0() clocked_by (rx_clkout0);
        method rx_parallel_data1 parallel_data1() clocked_by (rx_clkout1);
        method rx_parallel_data2 parallel_data2() clocked_by (rx_clkout2);
        method rx_parallel_data3 parallel_data3() clocked_by (rx_clkout3);
        method rx_ready ready0();
        method serial_data(rx_serial_data) enable((*inhigh*) EN_rx_serial_data);
    endinterface
    interface EthsonicpmawrapTx     tx;
        method parallel_data0(tx_parallel_data0) clocked_by(tx_clkout0) enable((*inhigh*) EN_tx_parallel_data0);
        method parallel_data1(tx_parallel_data1) clocked_by(tx_clkout1) enable((*inhigh*) EN_tx_parallel_data1);
        method parallel_data2(tx_parallel_data2) clocked_by(tx_clkout2) enable((*inhigh*) EN_tx_parallel_data2);
        method parallel_data3(tx_parallel_data3) clocked_by(tx_clkout3) enable((*inhigh*) EN_tx_parallel_data3);
        method tx_serial_data serial_data();
        method tx_ready ready0();
    endinterface
    schedule (phy_mgmt.address, phy_mgmt.read, phy_mgmt.readdata, phy_mgmt.waitrequest, phy_mgmt.write, phy_mgmt.writedata, pll.locked, rx.is_lockedtodata, rx.is_lockedtoref, rx.parallel_data0, rx.parallel_data1, rx.parallel_data2, rx.parallel_data3, rx.serial_data, rx.ready0, tx.parallel_data0, tx.parallel_data1, tx.parallel_data2, tx.parallel_data3, tx.serial_data, tx.ready0) CF (phy_mgmt.address, phy_mgmt.read, phy_mgmt.readdata, phy_mgmt.waitrequest, phy_mgmt.write, phy_mgmt.writedata, pll.locked, rx.is_lockedtodata, rx.is_lockedtoref, rx.parallel_data0, rx.parallel_data1, rx.parallel_data2, rx.parallel_data3, rx.serial_data, rx.ready0, tx.parallel_data0, tx.parallel_data1, tx.parallel_data2, tx.parallel_data3, tx.serial_data, tx.ready0);
endmodule
