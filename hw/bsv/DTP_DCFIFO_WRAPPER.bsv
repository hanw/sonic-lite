
/*
   /home/kslee/sonic/sonic-lite/hw/scripts/../../../connectal//generated/scripts/importbvi.py
   -o
   ../generated/DTP_DCFIFO_WRAPPER.bsv
   -I
   DtpDCFifoWrap
   -P
   DtpDCFifoWrap
   -c
   rdclk
   -c
   wrclk
   -r
   aclr
   ../verilog/asyncfifo/fifo.v
*/

import Clocks::*;
import DefaultValue::*;
import XilinxCells::*;
import GetPut::*;
import AxiBits::*;
import Ethernet ::*;

//(* always_ready, always_enabled *)
/* SyncFifoIfc 
interface SyncFIFOIfc #(type a_type) ;
    method Action enq ( a_type sendData ) ;
    method Action deq () ;
    method a_type first () ;
    method Bool notFull () ;
    method Bool notEmpty () ;
endinterface
*/
(* always_ready, always_enabled *)
interface DtpDCFifoWrap;
    method Action       enq(DtpEvent v);
    method Action       deq();
    method DtpEvent     first();
    method Bool wrFull();
    method Bool rdEmpty();
endinterface

import "BVI" fifo =
module mkDtpDCFifoWrap#(Clock wrclk, Reset aclr, Clock rdclk)(DtpDCFifoWrap);
    default_clock clk() = wrclk;
    default_reset rst() = aclr;
    input_reset aclr(aclr) = aclr;
    input_clock rdclk(rdclk, (*unused*) UNUSED) = rdclk;   
    input_clock wrclk(wrclk, (*unused*) UNUSED) = wrclk;

    method enq (data) enable(wrreq) clocked_by (wrclk);
    method deq ()   enable(rdreq) clocked_by (rdclk);
    method q first() clocked_by (rdclk);
    method rdempty rdEmpty() clocked_by (rdclk);
    method wrfull wrFull() clocked_by (wrclk);

    schedule (enq, wrFull) CF (deq, first, rdEmpty);
    schedule (first, rdEmpty) CF (first, rdEmpty);
    schedule (wrFull) CF (wrFull);
    schedule first SB (deq);
    schedule (rdEmpty) SB (deq);
    schedule (wrFull) SB (enq);
    schedule deq C deq;
    schedule enq C enq;
endmodule
