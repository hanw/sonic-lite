
/*
   /home/hwang/dev/sonic-lite/scripts/../../connectal//generated/scripts/importbvi.py
   -o
   ALTERA_SI570_WRAPPER.bsv
   -I
   Si570Wrap
   -P
   Si570Wrap
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
interface Si570wrapI2c;
    method Bit#(1)     clk();
    interface Inout#(Bit#(1))     data;
endinterface
(* always_ready, always_enabled *)
interface Si570wrapIfreq;
    method Action      mode(Bit#(3) v);
endinterface
(* always_ready, always_enabled *)
(* always_ready, always_enabled *)
interface Si570wrapIstart;
    method Action      go(Bit#(1) v);
endinterface
(* always_ready, always_enabled *)
interface Si570wrapOcontroller;
    method Bit#(1)     rdy();
endinterface
(* always_ready, always_enabled *)
interface Si570wrapOread;
    method Bit#(8)     data();
endinterface
(* always_ready, always_enabled *)
interface Si570wrapOsi570;
    method Bit#(1)     one_clk_config_done();
endinterface
(* always_ready, always_enabled *)
interface Si570Wrap;
    interface Si570wrapI2c     i2c;
    interface Si570wrapIfreq     ifreq;
    interface Si570wrapIstart     istart;
    interface Si570wrapOcontroller     ocontroller;
    interface Si570wrapOread     oread;
    interface Si570wrapOsi570     osi570;
endinterface
import "BVI" si570_controller =
module mkSi570Wrap#(Clock iclk, Reset iclk_reset)(Si570Wrap);
    default_clock clk();
    default_reset rst();
    input_clock iclk(iCLK) = iclk;
    input_reset iclk_reset(iRST_n) = iclk_reset; /* from clock*/
    interface Si570wrapI2c     i2c;
        method I2C_CLK clk();
        ifc_inout data(I2C_DATA);
    endinterface
    interface Si570wrapIfreq     ifreq;
        method mode(iFREQ_MODE) enable((*inhigh*) EN_iFREQ_MODE);
    endinterface
    interface Si570wrapIstart     istart;
        method go(iStart_Go) enable((*inhigh*) EN_iStart_Go);
    endinterface
    interface Si570wrapOcontroller     ocontroller;
        method oController_rdy rdy();
    endinterface
    interface Si570wrapOread     oread;
        method oREAD_Data data();
    endinterface
    interface Si570wrapOsi570     osi570;
        method oSI570_ONE_CLK_CONFIG_DONE one_clk_config_done();
    endinterface
    schedule (i2c.clk, ifreq.mode, istart.go, ocontroller.rdy, oread.data, osi570.one_clk_config_done) CF (i2c.clk, ifreq.mode, istart.go, ocontroller.rdy, oread.data, osi570.one_clk_config_done);
endmodule
