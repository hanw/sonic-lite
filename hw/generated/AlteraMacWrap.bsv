import Clocks::*;
import DefaultValue::*;
import GetPut::*;
import Vector::*;

(* always_ready, always_enabled *)
interface Mac_rx;
    method Bit#(64)    fifo_out_data();
    method Bit#(3)     fifo_out_empty();
    method Bit#(1)     fifo_out_endofpacket();
    method Bit#(6)     fifo_out_error();
    method Action      fifo_out_ready(Bit#(1) v);
    method Bit#(1)     fifo_out_startofpacket();
    method Bit#(1)     fifo_out_valid();
endinterface
(* always_ready, always_enabled *)
interface Mac_rx_status;
    method Bit#(40)    status_data();
    method Bit#(7)     status_error();
    method Bit#(1)     status_valid();
endinterface
(* always_ready, always_enabled *)
interface Mac_tx;
    method Action      fifo_in_data(Bit#(64) v);
    method Action      fifo_in_empty(Bit#(3) v);
    method Action      fifo_in_endofpacket(Bit#(1) v);
    method Action      fifo_in_error(Bit#(1) v);
    method Bit#(1)     fifo_in_ready();
    method Action      fifo_in_startofpacket(Bit#(1) v);
    method Action      fifo_in_valid(Bit#(1) v);
endinterface
(* always_ready, always_enabled *)
interface Mac_tx_status;
    method Bit#(40)    status_data();
    method Bit#(7)     status_error();
    method Bit#(1)     status_valid();
endinterface
(* always_ready, always_enabled *)
interface Mac_xgmii;
    method Action      rx_data(Bit#(72) v);
    method Bit#(72)     tx_data();
endinterface
(* always_ready, always_enabled *)
interface Mac_link_fault;
    method Bit#(2)     status_data();
endinterface
(* always_ready, always_enabled *)
interface Mac_mgmt;
   method Action address(Bit#(17) v);
   method Action read(Bit#(1) v);
   method Action write(Bit#(1) v);
   method Action writedata(Bit#(32) v);
   method Bit#(1) waitrequest();
   method Bit#(32) readdata();
endinterface
(* always_ready, always_enabled *)
interface MacWrap;
   interface Mac_rx rx;
   interface Mac_rx_status rx_status;
   interface Mac_tx tx;
   interface Mac_tx_status tx_status;
   interface Mac_xgmii xgmii;
   interface Mac_link_fault link_fault;
   interface Mac_mgmt mgmt;
endinterface

import "BVI" mac_10gbe=
module mkMacWrap#(Clock mgmt_clk, Clock tx_clk, Clock rx_clk, Reset mgmt_reset_n, Reset tx_reset_n, Reset rx_reset_n)(MacWrap);
   default_clock clk();
   default_reset rst();
   input_clock mgmt_clk(mm_clk_clk) = mgmt_clk;
   input_reset mgmt_reset_n(mm_reset_reset_n) clocked_by (mgmt_clk) = mgmt_reset_n;
   input_clock rx_clk(rx_clk_clk) = rx_clk;
   input_reset rx_reset_n(rx_reset_reset_n) clocked_by(rx_clk) = rx_reset_n;
   input_clock tx_clk(tx_clk_clk) = tx_clk;
   input_reset tx_reset_n(tx_reset_reset_n) clocked_by(tx_clk)= tx_reset_n;

   interface Mac_link_fault     link_fault;
      method link_fault_status_xgmii_rx_data status_data();
   endinterface
   interface Mac_rx rx;
      method rx_sc_fifo_out_data fifo_out_data() clocked_by (rx_clk) reset_by (rx_reset_n);
      method rx_sc_fifo_out_empty fifo_out_empty() clocked_by (rx_clk) reset_by (rx_reset_n);
      method rx_sc_fifo_out_endofpacket fifo_out_endofpacket() clocked_by (rx_clk) reset_by (rx_reset_n);
      method rx_sc_fifo_out_error fifo_out_error() clocked_by (rx_clk) reset_by (rx_reset_n);
      method fifo_out_ready(rx_sc_fifo_out_ready) clocked_by (rx_clk) reset_by (rx_reset_n) enable((*inhigh*) EN_rx_sc_fifo_out_ready);
      method rx_sc_fifo_out_startofpacket fifo_out_startofpacket() clocked_by (rx_clk) reset_by (rx_reset_n);
      method rx_sc_fifo_out_valid fifo_out_valid() clocked_by (rx_clk) reset_by (rx_reset_n);
   endinterface
   interface Mac_tx tx;
      method fifo_in_data(tx_sc_fifo_in_data) clocked_by (tx_clk) reset_by (tx_reset_n) enable((*inhigh*) EN_tx_sc_fifo_in_data);
      method fifo_in_empty(tx_sc_fifo_in_empty) clocked_by (tx_clk) reset_by (tx_reset_n) enable((*inhigh*) EN_tx_sc_fifo_in_empty);
      method fifo_in_endofpacket(tx_sc_fifo_in_endofpacket) clocked_by (tx_clk) reset_by (tx_reset_n) enable((*inhigh*) EN_tx_sc_fifo_in_endofpacket);
      method fifo_in_error(tx_sc_fifo_in_error) clocked_by (tx_clk) reset_by (tx_reset_n) enable((*inhigh*) EN_tx_sc_fifo_in_error);
      method tx_sc_fifo_in_ready fifo_in_ready() clocked_by (tx_clk) reset_by (tx_reset_n);
      method fifo_in_startofpacket(tx_sc_fifo_in_startofpacket) clocked_by (tx_clk) reset_by (tx_reset_n) enable((*inhigh*) EN_tx_sc_fifo_in_startofpacket);
      method fifo_in_valid(tx_sc_fifo_in_valid) clocked_by (tx_clk) reset_by (tx_reset_n) enable((*inhigh*) EN_tx_sc_fifo_in_valid);
   endinterface
   interface Mac_rx_status rx_status;
      method avalon_st_rxstatus_data status_data() clocked_by (rx_clk) reset_by (rx_reset_n);
      method avalon_st_rxstatus_error status_error() clocked_by (rx_clk) reset_by (rx_reset_n);
      method avalon_st_rxstatus_valid status_valid() clocked_by (rx_clk) reset_by (rx_reset_n);
   endinterface
   interface Mac_tx_status tx_status;
      method avalon_st_txstatus_data status_data() clocked_by (tx_clk) reset_by (tx_reset_n);
      method avalon_st_txstatus_error status_error() clocked_by (tx_clk) reset_by (tx_reset_n);
      method avalon_st_txstatus_valid status_valid() clocked_by (tx_clk) reset_by (tx_reset_n);
   endinterface
   interface Mac_xgmii     xgmii;
      method rx_data(xgmii_rx_data) clocked_by (rx_clk) reset_by (rx_reset_n) enable((*inhigh*) EN_xgmii_rx_data);
      method xgmii_tx_data tx_data() clocked_by (tx_clk) reset_by (tx_reset_n);
   endinterface
   interface Mac_mgmt      mgmt;
      method address(mm_pipeline_bridge_address) clocked_by (mgmt_clk) reset_by (mgmt_reset_n) enable((*inhigh*) EN_mm_pipeline_bridge_address);
      method read(mm_pipeline_bridge_read) clocked_by (mgmt_clk) reset_by (mgmt_reset_n) enable((*inhigh*) EN_mm_pipeline_bridge_read);
      method write(mm_pipeline_bridge_write) clocked_by (mgmt_clk) reset_by (mgmt_reset_n) enable((*inhigh*) EN_mm_pipeline_bridge_write);
      method writedata(mm_pipeline_bridge_writedata) clocked_by (mgmt_clk) reset_by (mgmt_reset_n) enable((*inhigh*) EN_mm_pipeline_bridge_writedata);
      method mm_pipeline_bridge_waitrequest waitrequest() clocked_by (mgmt_clk) reset_by (mgmt_reset_n);
      method mm_pipeline_bridge_readdata readdata() clocked_by (mgmt_clk) reset_by (mgmt_reset_n);
   endinterface
   schedule (link_fault.status_data, rx.fifo_out_data, rx.fifo_out_empty, rx.fifo_out_endofpacket, rx.fifo_out_error, rx.fifo_out_ready, rx.fifo_out_startofpacket, rx.fifo_out_valid, rx_status.status_data, rx_status.status_error, rx_status.status_valid, tx.fifo_in_data, tx.fifo_in_empty, tx.fifo_in_endofpacket, tx.fifo_in_error, tx.fifo_in_ready, tx.fifo_in_startofpacket, tx.fifo_in_valid, tx_status.status_data, tx_status.status_error, tx_status.status_valid, xgmii.rx_data, xgmii.tx_data, mgmt.address, mgmt.read, mgmt.write, mgmt.writedata, mgmt.waitrequest, mgmt.readdata) CF (link_fault.status_data, rx.fifo_out_data, rx.fifo_out_empty, rx.fifo_out_endofpacket, rx.fifo_out_error, rx.fifo_out_ready, rx.fifo_out_startofpacket, rx.fifo_out_valid, rx_status.status_data, rx_status.status_error, rx_status.status_valid, tx.fifo_in_data, tx.fifo_in_empty, tx.fifo_in_endofpacket, tx.fifo_in_error, tx.fifo_in_ready, tx.fifo_in_startofpacket, tx.fifo_in_valid, tx_status.status_data, tx_status.status_error, tx_status.status_valid, xgmii.rx_data, xgmii.tx_data, mgmt.address, mgmt.read, mgmt.write, mgmt.writedata, mgmt.waitrequest, mgmt.readdata);
endmodule
