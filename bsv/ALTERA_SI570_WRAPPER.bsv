
/*
   /home/hwang/dev/sonic-lite/scripts/../../connectal//generated/scripts/importbvi.py
   -o
   ALTERA_SI570_WRAPPER.bsv
   -I
   MacWrap
   -P
   MacWrap
   -c
   iCLK
   -r
   iRST_n
   -f
   iStart
   -f
   iFREQ
   -f
   oController
   -f
   I2C
   -f
   oREAD
   -f
   oSI570
   ../verilog/si570/si570_controller.v
*/

import Clocks::*;
import DefaultValue::*;
import XilinxCells::*;
import GetPut::*;

(* always_ready, always_enabled *)
interface MacwrapI2c;
    method Bit#(1)     clk();
    interface Inout#(Bit#(1))     data;
endinterface
(* always_ready, always_enabled *)
interface MacwrapIfreq;
    method Action      mode(Bit#(3) v);
endinterface
(* always_ready, always_enabled *)
(* always_ready, always_enabled *)
interface MacwrapIstart;
    method Action      go(Bit#(1) v);
endinterface
(* always_ready, always_enabled *)
interface MacwrapOcontroller;
    method Bit#(1)     ready();
endinterface
(* always_ready, always_enabled *)
interface MacwrapOread;
    method Bit#(8)     data();
endinterface
(* always_ready, always_enabled *)
interface MacwrapOsi570;
    method Bit#(1)     one_clk_config_done();
endinterface
(* always_ready, always_enabled *)
interface MacWrap;
    interface MacwrapI2c     i2c;
    interface MacwrapIfreq     ifreq;
    interface MacwrapIstart     istart;
    interface MacwrapOcontroller     ocontroller;
    interface MacwrapOread     oread;
    interface MacwrapOsi570     osi570;
endinterface
import "BVI" si570_controller =
module mkMacWrap#(Clock iclk, Reset iclk_reset, Reset irst_n)(MacWrap);
    default_clock clk();
    default_reset rst();
    input_clock iclk(iCLK) = iclk;
    input_reset iclk_reset() = iclk_reset; /* from clock*/
        input_reset irst_n(iRST_n) = irst_n;
    interface MacwrapI2c     i2c;
        method I2C_CLK clk();
        ifc_inout data(I2C_DATA);
    endinterface
    interface MacwrapIfreq     ifreq;
        method mode(iFREQ_MODE) enable((*inhigh*) EN_iFREQ_MODE);
    endinterface
    interface MacwrapIstart     istart;
        method go(iStart_Go) enable((*inhigh*) EN_iStart_Go);
    endinterface
    interface MacwrapOcontroller     ocontroller;
        method oController_Ready ready();
    endinterface
    interface MacwrapOread     oread;
        method oREAD_Data data();
    endinterface
    interface MacwrapOsi570     osi570;
        method oSI570_ONE_CLK_CONFIG_DONE one_clk_config_done();
    endinterface
    schedule (i2c.clk, ifreq.mode, istart.go, ocontroller.ready, oread.data, osi570.one_clk_config_done) CF (i2c.clk, ifreq.mode, istart.go, ocontroller.ready, oread.data, osi570.one_clk_config_done);
endmodule
