
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
   log
   -f
   ctrl
   -f
   cntr
   -f
   timeout
   -f
   lpbk
   ../verilog/port/sonic_single_port.sv
*/

import Clocks::*;
import DefaultValue::*;
import XilinxCells::*;
import GetPut::*;

(* always_ready, always_enabled *)
(* always_ready, always_enabled *)
interface EthportwrapCntr;
    method Action      global_state(Bit#(53) v);
    method Bit#(53)     local_state();
endinterface
(* always_ready, always_enabled *)
interface EthportwrapCtrl;
    method Action      bypass_clksync(Bit#(1) v);
    method Action      clear_local_state(Bit#(1) v);
    method Action      disable_clksync(Bit#(1) v);
    method Action      disable_ecc(Bit#(1) v);
    method Action      error_bound(Bit#(32) v);
    method Action      mode(Bit#(1) v);
endinterface
(* always_ready, always_enabled *)
interface EthportwrapLog;
    method Bit#(512)   data();
    method Bit#(16)    delay();
    method Bit#(1)     valid();
endinterface
(* always_ready, always_enabled *)
interface EthportwrapLpbk;
    method Action      endec(Bit#(1) v);
endinterface
(* always_ready, always_enabled *)
(* always_ready, always_enabled *)
interface EthportwrapTimeout;
    method Action      init(Bit#(32) v);
    method Action      sync(Bit#(32) v);
endinterface
(* always_ready, always_enabled *)
interface EthportwrapXcvr;
    method Action      rx_clkout(Bit#(1) v);
    method Action      rx_datain(Bit#(40) v);
    method Action      rx_ready(Bit#(1) v);
    method Action      tx_clkout(Bit#(1) v);
    method Bit#(40)     tx_dataout();
    method Action      tx_ready(Bit#(1) v);
endinterface
(* always_ready, always_enabled *)
interface EthportwrapXgmii;
    method Bit#(72)     rx_data();
    method Action      tx_data(Bit#(72) v);
endinterface
(* always_ready, always_enabled *)
interface EthPortWrap;
    interface EthportwrapCntr     cntr;
    interface EthportwrapCtrl     ctrl;
    interface EthportwrapLog     log;
    interface EthportwrapLpbk     lpbk;
    interface EthportwrapTimeout     timeout;
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
    interface EthportwrapCntr     cntr;
        method global_state(cntr_global_state) enable((*inhigh*) EN_cntr_global_state);
        method cntr_local_state local_state();
    endinterface
    interface EthportwrapCtrl     ctrl;
        method bypass_clksync(ctrl_bypass_clksync) enable((*inhigh*) EN_ctrl_bypass_clksync);
        method clear_local_state(ctrl_clear_local_state) enable((*inhigh*) EN_ctrl_clear_local_state);
        method disable_clksync(ctrl_disable_clksync) enable((*inhigh*) EN_ctrl_disable_clksync);
        method disable_ecc(ctrl_disable_ecc) enable((*inhigh*) EN_ctrl_disable_ecc);
        method error_bound(ctrl_error_bound) enable((*inhigh*) EN_ctrl_error_bound);
        method mode(ctrl_mode) enable((*inhigh*) EN_ctrl_mode);
    endinterface
    interface EthportwrapLog     log;
        method log_data data();
        method log_delay delay();
        method log_valid valid();
    endinterface
    interface EthportwrapLpbk     lpbk;
        method endec(lpbk_endec) enable((*inhigh*) EN_lpbk_endec);
    endinterface
    interface EthportwrapTimeout     timeout;
        method init(timeout_init) enable((*inhigh*) EN_timeout_init);
        method sync(timeout_sync) enable((*inhigh*) EN_timeout_sync);
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
    schedule (cntr.global_state, cntr.local_state, ctrl.bypass_clksync, ctrl.clear_local_state, ctrl.disable_clksync, ctrl.disable_ecc, ctrl.error_bound, ctrl.mode, log.data, log.delay, log.valid, lpbk.endec, timeout.init, timeout.sync, xcvr.rx_clkout, xcvr.rx_datain, xcvr.rx_ready, xcvr.tx_clkout, xcvr.tx_dataout, xcvr.tx_ready, xgmii.rx_data, xgmii.tx_data) CF (cntr.global_state, cntr.local_state, ctrl.bypass_clksync, ctrl.clear_local_state, ctrl.disable_clksync, ctrl.disable_ecc, ctrl.error_bound, ctrl.mode, log.data, log.delay, log.valid, lpbk.endec, timeout.init, timeout.sync, xcvr.rx_clkout, xcvr.rx_datain, xcvr.rx_ready, xcvr.tx_clkout, xcvr.tx_dataout, xcvr.tx_ready, xgmii.rx_data, xgmii.tx_data);
endmodule
