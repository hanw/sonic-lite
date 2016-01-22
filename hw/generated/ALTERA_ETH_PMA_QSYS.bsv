
// Import Qsys
//
import Clocks::*;
import DefaultValue::*;
import XilinxCells::*;
import GetPut::*;

`ifndef NUMBER_OF_ALTERA_PORTS // 4PORT WRAPPER
(* always_ready, always_enabled *)
interface EthsonicpmawrapPll;
    method Bit#(1)     locked0();
    method Bit#(1)     locked1();
    method Bit#(1)     locked2();
    method Bit#(1)     locked3();
endinterface
(* always_ready, always_enabled *)
interface EthsonicpmawrapRx;
    method Bit#(1)     is_lockedtodata0();
    method Bit#(1)     is_lockedtodata1();
    method Bit#(1)     is_lockedtodata2();
    method Bit#(1)     is_lockedtodata3();
    method Bit#(1)     is_lockedtoref0();
    method Bit#(1)     is_lockedtoref1();
    method Bit#(1)     is_lockedtoref2();
    method Bit#(1)     is_lockedtoref3();
    method Bit#(1)     ready0();
    method Bit#(1)     ready1();
    method Bit#(1)     ready2();
    method Bit#(1)     ready3();
    method Bit#(66)    parallel_data0();
    method Bit#(66)    parallel_data1();
    method Bit#(66)    parallel_data2();
    method Bit#(66)    parallel_data3();
    method Action      serial_data0(Bit#(1) v);
    method Action      serial_data1(Bit#(1) v);
    method Action      serial_data2(Bit#(1) v);
    method Action      serial_data3(Bit#(1) v);
endinterface
(* always_ready, always_enabled *)
interface EthsonicpmawrapTx;
    method Action      parallel_data0(Bit#(66) v);
    method Action      parallel_data1(Bit#(66) v);
    method Action      parallel_data2(Bit#(66) v);
    method Action      parallel_data3(Bit#(66) v);
    method Bit#(1)     serial_data0();
    method Bit#(1)     serial_data1();
    method Bit#(1)     serial_data2();
    method Bit#(1)     serial_data3();
    method Bit#(1)     ready0();
    method Bit#(1)     ready1();
    method Bit#(1)     ready2();
    method Bit#(1)     ready3();
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
module mkEthSonicPmaWrap#(Clock phy_mgmt_clk, Clock pll_ref_clk, Clock tx_coreclkin0, Clock tx_coreclkin1, Clock tx_coreclkin2, Clock tx_coreclkin3, Reset phy_mgmt_clk_reset_n, Reset pll_ref_clk_reset_n)(EthSonicPmaWrap);
    default_clock clk();
    default_reset rst();
    input_clock phy_mgmt_clk(phy_mgmt_clk_clk) = phy_mgmt_clk;
    input_reset phy_mgmt_clk_reset_n(phy_mgmt_clk_reset_reset_n) = phy_mgmt_clk_reset_n;
    input_clock pll_ref_clk(pll_ref_clk_clk) = pll_ref_clk;
    input_reset pll_ref_clk_reset_n(pll_ref_clk_reset_reset_n) = pll_ref_clk_reset_n;
    input_clock tx_coreclkin0(tx_coreclkin0_clk) = tx_coreclkin0;
    input_clock tx_coreclkin1(tx_coreclkin1_clk) = tx_coreclkin1;
    input_clock tx_coreclkin2(tx_coreclkin2_clk) = tx_coreclkin2;
    input_clock tx_coreclkin3(tx_coreclkin3_clk) = tx_coreclkin3;

    output_clock tx_clkout0(tx_clkout0_clk);
    output_clock tx_clkout1(tx_clkout1_clk);
    output_clock tx_clkout2(tx_clkout2_clk);
    output_clock tx_clkout3(tx_clkout3_clk);
    output_clock rx_clkout0(rx_clkout0_clk);
    output_clock rx_clkout1(rx_clkout1_clk);
    output_clock rx_clkout2(rx_clkout2_clk);
    output_clock rx_clkout3(rx_clkout3_clk);
    interface EthsonicpmawrapPll     pll;
        method pll_locked0_export locked0() clocked_by (pll_ref_clk);
        method pll_locked1_export locked1() clocked_by (pll_ref_clk);
        method pll_locked2_export locked2() clocked_by (pll_ref_clk);
        method pll_locked3_export locked3() clocked_by (pll_ref_clk);
    endinterface
    interface EthsonicpmawrapRx     rx;
        method rx_is_lockedtodata0_export is_lockedtodata0();
        method rx_is_lockedtodata1_export is_lockedtodata1();
        method rx_is_lockedtodata2_export is_lockedtodata2();
        method rx_is_lockedtodata3_export is_lockedtodata3();
        method rx_is_lockedtoref0_export is_lockedtoref0();
        method rx_is_lockedtoref1_export is_lockedtoref1();
        method rx_is_lockedtoref2_export is_lockedtoref2();
        method rx_is_lockedtoref3_export is_lockedtoref3();
        method rx_parallel_data0_data parallel_data0() clocked_by (rx_clkout0);
        method rx_parallel_data1_data parallel_data1() clocked_by (rx_clkout1);
        method rx_parallel_data2_data parallel_data2() clocked_by (rx_clkout2);
        method rx_parallel_data3_data parallel_data3() clocked_by (rx_clkout3);
        method rx_ready0_export ready0();
        method rx_ready1_export ready1();
        method rx_ready2_export ready2();
        method rx_ready3_export ready3();
        method serial_data0(rx_serial_data0_export) enable((*inhigh*) EN_rx_serial_data0);
        method serial_data1(rx_serial_data1_export) enable((*inhigh*) EN_rx_serial_data1);
        method serial_data2(rx_serial_data2_export) enable((*inhigh*) EN_rx_serial_data2);
        method serial_data3(rx_serial_data3_export) enable((*inhigh*) EN_rx_serial_data3);
    endinterface
    interface EthsonicpmawrapTx     tx;
        method parallel_data0(tx_parallel_data0_data) clocked_by(tx_coreclkin0) enable((*inhigh*) EN_tx_parallel_data0);
        method parallel_data1(tx_parallel_data1_data) clocked_by(tx_coreclkin1) enable((*inhigh*) EN_tx_parallel_data1);
        method parallel_data2(tx_parallel_data2_data) clocked_by(tx_coreclkin2) enable((*inhigh*) EN_tx_parallel_data2);
        method parallel_data3(tx_parallel_data3_data) clocked_by(tx_coreclkin3) enable((*inhigh*) EN_tx_parallel_data3);
        method tx_serial_data0_export serial_data0();
        method tx_serial_data1_export serial_data1();
        method tx_serial_data2_export serial_data2();
        method tx_serial_data3_export serial_data3();
        method tx_ready0_export ready0();
        method tx_ready1_export ready1();
        method tx_ready2_export ready2();
        method tx_ready3_export ready3();
    endinterface
    schedule (pll.locked0, pll.locked1, pll.locked2, pll.locked3, rx.is_lockedtodata0, rx.is_lockedtodata1, rx.is_lockedtodata2, rx.is_lockedtodata3, rx.is_lockedtoref0, rx.is_lockedtoref1, rx.is_lockedtoref2, rx.is_lockedtoref3, rx.parallel_data0, rx.parallel_data1, rx.parallel_data2, rx.parallel_data3, rx.serial_data0, rx.serial_data1, rx.serial_data2, rx.serial_data3, rx.ready0, rx.ready1, rx.ready2, rx.ready3, tx.parallel_data0, tx.parallel_data1, tx.parallel_data2, tx.parallel_data3, tx.serial_data0, tx.serial_data1, tx.serial_data2, tx.serial_data3, tx.ready0, tx.ready1, tx.ready2, tx.ready3) CF (pll.locked0, pll.locked1, pll.locked2, pll.locked3, rx.is_lockedtodata0, rx.is_lockedtodata1, rx.is_lockedtodata2, rx.is_lockedtodata3, rx.is_lockedtoref0, rx.is_lockedtoref1, rx.is_lockedtoref2, rx.is_lockedtoref3, rx.parallel_data0, rx.parallel_data1, rx.parallel_data2, rx.parallel_data3, rx.serial_data0, rx.serial_data1, rx.serial_data2, rx.serial_data3, rx.ready0, rx.ready1, rx.ready2, rx.ready3, tx.parallel_data0, tx.parallel_data1, tx.parallel_data2, tx.parallel_data3, tx.serial_data0, tx.serial_data1, tx.serial_data2, tx.serial_data3, tx.ready0, tx.ready1, tx.ready2, tx.ready3);
endmodule

`else   // 1 PORT wrapper

