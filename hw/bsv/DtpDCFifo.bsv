// Copyright (c) 2014 Cornell University.

// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

package DtpDCFifo;

import Clocks ::*;
import FIFOF ::*;
import SpecialFIFOs ::*;
import Pipe ::*;
import Ethernet ::*;
import DTP_DCFIFO_WRAPPER ::*;

//TODO: Xilinx and Altera
/* SyncFifoIfc 
interface SyncFIFOIfc #(type a_type) ;
    method Action enq ( a_type sendData ) ;
    method Action deq () ;
    method a_type first () ;
    method Bool notFull () ;
    method Bool notEmpty () ;
endinterface
*/

module mkDtpDCFifo#(Clock wrclk, Reset wrrst, Clock rdclk)(SyncFIFOIfc#(DtpEvent));

    Reset wrrst_n <- mkResetInverter(wrrst, clocked_by wrclk);
    DtpDCFifoWrap dc <- mkDtpDCFifoWrap(wrclk, wrrst_n, rdclk);

    method Action enq (DtpEvent v) if (!dc.wrFull);
        dc.enq(v);
    endmethod

    method Action deq () if (!dc.rdEmpty);
        dc.deq();
    endmethod
    
    method DtpEvent first();
        return dc.first();
    endmethod

    method Bool notEmpty() ;
        return !dc.rdEmpty();
    endmethod

    method Bool notFull() ;
        return !dc.wrFull();
    endmethod

endmodule

endpackage
