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

package Dtp;

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
//import MemTypes::*;

typedef 54 TIMESTAMP_LEN;
typedef 4  N_IFCs;

typedef 8  CmdLen;
typedef 32 ParamLen;

typedef 3 GLOBAL_DELAY;

typedef struct {
   Bit#(CmdLen)   cmd;
   Bit#(ParamLen) param;
} CmdTup deriving (Eq, Bits, FShow);

typedef struct {
   Bool     mux_sel;
   Bit#(53) c_local;
   Bit#(1)  parity;
} TxStageOneBuf deriving (Eq, Bits);

interface Dtp;
   interface PipeIn#(Bit#(66))  dtpRxIn;
   interface PipeIn#(Bit#(66))  dtpTxIn;
   interface PipeOut#(Bit#(66)) dtpRxOut;
   interface PipeOut#(Bit#(66)) dtpTxOut;
   (* always_ready, always_enabled *)
   method Action tx_ready(Bool v);
   (* always_ready, always_enabled *)
   method Action rx_ready(Bool v);
   interface DtpToPhyIfc api;
endinterface

typedef 3'b100 LOG_TYPE;
typedef 2'b01 INIT_TYPE;
typedef 2'b10 ACK_TYPE;
typedef 2'b11 BEACON_TYPE;

//FIXME: should be controlled by driver.
typedef 1000 INIT_TIMEOUT;
typedef 1000 SYNC_TIMEOUT;

typedef enum {INIT, SENT, SYNC} DtpState
deriving (Bits, Eq);

(* synthesize *)
module mkDtpTop(Dtp);
   Dtp _a <- mkDtp(0);
   return _a;
endmodule

