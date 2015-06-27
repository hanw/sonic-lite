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


package DtpTx;

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

typedef 8  CmdLen;
typedef 32 ParamLen;
typedef 4 GLOBAL_DELAY;
typedef 5 RXTX_DELAY;

typedef struct {
   Bit#(CmdLen)   cmd;
   Bit#(ParamLen) param;
} CmdTup deriving (Eq, Bits, FShow);

typedef struct {
   Bool     mux_sel;
   Bit#(53) c_local;
   Bit#(1)  parity;
} TxStageOneBuf deriving (Eq, Bits);

interface DtpTx;
   interface PipeIn#(Bit#(66))  dtpTxIn;
   interface PipeOut#(Bit#(66)) dtpTxOut;
   interface PipeOut#(Bit#(53)) dtpLocalOut;
   interface PipeIn#(Bit#(53))  dtpGlobalIn;
   interface DtpToPhyIfc api;

   interface PipeIn#(DtpEvent) dtpEventIn;
   interface PipeIn#(Bit#(32)) dtpErrCnt;

   (* always_ready, always_enabled *)
   method Action tx_ready(Bool v);
   (* always_ready, always_enabled *)
   method Action rx_ready(Bool v);
   (* always_ready, always_enabled *)
   method Action switch_mode(Bool v);
   (* always_ready, always_enabled *)
   method Action bsync_lock(Bool v);
endinterface

typedef 3'b100 LOG_TYPE;
typedef 2'b01 INIT_TYPE;
typedef 2'b10 ACK_TYPE;
typedef 2'b11 BEACON_TYPE;

typedef enum {INIT, SENT, SYNC} DtpState
deriving (Bits, Eq);

(* synthesize *)
module mkDtpTxTop(DtpTx);
   DtpTx _a <- mkDtpTx(0, 0);
   return _a;
endmodule

