
/*
   /home/hwang/dev/sonic-lite/scripts/../../connectal//generated/scripts/importbvi.py
   -o
   ALTERA_EDGE_DETECTOR_WRAPPER.bsv
   -I
   EdgeDetectorWrap
   -P
   EdgeDetectorWrap
   -c
   iCLK
   -r
   iRST_n
   -f
   iTrigger
   -f
   oFall
   -f
   oRis
   -f
   oDebounce
   ../verilog/si570/edge_detector.v
*/

import Clocks::*;
import DefaultValue::*;
import XilinxCells::*;
import GetPut::*;

(* always_ready, always_enabled *)
(* always_ready, always_enabled *)
interface EdgedetectorwrapItrigger;
    method Action      in(Bit#(1) v);
endinterface
(* always_ready, always_enabled *)
interface EdgedetectorwrapOdebounce;
    method Bit#(1)     out();
endinterface
(* always_ready, always_enabled *)
interface EdgedetectorwrapOfall;
    method Bit#(1)     ing_edge();
endinterface
(* always_ready, always_enabled *)
interface EdgedetectorwrapOris;
    method Bit#(1)     ing_edge();
endinterface
(* always_ready, always_enabled *)
interface EdgeDetectorWrap;
    interface EdgedetectorwrapItrigger     itrigger;
    interface EdgedetectorwrapOdebounce     odebounce;
    interface EdgedetectorwrapOfall     ofall;
    interface EdgedetectorwrapOris     oris;
endinterface
import "BVI" edge_detector =
module mkEdgeDetectorWrap#(Clock iclk, Reset iclk_reset)(EdgeDetectorWrap);
    default_clock clk();
    default_reset rst();
    input_clock iclk(iCLK) = iclk;
    input_reset iclk_reset(iRST_n) = iclk_reset; /* from clock*/
    interface EdgedetectorwrapItrigger     itrigger;
        method in(iTrigger_in) enable((*inhigh*) EN_iTrigger_in);
    endinterface
    interface EdgedetectorwrapOdebounce     odebounce;
        method oDebounce_out out();
    endinterface
    interface EdgedetectorwrapOfall     ofall;
        method oFalling_edge ing_edge();
    endinterface
    interface EdgedetectorwrapOris     oris;
        method oRising_edge ing_edge();
    endinterface
    schedule (itrigger.in, odebounce.out, ofall.ing_edge, oris.ing_edge) CF (itrigger.in, odebounce.out, ofall.ing_edge, oris.ing_edge);
endmodule
