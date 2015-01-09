
/*
   /home/hwang/dev/sonic-lite/scripts/../../connectal//generated/scripts/importbvi.py
   -o
   DTP_GLOBAL_TIMESTAMP_WRAPPER.bsv
   -I
   DtpGlobalWrap
   -P
   DtpGlobalWrap
   -c
   clock
   -r
   reset
   -f
   timestamp
   ../verilog/timestamp/global_timestamp.sv
*/

import Clocks::*;
import DefaultValue::*;
import XilinxCells::*;
import GetPut::*;

(* always_ready, always_enabled *)
interface DtpglobalwrapTimestamp;
    method Bit#(53)     maximum();
    method Action      p0(Bit#(53) v);
    method Action      p1(Bit#(53) v);
    method Action      p2(Bit#(53) v);
    method Action      p3(Bit#(53) v);
endinterface
(* always_ready, always_enabled *)
interface DtpGlobalWrap;
    interface DtpglobalwrapTimestamp     timestamp;
endinterface
import "BVI" global_timestamp =
module mkDtpGlobalWrap#(Clock clock, Reset clock_reset, Reset reset)(DtpGlobalWrap);
    default_clock clk();
    default_reset rst();
    input_clock clock(clock) = clock;
    input_reset clock_reset() = clock_reset; /* from clock*/
    input_reset reset(reset) = reset;
    interface DtpglobalwrapTimestamp     timestamp;
        method timestamp_maximum maximum();
        method p0(timestamp_p0) enable((*inhigh*) EN_timestamp_p0);
        method p1(timestamp_p1) enable((*inhigh*) EN_timestamp_p1);
        method p2(timestamp_p2) enable((*inhigh*) EN_timestamp_p2);
        method p3(timestamp_p3) enable((*inhigh*) EN_timestamp_p3);
    endinterface
    schedule (timestamp.maximum, timestamp.p0, timestamp.p1, timestamp.p2, timestamp.p3) CF (timestamp.maximum, timestamp.p0, timestamp.p1, timestamp.p2, timestamp.p3);
endmodule
