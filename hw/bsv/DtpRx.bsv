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

package DtpRx;

import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;
import FShow::*;
import Probe::*;
import Pipe::*;
import Ethernet::*;

typedef 3'b100 LOG_TYPE;
typedef 2'b01 INIT_TYPE;
typedef 2'b10 ACK_TYPE;
typedef 2'b11 BEACON_TYPE;
typedef 5 RXTX_DELAY;

interface DtpRx;
   interface PipeIn#(Bit#(66))  dtpRxIn;
   interface PipeOut#(Bit#(66)) dtpRxOut;
   interface PipeOut#(DtpEvent) dtpEventOut;
   interface PipeOut#(Bit#(32)) dtpErrCnt;
   (* always_ready, always_enabled *)
   method Action rx_ready(Bool v);
   method Action bsync_lock(Bool v);
endinterface

(* synthesize *)
module mkDtpRxTop(DtpRx);
   DtpRx _a <- mkDtpRx(0, 0);
   return _a;
endmodule

module mkDtpRx#(Integer id, Integer c_local_init)(DtpRx);

   let verbose = True;

   Reg#(Bit#(32))  cycle   <- mkReg(0);
   Wire#(Bool) rx_ready_wire <- mkDWire(False);
   Wire#(Bool) bsync_lock_wire <- mkDWire(False);

   FIFOF#(Bit#(66)) dtpRxInFifo    <- mkFIFOF;
   FIFOF#(Bit#(66)) dtpRxOutFifo   <- mkFIFOF;
   FIFOF#(DtpEvent) dtpEventOutFifo <- mkFIFOF;
   FIFOF#(Bit#(32)) dtpErrCntFifo  <- mkFIFOF;

   Reg#(Bit#(32))  err_cnt <- mkReg(0);

   rule cyc;
      cycle <= cycle + 1;
   endrule

   rule rx_bypass(!rx_ready_wire);
      let v <- toGet(dtpRxInFifo).get;
      dtpRxOutFifo.enq(v);
   endrule

   // Parse received DTP frame
   // Remove DTP timestamp before passing frame to MAC.
   rule parse_dtp_message(rx_ready_wire);
      let init_type   = fromInteger(valueOf(INIT_TYPE));
      let ack_type    = fromInteger(valueOf(ACK_TYPE));
      let beacon_type = fromInteger(valueOf(BEACON_TYPE));
      let log_type    = fromInteger(valueOf(LOG_TYPE));
      let rxtx_delay  = fromInteger(valueOf(RXTX_DELAY));
      let v <- toGet(dtpRxInFifo).get();
      //if(verbose) $display("%d: %d dtpRxIn=%h", cycle, id, v);
      Bit#(1)  parity = ^v[65:13];
      Bit#(53) c_remote = v[65:13];
      Bit#(66) vo = v;

      let c_remote_compensated = c_remote + rxtx_delay;

      if (v[9:2] == 8'h1e && bsync_lock_wire) begin
         vo[65:10] = 56'h0;
         if (v[11:10] == init_type ) begin
            if (parity == v[12]) begin
               if(dtpEventOutFifo.notFull) begin
                  dtpEventOutFifo.enq(DtpEvent{e:zeroExtend(v[11:10]), t:c_remote});
               end
               if(verbose) $display("%d: %d init_rcvd %d, forward to tx %d", cycle, id, c_remote, c_remote_compensated);
            end
            else begin
               $display("parity mismatch: expected %h, found %h", parity, v[12]);
            end
         end
         else if (v[11:10] == ack_type) begin
            if (parity == v[12]) begin
               if(dtpEventOutFifo.notFull) begin
                  dtpEventOutFifo.enq(DtpEvent{e:zeroExtend(v[11:10]), t:c_remote});
               end
               if(verbose) $display("%d: %d ack_rcvd %d, forward to tx %d", cycle, id, c_remote, c_remote_compensated);
            end
            else begin
               $display("parity mismatch: expected %h, found %h", parity, v[12]);
            end
         end
         else if (v[11:10] == beacon_type) begin
            if (parity == v[12]) begin
               if(dtpEventOutFifo.notFull) begin
                  dtpEventOutFifo.enq(DtpEvent{e:zeroExtend(v[11:10]), t:c_remote_compensated});
               end
               if(verbose) $display("%d: %d beacon_rcvd %d, forward to tx %d", cycle, id, c_remote, c_remote_compensated);
            end
            else begin
               $display("parity mismatch: expected %h, found %h", parity, v[12]);
            end
         end
         else if (v[12:10] == log_type) begin
            // send v[65:13] to logger, when bsync_lock is True
            if (dtpEventOutFifo.notFull) begin
               $display("%d: %d received log message %h", cycle, id, v[65:13]);
               dtpEventOutFifo.enq(DtpEvent{e:v[12:10], t:v[65:13]});
            end
         end
         else if (v[12:10] != 3'b0) begin
            err_cnt <= err_cnt + 1;
            dtpErrCntFifo.enq(err_cnt);
         end
         else begin
            // normal 0x1e idle frame
         end
      end
      //if(verbose) $display("%d: %d curr_state=%h", cycle, id, curr_state);
      dtpRxOutFifo.enq(vo);
   endrule

   method Action rx_ready(Bool v);
      rx_ready_wire <= v;
   endmethod

   method Action bsync_lock(Bool v);
      bsync_lock_wire <= v;
   endmethod

   interface dtpRxIn = toPipeIn(dtpRxInFifo);
   interface dtpRxOut = toPipeOut(dtpRxOutFifo);
   interface dtpEventOut = toPipeOut(dtpEventOutFifo);
   interface dtpErrCnt = toPipeOut(dtpErrCntFifo);
endmodule
endpackage: DtpRx