(* always_ready, always_enabled *)
interface EthsonicpmawrapPll;
    method Bit#(1)     locked0();
endinterface
(* always_ready, always_enabled *)
interface EthsonicpmawrapRx;
    method Bit#(1)     is_lockedtodata0();
    method Bit#(1)     is_lockedtoref0();
    method Bit#(1)     ready0();
    method Bit#(66)    parallel_data0();
    method Action      serial_data0(Bit#(1) v);
endinterface
(* always_ready, always_enabled *)
interface EthsonicpmawrapTx;
    method Action      parallel_data0(Bit#(66) v);
    method Bit#(1)     serial_data0();
    method Bit#(1)     ready0();
endinterface
(* always_ready, always_enabled *)
interface EthSonicPmaWrap;
    interface EthsonicpmawrapPll       pll;
    interface EthsonicpmawrapRx        rx;
    interface EthsonicpmawrapTx        tx;
    interface Clock                    tx_clkout0;
    interface Clock                    rx_clkout0;
endinterface
import "BVI" sv_10g_pma =
module mkEthSonicPmaWrap#(Clock phy_mgmt_clk, Clock pll_ref_clk, Clock tx_coreclkin0, Reset phy_mgmt_clk_reset_n, Reset pll_ref_clk_reset_n)(EthSonicPmaWrap);
    default_clock clk();
    default_reset rst();
    input_clock phy_mgmt_clk(phy_mgmt_clk_clk) = phy_mgmt_clk;
    input_reset phy_mgmt_clk_reset_n(phy_mgmt_clk_reset_reset_n) = phy_mgmt_clk_reset_n;
    input_clock pll_ref_clk(pll_ref_clk_clk) = pll_ref_clk;
    input_reset pll_ref_clk_reset_n(pll_ref_clk_reset_reset_n) = pll_ref_clk_reset_n;
    input_clock tx_coreclkin0(tx_coreclkin0_clk) = tx_coreclkin0;

    output_clock tx_clkout0(tx_clkout0_clk);
    output_clock rx_clkout0(rx_clkout0_clk);
    interface EthsonicpmawrapPll     pll;
        method pll_locked0_export locked0() clocked_by (pll_ref_clk);
    endinterface
    interface EthsonicpmawrapRx     rx;
        method rx_is_lockedtodata0_export is_lockedtodata0();
        method rx_is_lockedtoref0_export is_lockedtoref0();
        method rx_parallel_data0_data parallel_data0() clocked_by (rx_clkout0);
        method rx_ready0_export ready0();
        method serial_data0(rx_serial_data0_export) enable((*inhigh*) EN_rx_serial_data0);
    endinterface
    interface EthsonicpmawrapTx     tx;
        method parallel_data0(tx_parallel_data0_data) clocked_by(tx_coreclkin0) enable((*inhigh*) EN_tx_parallel_data0);
        method tx_serial_data0_export serial_data0();
        method tx_ready0_export ready0();
    endinterface
    schedule (pll.locked0, rx.is_lockedtodata0, rx.is_lockedtoref0, rx.parallel_data0, rx.serial_data0, rx.ready0, tx.parallel_data0, tx.serial_data0, tx.ready0) CF (pll.locked0, rx.is_lockedtodata0, rx.is_lockedtoref0, rx.parallel_data0, rx.serial_data0, rx.ready0, tx.parallel_data0, tx.serial_data0, tx.ready0);
endmodule

`endif
