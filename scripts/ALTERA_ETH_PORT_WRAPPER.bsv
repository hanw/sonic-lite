
/*
   /home/hwang/dev/sonic-lite/scripts/../../connectal//generated/scripts/importbvi.py
   -o
   ALTERA_ETH_PORT_WRAPPER.bsv
   -I
   EthPortWrap
   -P
   EthPortWrap
   -r
   rst_in
   -c
   clk_in
   -f
   xcvr
   -f
   xgmii
   -f
   export
   -f
   ctrl
   -f
   counter
   -f
   init
   -f
   sync
   -f
   endec
   ../verilog/port/sonic_single_port.sv
*/

import Clocks::*;
import DefaultValue::*;
import XilinxCells::*;
import GetPut::*;

(* always_ready, always_enabled *)
(* always_ready, always_enabled *)
interface EthportwrapCounter;
    method Action      global(wire v);
    method wire     local();
endinterface
(* always_ready, always_enabled *)
interface EthportwrapCtrl;
    method Action      bypass(wire v);
    method Action      clear(wire v);
    method Action      disable(wire v);
    method Action      filter_disable(wire v);
    method Action      mode(wire v);
    method Action      thres(wire v);
endinterface
(* always_ready, always_enabled *)
interface EthportwrapEndec;
    method Action      loopback(wire v);
endinterface
(* always_ready, always_enabled *)
interface EthportwrapExport;
    method wire     data();
    method wire     delay();
    method wire     valid();
endinterface
(* always_ready, always_enabled *)
interface EthportwrapInit;
    method Action      timeout(wire v);
endinterface
(* always_ready, always_enabled *)
(* always_ready, always_enabled *)
interface EthportwrapSync;
    method Action      timeout(wire v);
endinterface
(* always_ready, always_enabled *)
interface EthportwrapXcvr;
    method Action      rx_clkout(wire v);
    method Action      rx_datain(wire v);
    method Action      rx_ready(wire v);
    method Action      tx_clkout(wire v);
    method wire     tx_dataout();
    method Action      tx_ready(wire v);
endinterface
(* always_ready, always_enabled *)
interface EthportwrapXgmii;
    method wire     rx_data();
    method Action      tx_data(wire v);
endinterface
(* always_ready, always_enabled *)
interface EthPortWrap;
    interface EthportwrapCounter     counter;
    interface EthportwrapCtrl     ctrl;
    interface EthportwrapEndec     endec;
    interface EthportwrapExport     export;
    interface EthportwrapInit     init;
    interface EthportwrapSync     sync;
    interface EthportwrapXcvr     xcvr;
    interface EthportwrapXgmii     xgmii;
endinterface
import "BVI" sonic_single_port =
module mkEthPortWrap#(Clock clk_in, Reset clk_in_reset, Reset rst_in)(EthPortWrap);
    default_clock clk();
    default_reset rst();
        input_clock clk_in(clk_in) = clk_in;
        input_reset clk_in_reset() = clk_in_reset; /* from clock*/
        input_reset rst_in(rst_in) = rst_in;
    interface EthportwrapCounter     counter;
        method global(counter_global) enable((*inhigh*) EN_counter_global);
        method counter_local local();
    endinterface
    interface EthportwrapCtrl     ctrl;
        method bypass(ctrl_bypass) enable((*inhigh*) EN_ctrl_bypass);
        method clear(ctrl_clear) enable((*inhigh*) EN_ctrl_clear);
        method disable(ctrl_disable) enable((*inhigh*) EN_ctrl_disable);
        method filter_disable(ctrl_filter_disable) enable((*inhigh*) EN_ctrl_filter_disable);
        method mode(ctrl_mode) enable((*inhigh*) EN_ctrl_mode);
        method thres(ctrl_thres) enable((*inhigh*) EN_ctrl_thres);
    endinterface
    interface EthportwrapEndec     endec;
        method loopback(endec_loopback) enable((*inhigh*) EN_endec_loopback);
    endinterface
    interface EthportwrapExport     export;
        method export_data data();
        method export_delay delay();
        method export_valid valid();
    endinterface
    interface EthportwrapInit     init;
        method timeout(init_timeout) enable((*inhigh*) EN_init_timeout);
    endinterface
    interface EthportwrapSync     sync;
        method timeout(sync_timeout) enable((*inhigh*) EN_sync_timeout);
    endinterface
    interface EthportwrapXcvr     xcvr;
        method rx_clkout(xcvr_rx_clkout) enable((*inhigh*) EN_xcvr_rx_clkout);
        method rx_datain(xcvr_rx_datain) enable((*inhigh*) EN_xcvr_rx_datain);
        method rx_ready(xcvr_rx_ready) enable((*inhigh*) EN_xcvr_rx_ready);
        method tx_clkout(xcvr_tx_clkout) enable((*inhigh*) EN_xcvr_tx_clkout);
        method xcvr_tx_dataout tx_dataout();
        method tx_ready(xcvr_tx_ready) enable((*inhigh*) EN_xcvr_tx_ready);
    endinterface
    interface EthportwrapXgmii     xgmii;
        method xgmii_rx_data rx_data();
        method tx_data(xgmii_tx_data) enable((*inhigh*) EN_xgmii_tx_data);
    endinterface
    schedule (counter.global, counter.local, ctrl.bypass, ctrl.clear, ctrl.disable, ctrl.filter_disable, ctrl.mode, ctrl.thres, endec.loopback, export.data, export.delay, export.valid, init.timeout, sync.timeout, xcvr.rx_clkout, xcvr.rx_datain, xcvr.rx_ready, xcvr.tx_clkout, xcvr.tx_dataout, xcvr.tx_ready, xgmii.rx_data, xgmii.tx_data) CF (counter.global, counter.local, ctrl.bypass, ctrl.clear, ctrl.disable, ctrl.filter_disable, ctrl.mode, ctrl.thres, endec.loopback, export.data, export.delay, export.valid, init.timeout, sync.timeout, xcvr.rx_clkout, xcvr.rx_datain, xcvr.rx_ready, xcvr.tx_clkout, xcvr.tx_dataout, xcvr.tx_ready, xgmii.rx_data, xgmii.tx_data);
endmodule
