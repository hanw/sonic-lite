
/*
   /home/hwang/dev/sonic-lite/hw/scripts/../../../connectal//generated/scripts/importbvi.py
   -o
   ALTERA_ETH_10GBASER_WRAPPER.bsv
   -I
   Eth10GPhyWrap
   -P
   Eth10GPhyWrap
   -c
   pll_ref_clk
   -c
   xgmii_rx_clk
   -c
   xgmii_tx_clk
   -c
   phy_mgmt_clk
   -r
   phy_mgmt_clk_reset
   -f
   rx_ready
   -f
   tx_ready
   -f
   tx_serial
   -f
   rx_serial
   -f
   rx
   -f
   tx
   -f
   xgmii
   -f
   phy_mgmt
   -f
   reconfig
   /home/hwang/dev/fpgamake-cache/p4/de5/synthesis/altera_xcvr_10gbaser_wrapper/altera_xcvr_10gbaser_wrapper.v
*/

import Clocks::*;
import DefaultValue::*;
import XilinxCells::*;
import GetPut::*;
import AxiBits::*;

(* always_ready, always_enabled *)
interface Eth10gphywrap_PhyMgmt;
    method Action      address(Bit#(9) v);
    method Action      read(Bit#(1) v);
    method Bit#(32)     readdata();
    method Bit#(1)     waitrequest();
    method Action      write(Bit#(1) v);
    method Action      writedata(Bit#(32) v);
endinterface
(* always_ready, always_enabled *)
interface Eth10gphywrap_Reconfig;
    method Bit#(276)     from_xcvr();
    method Action      to_xcvr(Bit#(420) v);
endinterface
(* always_ready, always_enabled *)
interface Eth10gphywrap_ResetReady;
    method Bit#(1)     tx_ready();
    method Bit#(1)     rx_ready();
endinterface
(* always_ready, always_enabled *)
interface Eth10gphywrap_DataReady;
    method Bit#(4)     data_ready();
endinterface
(* always_ready, always_enabled *)
interface Eth10gphywrap_RxSerial;
    method Action      data_0(Bit#(1) v);
    method Action      data_1(Bit#(1) v);
    method Action      data_2(Bit#(1) v);
endinterface
(* always_ready, always_enabled *)
interface Eth10gphywrap_TxSerial;
    method Bit#(1)     data_0();
    method Bit#(1)     data_1();
    method Bit#(1)     data_2();
endinterface
(* always_ready, always_enabled *)
interface Eth10gphywrap_TxData;
    method Action      dc_0(Bit#(72) v);
    method Action      dc_1(Bit#(72) v);
    method Action      dc_2(Bit#(72) v);
endinterface
(* always_ready, always_enabled *)
interface Eth10gphywrap_RxData;
    method Bit#(72)     dc_0();
    method Bit#(72)     dc_1();
    method Bit#(72)     dc_2();
endinterface
(* always_ready, always_enabled *)
interface Eth10GPhyWrap;
    interface Eth10gphywrap_PhyMgmt      phy_mgmt;
    interface Eth10gphywrap_Reconfig     reconfig;
    interface Eth10gphywrap_ResetReady   rxtx;
    interface Eth10gphywrap_DataReady    rx;
    interface Eth10gphywrap_RxSerial     rx_serial;
    interface Eth10gphywrap_TxSerial     tx_serial;
    interface Eth10gphywrap_TxData       xgmii_tx;
    interface Eth10gphywrap_RxData       xgmii_rx;
    interface Clock                      xgmii_rx_clk;
endinterface
import "BVI" altera_xcvr_10gbaser_wrapper =
module mkEth10GPhyWrap#(Clock phy_mgmt_clk, Clock pll_ref_clk, Clock xgmii_tx_clk, Reset phy_mgmt_clk_reset)(Eth10GPhyWrap);
    default_clock clk();
    default_reset rst();
        input_clock phy_mgmt_clk(phy_mgmt_clk) = phy_mgmt_clk;
        input_reset phy_mgmt_clk_reset(phy_mgmt_clk_reset) = phy_mgmt_clk_reset;
        input_clock pll_ref_clk(pll_ref_clk) = pll_ref_clk;
        input_clock xgmii_tx_clk(xgmii_tx_clk) = xgmii_tx_clk;
        output_clock xgmii_rx_clk(xgmii_rx_clk);
    interface Eth10gphywrap_PhyMgmt     phy_mgmt;
        method address(phy_mgmt_address) clocked_by (phy_mgmt_clk) reset_by (phy_mgmt_clk_reset) enable((*inhigh*) EN_phy_mgmt_address);
        method read(phy_mgmt_read) clocked_by (phy_mgmt_clk) reset_by (phy_mgmt_clk_reset) enable((*inhigh*) EN_phy_mgmt_read);
        method phy_mgmt_readdata readdata() clocked_by (phy_mgmt_clk) reset_by (phy_mgmt_clk_reset);
        method phy_mgmt_waitrequest waitrequest() clocked_by (phy_mgmt_clk) reset_by (phy_mgmt_clk_reset);
        method write(phy_mgmt_write) clocked_by (phy_mgmt_clk) reset_by (phy_mgmt_clk_reset) enable((*inhigh*) EN_phy_mgmt_write);
        method writedata(phy_mgmt_writedata) clocked_by (phy_mgmt_clk) reset_by (phy_mgmt_clk_reset) enable((*inhigh*) EN_phy_mgmt_writedata);
    endinterface
    interface Eth10gphywrap_Reconfig     reconfig;
        method reconfig_from_xcvr from_xcvr();
        method to_xcvr(reconfig_to_xcvr) enable((*inhigh*) EN_reconfig_to_xcvr);
    endinterface
    interface Eth10gphywrap_ResetReady     rxtx;
        method rx_ready rx_ready();
        method tx_ready tx_ready();
    endinterface
    interface Eth10gphywrap_DataReady     rx;
        method rx_data_ready data_ready();
    endinterface
    interface Eth10gphywrap_RxSerial     rx_serial;
        method data_0(rx_serial_data_0) enable((*inhigh*) EN_rx_serial_data_0);
        method data_1(rx_serial_data_1) enable((*inhigh*) EN_rx_serial_data_1);
        method data_2(rx_serial_data_2) enable((*inhigh*) EN_rx_serial_data_2);
    endinterface
    interface Eth10gphywrap_TxSerial     tx_serial;
        method tx_serial_data_0 data_0();
        method tx_serial_data_1 data_1();
        method tx_serial_data_2 data_2();
    endinterface
    interface Eth10gphywrap_TxData     xgmii_tx;
        method dc_0(xgmii_tx_dc_0) clocked_by (xgmii_tx_clk) enable((*inhigh*) EN_xgmii_tx_dc_0);
        method dc_1(xgmii_tx_dc_1) clocked_by (xgmii_tx_clk) enable((*inhigh*) EN_xgmii_tx_dc_1);
        method dc_2(xgmii_tx_dc_2) clocked_by (xgmii_tx_clk) enable((*inhigh*) EN_xgmii_tx_dc_2);
    endinterface
    interface Eth10gphywrap_RxData     xgmii_rx;
        method xgmii_rx_dc_0 dc_0() clocked_by (xgmii_rx_clk);
        method xgmii_rx_dc_1 dc_1() clocked_by (xgmii_rx_clk);
        method xgmii_rx_dc_2 dc_2() clocked_by (xgmii_rx_clk);
    endinterface
    schedule (phy_mgmt.address, phy_mgmt.read, phy_mgmt.readdata, phy_mgmt.waitrequest, phy_mgmt.write, phy_mgmt.writedata, reconfig.from_xcvr, reconfig.to_xcvr, rx.data_ready, rxtx.rx_ready, rx_serial.data_0, rx_serial.data_1, rx_serial.data_2, rxtx.tx_ready, tx_serial.data_0, tx_serial.data_1, tx_serial.data_2, xgmii_rx.dc_0, xgmii_rx.dc_1, xgmii_rx.dc_2, xgmii_tx.dc_0, xgmii_tx.dc_1, xgmii_tx.dc_2) CF (phy_mgmt.address, phy_mgmt.read, phy_mgmt.readdata, phy_mgmt.waitrequest, phy_mgmt.write, phy_mgmt.writedata, reconfig.from_xcvr, reconfig.to_xcvr, rx.data_ready, rxtx.rx_ready, rx_serial.data_0, rx_serial.data_1, rx_serial.data_2, rxtx.tx_ready, tx_serial.data_0, tx_serial.data_1, tx_serial.data_2, xgmii_rx.dc_0, xgmii_rx.dc_1, xgmii_rx.dc_2, xgmii_tx.dc_0, xgmii_tx.dc_1, xgmii_tx.dc_2);
endmodule
