
// Import Qsys
//
import Clocks::*;
import DefaultValue::*;
import XilinxCells::*;
import GetPut::*;

(* always_ready, always_enabled *)
interface EthsonicpmawrapPll;
    method Bit#(4)     locked();
endinterface
(* always_ready, always_enabled *)
interface EthsonicpmawrapRx;
    method Bit#(4)     is_lockedtodata();
    method Bit#(4)     is_lockedtoref();
    method Bit#(1)     ready0();
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
    method Bit#(1)     ready0();
endinterface
(* always_ready, always_enabled *)
interface EthSonicPmaWrap;
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
import "BVI" sv_10g_pma =
module mkEthSonicPmaWrap#(Clock phy_mgmt_clk, Clock pll_ref_clk, Reset phy_mgmt_clk_reset_n, Reset pll_ref_clk_reset_n)(EthSonicPmaWrap);
    default_clock clk();
    default_reset rst();
    input_clock phy_mgmt_clk(phy_mgmt_clk_clk) = phy_mgmt_clk;
    input_reset phy_mgmt_clk_reset_n(phy_mgmt_clk_reset_reset_n) = phy_mgmt_clk_reset_n;
    input_clock pll_ref_clk(pll_ref_clk_clk) = pll_ref_clk;
    input_reset pll_ref_clk_reset_n(pll_ref_clk_reset_reset_n) = pll_ref_clk_reset_n;

    output_clock tx_clkout0(tx_clkout0_clk);
    output_clock tx_clkout1(tx_clkout1_clk);
    output_clock tx_clkout2(tx_clkout2_clk);
    output_clock tx_clkout3(tx_clkout3_clk);
    output_clock rx_clkout0(rx_clkout0_clk);
    output_clock rx_clkout1(rx_clkout1_clk);
    output_clock rx_clkout2(rx_clkout2_clk);
    output_clock rx_clkout3(rx_clkout3_clk);
    interface EthsonicpmawrapPll     pll;
        method pll_locked_export locked() clocked_by (pll_ref_clk);
    endinterface
    interface EthsonicpmawrapRx     rx;
        method rx_is_lockedtodata_export is_lockedtodata();
        method rx_is_lockedtoref_export is_lockedtoref();
        method rx_parallel_data0_data parallel_data0() clocked_by (rx_clkout0);
        method rx_parallel_data1_data parallel_data1() clocked_by (rx_clkout1);
        method rx_parallel_data2_data parallel_data2() clocked_by (rx_clkout2);
        method rx_parallel_data3_data parallel_data3() clocked_by (rx_clkout3);
        method rx_ready_export ready0();
        method serial_data(rx_serial_data_export) enable((*inhigh*) EN_rx_serial_data);
    endinterface
    interface EthsonicpmawrapTx     tx;
        method parallel_data0(tx_parallel_data0_data) clocked_by(tx_clkout0) enable((*inhigh*) EN_tx_parallel_data0);
        method parallel_data1(tx_parallel_data1_data) clocked_by(tx_clkout1) enable((*inhigh*) EN_tx_parallel_data1);
        method parallel_data2(tx_parallel_data2_data) clocked_by(tx_clkout2) enable((*inhigh*) EN_tx_parallel_data2);
        method parallel_data3(tx_parallel_data3_data) clocked_by(tx_clkout3) enable((*inhigh*) EN_tx_parallel_data3);
        method tx_serial_data_export serial_data();
        method tx_ready_export ready0();
    endinterface
    schedule (pll.locked, rx.is_lockedtodata, rx.is_lockedtoref, rx.parallel_data0, rx.parallel_data1, rx.parallel_data2, rx.parallel_data3, rx.serial_data, rx.ready0, tx.parallel_data0, tx.parallel_data1, tx.parallel_data2, tx.parallel_data3, tx.serial_data, tx.ready0) CF (pll.locked, rx.is_lockedtodata, rx.is_lockedtoref, rx.parallel_data0, rx.parallel_data1, rx.parallel_data2, rx.parallel_data3, rx.serial_data, rx.ready0, tx.parallel_data0, tx.parallel_data1, tx.parallel_data2, tx.parallel_data3, tx.serial_data, tx.ready0);
endmodule
