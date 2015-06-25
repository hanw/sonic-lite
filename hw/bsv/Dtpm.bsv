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

package Dtpm;

import Clocks::*;
import FIFO::*;
import FIFOF::*;
import BRAMFIFO :: *;
import SpecialFIFOs::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;
import FShow::*;
import Probe::*;
import Pipe::*;
import Ethernet::*;
import Connectable::*;
import DtpRx::*;
import DtpTx::*;

interface Dtpm;
   interface PipeIn#(Bit#(66))  dtpRxIn;
   interface PipeIn#(Bit#(66))  dtpTxIn;
   interface PipeOut#(Bit#(66)) dtpRxOut;
   interface PipeOut#(Bit#(66)) dtpTxOut;
   interface PipeOut#(Bit#(53)) dtpLocalOut;
   interface PipeIn#(Bit#(53))  dtpGlobalIn;
   interface PipeIn#(Bit#(53))  dtpFromHost;
   interface PipeOut#(Bit#(53)) dtpToHost;
   (* always_ready, always_enabled *)
   method Action tx_ready(Bool v);
   (* always_ready, always_enabled *)
   method Action rx_ready(Bool v);
   (* always_ready, always_enabled *)
   method Action switch_mode(Bool v);
   interface DtpToPhyIfc api;
endinterface

(* synthesize *)
module mkDtpmTop(Dtpm);
   Dtpm _a <- mkDtpm(0, 0);
   return _a;
endmodule

module mkDtpm#(Integer id, Integer c_local_init)(Dtpm);

   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

   Wire#(Bool) tx_ready_wire <- mkDWire(False);
   Wire#(Bool) rx_ready_wire <- mkDWire(False);
   Wire#(Bool) switch_mode_wire <- mkDWire(False);

   DtpRx dtp_rx <- mkDtpRx(id, c_local_init);
   DtpTx dtp_tx <- mkDtpTx(id, c_local_init);

   SyncFIFOIfc#(DtpEvent) dtpEventFifo <- mkSyncBRAMFIFO(10, defaultClock, defaultReset, defaultClock, defaultReset);
   PipeOut#(DtpEvent) dtpEventOut = toPipeOut(dtpEventFifo);
   PipeIn#(DtpEvent) dtpEventIn = toPipeIn(dtpEventFifo);

   mkConnection(dtp_rx.dtpEventOut, dtpEventIn);
   mkConnection(dtpEventOut, dtp_tx.dtpEventIn);

   rule rx_rdy;
      dtp_rx.rx_ready(rx_ready_wire);
      dtp_tx.rx_ready(rx_ready_wire);
   endrule

   rule tx_rdy;
      dtp_tx.tx_ready(tx_ready_wire);
   endrule

   rule switch;
      dtp_tx.switch_mode(switch_mode_wire);
   endrule

   method Action tx_ready(Bool v);
      tx_ready_wire <= v;
   endmethod

   method Action rx_ready(Bool v);
      rx_ready_wire <= v;
   endmethod

   method Action switch_mode(Bool v);
      switch_mode_wire <= v;
   endmethod

   interface dtpRxIn  = dtp_rx.dtpRxIn;
   interface dtpRxOut = dtp_rx.dtpRxOut;
   interface dtpTxIn  = dtp_tx.dtpTxIn;
   interface dtpTxOut = dtp_tx.dtpTxOut;
   interface dtpLocalOut = dtp_tx.dtpLocalOut;
   interface dtpGlobalIn = dtp_tx.dtpGlobalIn;
   interface dtpFromHost = dtp_tx.api.fromHost;
   interface dtpToHost = dtp_tx.api.toHost;
endmodule: mkDtpm
endpackage: Dtpm