module mkDtp#(Integer id)(Dtp);

   let verbose = False;
   Wire#(Bool) tx_ready_wire <- mkDWire(False);
   Wire#(Bool) rx_ready_wire <- mkDWire(False);

   FIFOF#(Bit#(66)) dtpRxInFifo <- mkFIFOF ();
   FIFOF#(Bit#(66)) dtpTxInFifo <- mkFIFOF ();

   Reg#(Bit#(1))   mode <- mkReg(0); // mode=0 NIC, mode=1 SWITCH
   Reg#(Bit#(32))  cycle   <- mkReg(0);
   Reg#(DtpState)  curr_state  <- mkReg(INIT);

   Reg#(Bit#(53))  c_local <- mkReg(0); //fromInteger(c_local_init));
   Reg#(Bit#(53))  delay   <- mkReg(0);
   Reg#(Bit#(32))  timeout_count_init <- mkReg(0);
   Reg#(Bit#(32))  timeout_count_sync <- mkReg(0);
   Reg#(Bit#(64))  jumpCount <- mkReg(0);
   Wire#(Bool) init_rcvd    <- mkDWire(False);
   Wire#(Bool) ack_rcvd     <- mkDWire(False);
   Wire#(Bool) beacon_rcvd  <- mkDWire(False);
   Reg#(Bool) is_idle      <- mkReg(False);

   Wire#(Bit#(53)) c_local_next <- mkDWire(0);
   Wire#(Bit#(2))  tx_mux_sel   <- mkDWire(0);

   // Tx Stage 1
   FIFOF#(Bit#(66)) dtpTxInPipelineFifo <- mkFIFOF;
   FIFOF#(Bit#(66)) dtpTxOutFifo <- mkFIFOF;
   FIFOF#(TxStageOneBuf) stageOneFifo <- mkFIFOF;

   FIFOF#(Bit#(53)) outstandingInitRequest <- mkSizedFIFOF(8);

   FIFOF#(Bit#(2))  dtpEventFifo   <- mkFIFOF;
   FIFOF#(Bit#(2))  dtpEventOutputFifo   <- mkFIFOF;
   FIFOF#(Bit#(66)) dtpRxOutFifo <- mkFIFOF;

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
   FIFOF#(Bit#(53)) fromHostFifo <- mkSizedFIFOF(1);
   FIFOF#(Bit#(53)) toHostFifo   <- mkSizedFIFOF(1);
   FIFOF#(Bit#(32)) delayFifo    <- mkSizedFIFOF(1);
   FIFOF#(Bit#(32)) stateFifo     <- mkSizedFIFOF(1);
   FIFOF#(Bit#(64)) jumpCountFifo <- mkSizedFIFOF(1);

   rule cyc;
      cycle <= cycle + 1;
   endrule

   // Setup link first if neither Tx or Rx is ready, bypass DTP.
   rule tx_bypass(!tx_ready_wire || !rx_ready_wire);
      let v <- toGet(dtpTxInFifo).get;
      dtpTxOutFifo.enq(v);
   endrule

   rule rx_bypass(!tx_ready_wire || !rx_ready_wire);
      let v <- toGet(dtpRxInFifo).get;
      dtpRxOutFifo.enq(v);
   endrule

   rule tx_stage1(tx_ready_wire && rx_ready_wire);
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

      if(verbose) $display("%d: %d dtpTxIn=%h, c_local=%h, is_idle=%h, curr_state=%d", cycle, id, v, c_local, mux_sel, curr_state);
      cfFifo.enq(?);
      dmFifo.enq(?);
      stageOneFifo.enq(TxStageOneBuf{mux_sel: mux_sel,
                                     parity: parity,
                                     c_local: c_local+1});
      dtpTxInPipelineFifo.enq(v);
   endrule

   Probe#(Bit#(53)) debug_from_host <- mkProbe();
   rule tx_stage2(tx_ready_wire && rx_ready_wire);
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

      if (mux_sel && tx_mux_sel == init_type) begin
         encodeOut = {c_local+1, parity, init_type, block_type};
         $display("Enqueued ougoing init request");
         outstandingInitRequest.enq(c_local+1);
      end
      else if (mux_sel && tx_mux_sel == ack_type) begin
         encodeOut = {c_local+1, parity, ack_type, block_type};
      end
      else if (mux_sel && tx_mux_sel == beacon_type) begin
         encodeOut = {c_local+1, parity, beacon_type, block_type};
      end
      else if (mux_sel && fromHostFifo.notEmpty) begin
         let host_data = fromHostFifo.first;
         debug_from_host <= host_data;
         encodeOut = {host_data, log_type, block_type};
         fromHostFifo.deq;
      end
      else begin
         encodeOut = v;
      end
      if(verbose) $display("%d: %d dtpTxOut=%h, c_local=%h, encodeOut=%h", cycle, id, v, c_local, encodeOut[11:10]);
      dtpTxOutFifo.enq(encodeOut);
   endrule

   // delay measurement
   rule delay_measurment(curr_state == INIT || curr_state == SENT);
      let init_timeout = fromInteger(valueOf(INIT_TIMEOUT));
      let init_type = fromInteger(valueOf(INIT_TYPE));
      let ack_type = fromInteger(valueOf(ACK_TYPE));
      dmFifo.deq;
      // Timeout driven output
      if (timeout_count_init > init_timeout) begin
         if (is_idle) begin
            timeout_count_init <= 0;
         end
         else begin
            timeout_count_init <= timeout_count_init + 1;
         end
         tx_mux_sel <= init_type;
         if(verbose) $display("%d: %d, init timed_out %d", cycle, id, timeout_count_init);
      end
      else if (init_rcvd) begin
         timeout_count_init <= timeout_count_init + 1;
         tx_mux_sel <= ack_type;
      end
      else begin
         timeout_count_init <= timeout_count_init + 1;
         tx_mux_sel <= 2'b00;
      end

      // compute delay
      if (ack_rcvd) begin
         let temp = outstandingInitRequest.first;
         delay <= (c_local - temp - 1) >> 1;
         if(verbose) $display("%d: %d update delay=%h, %h, %h", cycle, id, c_local, temp, (c_local-temp-1)>>1);
         outstandingInitRequest.deq;
      end
   endrule

   // Beacon
   rule beacon(curr_state == SYNC);
      dmFifo.deq;
      let sync_timeout = fromInteger(valueOf(SYNC_TIMEOUT));
      let beacon_type = fromInteger(valueOf(BEACON_TYPE));
      let ack_type = fromInteger(valueOf(ACK_TYPE));
      if (timeout_count_sync >= sync_timeout) begin
         if (is_idle) begin
            timeout_count_sync <= 0;
         end
         else begin
            timeout_count_sync <= timeout_count_sync + 1;
         end
         tx_mux_sel <= beacon_type;
      end
      else if (init_rcvd) begin
         tx_mux_sel <= ack_type;
         timeout_count_sync <= timeout_count_sync + 1;
      end
      else begin
         timeout_count_sync <= timeout_count_sync + 1;
         tx_mux_sel <= 2'b00;
      end

      if (ack_rcvd) begin
         let temp = outstandingInitRequest.first;
         delay <= (c_local - temp - 1) >> 1;
         if(verbose) $display("%d: %d update delay=%h, %h, %h", cycle, id, c_local, temp, (c_local-temp-1)>>1);
         outstandingInitRequest.deq;
      end
   endrule

   // DTP state machine
   rule state_init (curr_state == INIT);
      let init_type = fromInteger(valueOf(INIT_TYPE));
      cfFifo.deq;

      // update states
      if (tx_mux_sel == init_type && is_idle) begin
         curr_state <= SENT;
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
      else if (tx_mux_sel == init_type) begin
         curr_state <= INIT;
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

   Probe#(Bit#(53)) debug_to_host <- mkProbe();
   // Parse received DTP frame
   // Remove DTP timestamp before passing frame to MAC.
   rule rx_stage1(tx_ready_wire && rx_ready_wire);
      let init_type   = fromInteger(valueOf(INIT_TYPE));
      let ack_type    = fromInteger(valueOf(ACK_TYPE));
      let beacon_type = fromInteger(valueOf(BEACON_TYPE));
      let log_type    = fromInteger(valueOf(LOG_TYPE));
      let v <- toGet(dtpRxInFifo).get();
      Bit#(1)  parity = ^v[65:13];
      Bit#(53) c_remote = v[65:13];
      Bit#(66) vo = v;
      Bool init_rcvd_next   = False;
      Bool ack_rcvd_next    = False;
      Bool beacon_rcvd_next = False;
      Bool log_rcvd_next    = False;
      vo[65:10] = 56'h0;

      if (v[9:2] == 8'h1e) begin
         if (v[11:10] == init_type) begin
            if (parity == v[12]) begin
               init_rcvd_next = True;
               if(verbose) $display("%d: %d init_rcvd %h %h", cycle, id, c_remote, c_local);
            end
            else begin
               $display("parity mismatch: expected %h, found %h", parity, v[12]);
            end
         end
         else if (v[11:10] == ack_type) begin
            if (parity == v[12]) begin
               ack_rcvd_next = True;
               if(verbose) $display("%d: %d ack_rcvd %h %h", cycle, id, c_remote, c_local);
            end
            else begin
               $display("parity mismatch: expected %h, found %h", parity, v[12]);
            end
         end
         else if (v[11:10] == beacon_type) begin
            if (parity == v[12]) begin
               beacon_rcvd_next = True;
               localCompareRemoteFifo.enq(c_local + 1);
               remoteCompareLocalFifo.enq(c_remote + 1);
               if(verbose) $display("%d: %d beacon_rcvd %h %h", cycle, id, c_remote, c_local);
            end
            else begin
               $display("parity mismatch: expected %h, found %h", parity, v[12]);
            end
         end
         else if (v[12:10] == log_type) begin
            // send v[65:13] to logger.
            log_rcvd_next = True;
            debug_to_host <= v[65:13];
            //FIXME: enable toHost.
            if (toHostFifo.notFull) begin
               toHostFifo.enq(v[65:13]);
            end
         end
         dtpEventFifo.enq(v[11:10]);
      end
      else begin
         dtpEventFifo.enq(2'b0);
      end
      //if(verbose) $display("%d: %d dtpRxIn=%h", cycle, id, v);
      //if(verbose) $display("%d: %d curr_state=%h", cycle, id, curr_state);
      init_rcvd   <= init_rcvd_next;
      ack_rcvd    <= ack_rcvd_next;
      beacon_rcvd <= beacon_rcvd_next;
      log_rcvd    <= log_rcvd_next;
      dtpRxOutFifo.enq(vo);
   endrule

   rule rx_stage2 (mode==0 || mode==1);
      let v_local <- toGet(localCompareRemoteFifo).get();
      let v_remote <- toGet(remoteCompareLocalFifo).get();
      if(verbose) $display("%d: %d, v_local=%h, v_remote=%h, delay=%h", cycle, id, v_local, v_remote, delay);
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

   rule compare_global_remote (mode==1);
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
      globalOutputFifo.enq(v_global);
   endrule

   rule compare_global_local (mode==1);
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
   endrule

   rule rx_stage2_bypass;
      let v_event <- toGet(dtpEventFifo).get();
      dtpEventOutputFifo.enq(v_event);
   endrule

   rule rx_stage3_compute_c_local_next(mode==0);
      let vLocal <- toGet(localOutputFifo).get();
      let vRemote <- toGet(remoteOutputFifo).get();
      let useLocal <- toGet(localGeRemoteFifo).get();
      let incrJump <- toGet(localLtRemoteFifo).get();
      if(verbose) $display("%d: %d, vLocal=%h", cycle, id, vLocal);
      if(verbose) $display("%d: %d, vRemote=%h", cycle, id, vRemote);
      if(verbose) $display("%d: %d, delay=%h", cycle, id, delay);
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

   rule output_switch (mode==1);
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
      if (isGR && isGL) begin
         c_local_next <= v_global + global_delay;
      end
      else if (isLR && isLG) begin
         c_local_next <= v_local + 3;
      end
      else if (isRG && isRL) begin
         c_local_next <= v_remote + delay;
      end
   endrule

   rule rx_stage3;
      let v <- toGet(dtpEventOutputFifo).get();
      Bit#(2) beacon_type = fromInteger(valueOf(BEACON_TYPE));
      if (v == beacon_type) begin
         c_local <= c_local_next;
         if(verbose) $display("%d: %d c_local_next = %h", cycle, id, c_local_next);
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

   method Action tx_ready(Bool v);
      tx_ready_wire <= v;
   endmethod

   method Action rx_ready(Bool v);
      rx_ready_wire <= v;
   endmethod

   interface api = (interface DtpToPhyIfc;
      interface delayOut = toPipeOut(delayFifo);
      interface stateOut = toPipeOut(stateFifo);
      interface jumpCount = toPipeOut(jumpCountFifo);
      interface toHost   = toPipeOut(toHostFifo);
      interface fromHost = toPipeIn(fromHostFifo);
   endinterface);
   interface dtpRxIn = toPipeIn(dtpRxInFifo);
   interface dtpTxIn = toPipeIn(dtpTxInFifo);
   interface dtpRxOut = toPipeOut(dtpRxOutFifo);
   interface dtpTxOut = toPipeOut(dtpTxOutFifo);
endmodule
endpackage
