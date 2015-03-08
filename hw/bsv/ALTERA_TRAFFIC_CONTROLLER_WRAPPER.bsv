
/*
   /home/hwang/dev/sonic-lite/scripts/../../connectal//generated/scripts/importbvi.py
   -o
   ALTERA_TRAFFIC_CONTROLLER_WRAPPER.bsv
   -I
   TrafficCtrlWrap
   -P
   TrafficCtrlWrap
   -r
   reset_n
   -c
   clk_in
   -f
   avl_mm
   -f
   avl_st_tx
   -f
   avl_st_rx
   -f
   mac_rx
   -f
   stop
   -f
   mon
   ../verilog/traffic_controller/avalon_st_traffic_controller.v
*/

import Clocks::*;
import DefaultValue::*;
import XilinxCells::*;
import GetPut::*;

(* always_ready, always_enabled *)
interface TrafficctrlwrapAvl_mm;
    method Action      baddress(Bit#(24) v);
    method Action      read(Bit#(1) v);
    method Bit#(32)     readdata();
    method Bit#(1)     waitrequest();
    method Action      write(Bit#(1) v);
    method Action      writedata(Bit#(32) v);
endinterface
(* always_ready, always_enabled *)
interface TrafficctrlwrapAvl_st_rx;
    method Action      data(Bit#(64) v);
    method Action      empty(Bit#(3) v);
    method Action      eop(Bit#(1) v);
    method Action      error(Bit#(6) v);
    method Bit#(1)     rdy();
    method Action      sop(Bit#(1) v);
    method Action      val(Bit#(1) v);
endinterface
(* always_ready, always_enabled *)
interface TrafficctrlwrapAvl_st_tx;
    method Bit#(64)     data();
    method Bit#(3)     empty();
    method Bit#(1)     eop();
    method Bit#(1)     error();
    method Action      rdy(Bit#(1) v);
    method Bit#(1)     sop();
    method Bit#(1)     val();
endinterface
(* always_ready, always_enabled *)
interface TrafficctrlwrapMac_rx;
    method Action      status_data(Bit#(40) v);
    method Action      status_error(Bit#(1) v);
    method Action      status_valid(Bit#(1) v);
endinterface
(* always_ready, always_enabled *)
interface TrafficctrlwrapMon;
    method Bit#(1)     active();
    method Bit#(1)     done();
    method Bit#(1)     error();
endinterface
(* always_ready, always_enabled *)
interface TrafficctrlwrapStop;
    method Action      mon(Bit#(1) v);
endinterface
(* always_ready, always_enabled *)
interface TrafficCtrlWrap;
    interface TrafficctrlwrapAvl_mm     avl_mm;
    interface TrafficctrlwrapAvl_st_rx     avl_st_rx;
    interface TrafficctrlwrapAvl_st_tx     avl_st_tx;
    interface TrafficctrlwrapMac_rx     mac_rx;
    interface TrafficctrlwrapMon     mon;
    interface TrafficctrlwrapStop     stop;
endinterface
import "BVI" avalon_st_traffic_controller =
module mkTrafficCtrlWrap#(Clock clk_in, Reset clk_in_reset, Reset reset_n)(TrafficCtrlWrap);
    default_clock clk();
    default_reset rst();
        input_clock clk_in(clk_in) = clk_in;
        input_reset clk_in_reset() = clk_in_reset; /* from clock*/
        input_reset reset_n(reset_n) = reset_n;
    interface TrafficctrlwrapAvl_mm     avl_mm;
        method baddress(avl_mm_baddress) enable((*inhigh*) EN_avl_mm_baddress);
        method read(avl_mm_read) enable((*inhigh*) EN_avl_mm_read);
        method avl_mm_readdata readdata();
        method avl_mm_waitrequest waitrequest();
        method write(avl_mm_write) enable((*inhigh*) EN_avl_mm_write);
        method writedata(avl_mm_writedata) enable((*inhigh*) EN_avl_mm_writedata);
    endinterface
    interface TrafficctrlwrapAvl_st_rx     avl_st_rx;
        method data(avl_st_rx_data) enable((*inhigh*) EN_avl_st_rx_data);
        method empty(avl_st_rx_empty) enable((*inhigh*) EN_avl_st_rx_empty);
        method eop(avl_st_rx_eop) enable((*inhigh*) EN_avl_st_rx_eop);
        method error(avl_st_rx_error) enable((*inhigh*) EN_avl_st_rx_error);
        method avl_st_rx_rdy rdy();
        method sop(avl_st_rx_sop) enable((*inhigh*) EN_avl_st_rx_sop);
        method val(avl_st_rx_val) enable((*inhigh*) EN_avl_st_rx_val);
    endinterface
    interface TrafficctrlwrapAvl_st_tx     avl_st_tx;
        method avl_st_tx_data data();
        method avl_st_tx_empty empty();
        method avl_st_tx_eop eop();
        method avl_st_tx_error error();
        method rdy(avl_st_tx_rdy) enable((*inhigh*) EN_avl_st_tx_rdy);
        method avl_st_tx_sop sop();
        method avl_st_tx_val val();
    endinterface
    interface TrafficctrlwrapMac_rx     mac_rx;
        method status_data(mac_rx_status_data) enable((*inhigh*) EN_mac_rx_status_data);
        method status_error(mac_rx_status_error) enable((*inhigh*) EN_mac_rx_status_error);
        method status_valid(mac_rx_status_valid) enable((*inhigh*) EN_mac_rx_status_valid);
    endinterface
    interface TrafficctrlwrapMon     mon;
        method mon_active active();
        method mon_done done();
        method mon_error error();
    endinterface
    interface TrafficctrlwrapStop     stop;
        method mon(stop_mon) enable((*inhigh*) EN_stop_mon);
    endinterface
    schedule (avl_mm.baddress, avl_mm.read, avl_mm.readdata, avl_mm.waitrequest, avl_mm.write, avl_mm.writedata, avl_st_rx.data, avl_st_rx.empty, avl_st_rx.eop, avl_st_rx.error, avl_st_rx.rdy, avl_st_rx.sop, avl_st_rx.val, avl_st_tx.data, avl_st_tx.empty, avl_st_tx.eop, avl_st_tx.error, avl_st_tx.rdy, avl_st_tx.sop, avl_st_tx.val, mac_rx.status_data, mac_rx.status_error, mac_rx.status_valid, mon.active, mon.done, mon.error, stop.mon) CF (avl_mm.baddress, avl_mm.read, avl_mm.readdata, avl_mm.waitrequest, avl_mm.write, avl_mm.writedata, avl_st_rx.data, avl_st_rx.empty, avl_st_rx.eop, avl_st_rx.error, avl_st_rx.rdy, avl_st_rx.sop, avl_st_rx.val, avl_st_tx.data, avl_st_tx.empty, avl_st_tx.eop, avl_st_tx.error, avl_st_tx.rdy, avl_st_tx.sop, avl_st_tx.val, mac_rx.status_data, mac_rx.status_error, mac_rx.status_valid, mon.active, mon.done, mon.error, stop.mon);
endmodule