module mkDtpTx#(Integer id, Integer c_local_init)(DtpTx);

   let verbose = True;
   Wire#(Bool) tx_ready_wire <- mkDWire(False);
   Wire#(Bool) rx_ready_wire <- mkDWire(False);
   Wire#(Bool) switch_mode_wire <- mkDWire(False);
   Wire#(Bool) bsync_lock_wire <- mkDWire(False);

   FIFOF#(Bit#(66)) dtpTxInFifo <- mkFIFOF ();

   Reg#(Bool)   is_switch_mode <- mkReg(False); // by default, NIC mode
   Reg#(Bit#(32))  cycle   <- mkReg(0);
   Reg#(DtpState)  curr_state  <- mkReg(INIT);

   Reg#(Bit#(53))  c_local <- mkReg(fromInteger(c_local_init)); //mkReg(0); //fromInteger(c_local_init));
   Reg#(Bit#(53))  delay   <- mkReg(0);
   Reg#(Bit#(32))  timeout_count_init <- mkReg(0);
   Reg#(Bit#(32))  timeout_count_sync <- mkReg(0);
   Reg#(Bit#(64))  jumpCount <- mkReg(0);
   Reg#(Bit#(32))  interval_reg <- mkReg(1000);

   Wire#(Bool) init_rcvd    <- mkDWire(False);
   Wire#(Bool) ack_rcvd     <- mkDWire(False);
   Wire#(Bool) beacon_rcvd  <- mkDWire(False);

   Wire#(Bool) is_idle      <- mkDWire(False);

   Wire#(Bit#(53)) c_local_next <- mkDWire(0);
   FIFOF#(Bit#(2)) txMuxSelFifo <- mkSizedBypassFIFOF(3);

   // Tx Stage 1
   FIFOF#(Bit#(66)) dtpTxInPipelineFifo <- mkFIFOF;
   FIFOF#(Bit#(66)) dtpTxOutFifo <- mkFIFOF;
   FIFOF#(TxStageOneBuf) stageOneFifo <- mkFIFOF;

   FIFOF#(Bit#(53)) initTimestampFifo <- mkBypassFIFOF;
   FIFOF#(Bit#(1)) initParityFifo <- mkBypassFIFOF;
   FIFOF#(Bit#(53)) ackTimestampFifo <- mkBypassFIFOF;

   FIFOF#(Bit#(3))  dtpEventFifo   <- mkFIFOF;
   FIFOF#(Bit#(3))  dtpEventOutputFifo   <- mkFIFOF;
   FIFOF#(Bit#(66)) dtpRxOutFifo <- mkFIFOF;
   FIFOF#(DtpEvent) dtpEventInFifo <- mkFIFOF;
   FIFOF#(Bit#(32)) dtpErrCntFifo <- mkFIFOF;

   FIFOF#(Bit#(53)) dtpLocalOutFifo <- mkFIFOF;
   FIFOF#(Bit#(53)) dtpGlobalInFifo <- mkFIFOF;

   FIFOF#(Bit#(53)) localCompareRemoteFifo  <- mkFIFOF;
   FIFOF#(Bit#(53)) localCompareGlobalFifo  <- mkFIFOF;
   FIFOF#(Bit#(53)) remoteCompareGlobalFifo <- mkFIFOF;
   FIFOF#(Bit#(53)) remoteCompareLocalFifo  <- mkFIFOF;
   FIFOF#(Bit#(53)) globalCompareRemoteFifo <- mkFIFOF;
   FIFOF#(Bit#(53)) globalCompareLocalFifo  <- mkFIFOF;

   FIFOF#(Bit#(53)) localOutputFifo  <- mkFIFOF;
   FIFOF#(Bit#(53)) globalOutputFifo <- mkFIFOF;
   FIFOF#(Bit#(53)) remoteOutputFifo <- mkFIFOF;

   FIFOF#(Bool) localLtRemoteFifo  <- mkFIFOF;
   FIFOF#(Bool) localGeRemoteFifo  <- mkFIFOF;
   FIFOF#(Bool) globalLeRemoteFifo <- mkFIFOF;
   FIFOF#(Bool) globalGtRemoteFifo <- mkFIFOF;
   FIFOF#(Bool) globalLeLocalFifo  <- mkFIFOF;
   FIFOF#(Bool) globalGtLocalFifo  <- mkFIFOF;

   FIFOF#(void) cfFifo <- mkFIFOF;
   FIFOF#(void) dmFifo <- mkFIFOF;

   Reg#(Bool)       log_rcvd     <- mkReg(False);
   FIFOF#(Bit#(53)) fromHostFifo <- mkSizedBypassFIFOF(2);
   FIFOF#(Bit#(53)) toHostFifo   <- mkSizedBypassFIFOF(2);
   FIFOF#(Bit#(32)) delayFifo    <- mkSizedFIFOF(1);
   FIFOF#(Bit#(32)) stateFifo     <- mkSizedFIFOF(1);
   FIFOF#(Bit#(64)) jumpCountFifo <- mkSizedFIFOF(1);
   FIFOF#(Bit#(53)) cLocalFifo   <- mkSizedFIFOF(1);
   FIFOF#(Bit#(32)) intervalFifo <- mkSizedFIFOF(1);

   rule cyc;
      cycle <= cycle + 1;
   endrule

   rule set_switch_mode;
      is_switch_mode <= switch_mode_wire; // 0 for NIC, 1 for switch.
   endrule

   // Setup link first if neither Tx or Rx is ready, bypass DTP.
   rule tx_bypass(!tx_ready_wire || !rx_ready_wire || !bsync_lock_wire);
      let v <- toGet(dtpTxInFifo).get;
      dtpTxOutFifo.enq(v);
   endrule

   rule tx_stage1(tx_ready_wire && rx_ready_wire && bsync_lock_wire);
      let v <- toGet(dtpTxInFifo).get();
      Bit#(1) parity;
      Bool    mux_sel;
      Bit#(53) c_local_out;
      c_local_out = c_local+2; // forward compute parity.
      parity = ^c_local_out[52:0];

      if(v[9:2] == 8'h1e) begin
         mux_sel = True;
         is_idle <= True;
      end
      else begin
         mux_sel = False;
         is_idle <= False;
      end
      //if(verbose) $display("%d: %d dtpTxIn=%h, c_local=%h, is_idle=%h, curr_state=%d", cycle, id, v, c_local, mux_sel, curr_state);
      cfFifo.enq(?);
      dmFifo.enq(?);
      stageOneFifo.enq(TxStageOneBuf{mux_sel: mux_sel,
                                     parity: parity,
                                     c_local: c_local+1});
      dtpTxInPipelineFifo.enq(v);
   endrule

   Probe#(Bit#(53)) debug_from_host <- mkProbe();
   rule tx_stage2(tx_ready_wire && rx_ready_wire && bsync_lock_wire);
      let val <- toGet(stageOneFifo).get;
      let v <- toGet(dtpTxInPipelineFifo).get();
      let mux_sel = val.mux_sel;
      let c_local = val.c_local;
      let parity = val.parity;

      Bit#(10) block_type;
      Bit#(66) encodeOut;
      Bit#(3) log_type    = fromInteger(valueOf(LOG_TYPE));
      Bit#(2) init_type   = fromInteger(valueOf(INIT_TYPE));
      Bit#(2) ack_type    = fromInteger(valueOf(ACK_TYPE));
      Bit#(2) beacon_type = fromInteger(valueOf(BEACON_TYPE));

      block_type = v[9:0];

      if (mux_sel && fromHostFifo.notEmpty) begin
         let host_data = fromHostFifo.first;
         debug_from_host <= host_data;
         encodeOut = {host_data, log_type, block_type};
         fromHostFifo.deq;
      end
      else if (mux_sel && txMuxSelFifo.notEmpty) begin
         let sel = txMuxSelFifo.first;
         if (sel == init_type) begin
            encodeOut = {c_local+1, parity, init_type, block_type};
            if(verbose) $display("%d: %d, Enqueued outgoing init request %d", cycle, id, c_local+1);
         end
         else if (sel == ack_type) begin
            let init_timestamp <- toGet(initTimestampFifo).get;
            let init_parity <- toGet(initParityFifo).get;
            encodeOut = {init_timestamp, init_parity, ack_type, block_type};
            if(verbose) $display("%d: %d, Enqueued outgoing ack %d", cycle, id, init_timestamp);
         end
         else if (sel == beacon_type) begin
            encodeOut = {c_local+1, parity, beacon_type, block_type};
         end
         else begin
            encodeOut = v; //should never happen
         end
         txMuxSelFifo.deq;
      end
      else begin
         encodeOut = v;
      end
      //if(verbose) $display("%d: %d dtpTxOut=%h, c_local=%h, encodeOut=%h", cycle, id, encodeOut, c_local, encodeOut[12:10]);
      dtpTxOutFifo.enq(encodeOut);
   endrule

   // delay measurement
   rule delay_measurment(curr_state == INIT || curr_state == SENT);
      let init_timeout = interval_reg._read;
      let init_type = fromInteger(valueOf(INIT_TYPE));
      let ack_type = fromInteger(valueOf(ACK_TYPE));
      let rxtx_delay = fromInteger(valueOf(RXTX_DELAY));
      dmFifo.deq;
      // Timeout driven output
      if (init_rcvd) begin
         timeout_count_init <= timeout_count_init + 1;
         if (txMuxSelFifo.notFull) begin
            txMuxSelFifo.enq(ack_type);
         end
         if(verbose) $display("%d: %d, send ack, type %d", cycle, id, ack_type);
      end
      else if (timeout_count_init > init_timeout-1) begin
         if (is_idle) begin
            timeout_count_init <= 0;
            if (txMuxSelFifo.notFull) begin
               txMuxSelFifo.enq(init_type);
            end
            if(verbose) $display("%d: %d, init timed_out %d", cycle, id, timeout_count_init);
         end
         else begin
            timeout_count_init <= timeout_count_init + 1;
         end
      end
      else begin
         timeout_count_init <= timeout_count_init + 1;
      end

      // compute delay
      if (ack_rcvd) begin
         let temp <- toGet(ackTimestampFifo).get;
         delay <= (c_local - temp - (rxtx_delay << 1) - 1) >> 1;
         if(verbose) $display("%d: %d update delay=%d, %d, %d", cycle, id, c_local, temp, (c_local-temp-(rxtx_delay<<1)-1)>>1);
      end
   endrule

   // Beacon
   rule beacon(curr_state == SYNC);
      dmFifo.deq;
      let sync_timeout = interval_reg._read;
      let beacon_type = fromInteger(valueOf(BEACON_TYPE));
      let ack_type = fromInteger(valueOf(ACK_TYPE));
      let rxtx_delay = fromInteger(valueOf(RXTX_DELAY));
      if (timeout_count_sync >= sync_timeout-1) begin
         if (is_idle) begin
            timeout_count_sync <= 0;
         end
         else begin
            timeout_count_sync <= timeout_count_sync + 1;
         end
         if (txMuxSelFifo.notFull) begin
            txMuxSelFifo.enq(beacon_type);
         end
      end
      else if (init_rcvd) begin
         if (txMuxSelFifo.notFull) begin
            txMuxSelFifo.enq(ack_type);
         end
         timeout_count_sync <= timeout_count_sync + 1;
      end
      else begin
         timeout_count_sync <= timeout_count_sync + 1;
      end

      // compute delay
      if (ack_rcvd) begin
         let temp <- toGet(ackTimestampFifo).get;
         delay <= (c_local - temp - (rxtx_delay << 1) - 1) >> 1;
         if(verbose) $display("%d: %d update delay=%d, %d, %d", cycle, id, c_local, temp, (c_local-temp-(rxtx_delay<<1)-1)>>1);
      end
   endrule

   // DTP state machine
   rule state_init (curr_state == INIT);
      let init_type = fromInteger(valueOf(INIT_TYPE));
      cfFifo.deq;

      // update states
      if (txMuxSelFifo.notEmpty && is_idle) begin
         if (txMuxSelFifo.first == init_type) begin
            curr_state <= SENT;
         end
      end
      else if (init_rcvd) begin
         curr_state <= INIT;
      end
      else begin
         curr_state <= INIT;
      end
      //if(verbose) $display("%d: %d curr_state=%h", cycle, id, curr_state);
   endrule

   rule state_sent (curr_state == SENT);
      let init_type = fromInteger(valueOf(INIT_TYPE));
      cfFifo.deq;

      // update states
      if (init_rcvd) begin
         curr_state <= SENT;
      end
      else if (ack_rcvd) begin
         curr_state <= SYNC;
      end
      else if (txMuxSelFifo.notEmpty) begin
         if (txMuxSelFifo.first == init_type) begin
            curr_state <= INIT;
         end
      end
      else begin
         curr_state <= SENT;
      end
   endrule

   rule state_sync (curr_state == SYNC);
      cfFifo.deq;

      // update states
      if (init_rcvd) begin
         curr_state <= SYNC;
      end
      else begin
         curr_state <= SYNC;
      end
   endrule

   rule switch_in_c_local(is_switch_mode);
      //if(verbose) $display("%d: send c_local %h to L2", cycle, c_local);
      dtpLocalOutFifo.enq(c_local);
   endrule

   rule switch_out_c_global;
      let v <- toGet(dtpGlobalInFifo).get;
      if (is_switch_mode && beacon_rcvd) begin
         if (verbose) $display("%d: received global counter %d", cycle, v);
         globalCompareRemoteFifo.enq(v + 1);
         globalCompareLocalFifo.enq(v + 1);
      end
   endrule

   rule rx_stage1(tx_ready_wire && rx_ready_wire && bsync_lock_wire);
      let init_type   = fromInteger(valueOf(INIT_TYPE));
      let ack_type    = fromInteger(valueOf(ACK_TYPE));
      let beacon_type = fromInteger(valueOf(BEACON_TYPE));
      let log_type    = fromInteger(valueOf(LOG_TYPE));
      Bool init_rcvd_next   = False;
      Bool ack_rcvd_next    = False;
      Bool beacon_rcvd_next = False;
      Bool log_rcvd_next    = False;
      if (dtpEventInFifo.notEmpty) begin
         let v <- toGet(dtpEventInFifo).get;
         if ((v.e == init_type)) begin
            let parity = ^(v.t);
            if (initTimestampFifo.notFull && initParityFifo.notFull) begin
               initTimestampFifo.enq(v.t);
               initParityFifo.enq(parity);
            end
            if(verbose) $display("%d: %d DtpTx init_rcvd %h %d", cycle, id, v.e, v.t);
            init_rcvd_next = True;
         end
         else if (v.e == ack_type) begin
            ack_rcvd_next = True;
            // append received timestamp to fifo
            if (ackTimestampFifo.notFull)
               ackTimestampFifo.enq(v.t);
            if(verbose) $display("%d: %d DtpTx ack_rcvd %h %d", cycle, id, v.e, v.t);
         end
         else if (v.e == beacon_type) begin
            beacon_rcvd_next = True;
            if(verbose) $display("%d: %d DtpTx beacon_rcvd %h %d", cycle, id, v.e, v.t);
            localCompareRemoteFifo.enq(c_local+1);
            remoteCompareLocalFifo.enq(v.t+1);
            if (is_switch_mode) begin
               localCompareGlobalFifo.enq(c_local+1);
               remoteCompareGlobalFifo.enq(v.t+1);
            end
         end
         else if (v.e == log_type) begin
            log_rcvd_next = True;
            if(verbose) $display("%d: %d DtpTx log_rcvd %h %d", cycle, id, v.e, v.t);
            if (toHostFifo.notFull) begin
               toHostFifo.enq(v.t);
            end
         end
         dtpEventFifo.enq(v.e);
      end
      else begin
         dtpEventFifo.enq(3'b0);
      end
      init_rcvd   <= init_rcvd_next;
      ack_rcvd    <= ack_rcvd_next;
      beacon_rcvd <= beacon_rcvd_next;
      log_rcvd    <= log_rcvd_next;
   endrule

   rule rx_stage2;
      let v_local <- toGet(localCompareRemoteFifo).get();
      let v_remote <- toGet(remoteCompareLocalFifo).get();
      if(verbose) $display("%d: %d, v_local=%d, v_remote=%d, delay=%d", cycle, id, v_local, v_remote, delay);
      if (v_local + 1 < v_remote + delay) begin
         localLtRemoteFifo.enq(True);
         localGeRemoteFifo.enq(False);
      end
      else begin
         localLtRemoteFifo.enq(False);
         localGeRemoteFifo.enq(True);
      end
      localOutputFifo.enq(v_local + 1);
      remoteOutputFifo.enq(v_remote + 1);
   endrule

   rule compare_global_remote (is_switch_mode);
      let global_delay = fromInteger(valueOf(GLOBAL_DELAY));
      let v_global <- toGet(globalCompareRemoteFifo).get();
      let v_remote <- toGet(remoteCompareGlobalFifo).get();
      if (v_global + global_delay <= v_remote + delay) begin
         globalLeRemoteFifo.enq(True);
         globalGtRemoteFifo.enq(False);
      end
      else begin
         globalLeRemoteFifo.enq(False);
         globalGtRemoteFifo.enq(True);
      end
      if(verbose) $display("%d: %d, v_global=%d, v_remote=%d", cycle, id, v_global, v_remote);
      globalOutputFifo.enq(v_global + 1);
   endrule

   rule compare_global_local (is_switch_mode);
      let global_delay = fromInteger(valueOf(GLOBAL_DELAY));
      let v_global <- toGet(globalCompareLocalFifo).get();
      let v_local <- toGet(localCompareGlobalFifo).get();
      if (v_global + global_delay <= v_local + 1) begin
         globalLeLocalFifo.enq(True);
         globalGtLocalFifo.enq(False);
      end
      else begin
         globalLeLocalFifo.enq(False);
         globalGtLocalFifo.enq(True);
      end
      if(verbose) $display("%d: %d, v_global=%d, v_local=%d", cycle, id, v_global, v_local);
   endrule

   rule rx_stage2_bypass;
      let v_event <- toGet(dtpEventFifo).get();
      dtpEventOutputFifo.enq(v_event);
   endrule

   rule rx_stage3_nic_mode (!is_switch_mode);
      let vLocal <- toGet(localOutputFifo).get();
      let vRemote <- toGet(remoteOutputFifo).get();
      let useLocal <- toGet(localGeRemoteFifo).get();
      let incrJump <- toGet(localLtRemoteFifo).get();
      if(verbose) $display("%d: %d vLocal=%d", cycle, id, vLocal);
      if(verbose) $display("%d: %d vRemote=%d", cycle, id, vRemote);
      if(verbose) $display("%d: %d delay=%d", cycle, id, delay);
      if (useLocal) begin
         c_local_next <= vLocal + 1;
      end
      else begin
         c_local_next <= vRemote + delay + 1;
      end

      if (incrJump) begin
         jumpCount <= jumpCount + 1;
      end
   endrule

   rule rx_stage3_switch_mode (is_switch_mode);
      let v_local <- toGet(localOutputFifo).get();
      let v_remote <- toGet(remoteOutputFifo).get();
      let v_global <- toGet(globalOutputFifo).get();
      let isGR <- toGet(globalGtRemoteFifo).get();
      let isGL <- toGet(globalGtLocalFifo).get();
      let isLR <- toGet(localGeRemoteFifo).get();
      let isLG <- toGet(globalLeLocalFifo).get();
      let isRG <- toGet(globalLeRemoteFifo).get();
      let isRL <- toGet(localLtRemoteFifo).get();
      let global_delay = fromInteger(valueOf(GLOBAL_DELAY));
      let err = False;
      if(verbose) $display("%d: isGR=%d, isGL=%d, isLR=%d, isLG=%d, isRG=%d, isRL=%d", cycle, isGR, isGL, isLR, isLG, isRG, isRL);
      if (isGR && isGL) begin
         c_local_next <= v_global + global_delay;
         err = True;
      end
      else if (isLR && isLG) begin
         c_local_next <= v_local + 1;
      end
      else if (isRG && isRL) begin
         c_local_next <= v_remote + delay;
         err = True;
      end
      else begin
         c_local_next <= v_local + 1;
         err = True;
      end

      if (err) begin
         jumpCount <= jumpCount + 1;
      end

      if(verbose && id==1) $display("%d: jumpCount = %d", cycle, jumpCount);
   endrule

   rule rx_stage3;
      let v <- toGet(dtpEventOutputFifo).get();
      Bit#(2) beacon_type = fromInteger(valueOf(BEACON_TYPE));
      if (!rx_ready_wire) begin
         c_local <= 0;
      end
      else if (v == zeroExtend(beacon_type)) begin
         c_local <= c_local_next;
         if(verbose) $display("%d: %d c_local_next = %d", cycle, id, c_local_next);
      end
      else begin
         c_local <= c_local + 1;
      end
   endrule

   rule export_delay;
      delayFifo.enq(truncate(delay));
   endrule

   rule export_state;
      stateFifo.enq(zeroExtend(pack(curr_state)));
   endrule

   rule export_jumpCount;
      jumpCountFifo.enq(jumpCount);
   endrule

   rule export_c_local;
      cLocalFifo.enq(c_local);
   endrule

   rule import_interval(intervalFifo.notEmpty);
      let interval = intervalFifo.first;
      interval_reg <= interval;
      intervalFifo.deq;
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

   method Action bsync_lock(Bool v);
      bsync_lock_wire <= v;
   endmethod

   interface api = (interface DtpToPhyIfc;
      interface delayOut = toPipeOut(delayFifo);
      interface stateOut = toPipeOut(stateFifo);
      interface jumpCount = toPipeOut(jumpCountFifo);
      interface cLocalOut = toPipeOut(cLocalFifo);
      interface toHost   = toPipeOut(toHostFifo);
      interface fromHost = toPipeIn(fromHostFifo);
      interface interval = toPipeIn(intervalFifo);
      interface dtpErrCnt = toPipeOut(dtpErrCntFifo);
   endinterface);
   interface dtpEventIn = toPipeIn(dtpEventInFifo);
   interface dtpErrCnt = toPipeIn(dtpErrCntFifo);
   interface dtpTxIn = toPipeIn(dtpTxInFifo);
   interface dtpTxOut = toPipeOut(dtpTxOutFifo);
   interface dtpLocalOut = toPipeOut(dtpLocalOutFifo);
   interface dtpGlobalIn = toPipeIn(dtpGlobalInFifo);
endmodule
endpackage
