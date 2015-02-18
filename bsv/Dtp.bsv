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

import Pipe::*;
import MemTypes::*;

typedef 54 TIMESTAMP_LEN;
typedef 4  N_IFCs;

typedef 8  CmdLen;
typedef 32 ParamLen;

typedef 3 GLOBAL_DELAY;

typedef struct {
   Bit#(CmdLen)   cmd;
   Bit#(ParamLen) param;
} CmdTup deriving (Eq, Bits, FShow);

interface DtpIn;
   interface PipeOut#(Bit#(66))  decoderIn;
   interface PipeOut#(Bit#(66))  encoderIn;
   //interface PipeOut#(CmdTup)    cmdIn;
endinterface

interface DtpIfc;
   interface PipeOut#(Bit#(66)) decoderOut;
   interface PipeOut#(Bit#(66)) encoderOut;
//   method Vector#(N_IFCs, Bit#(TIMESTAMP_LEN)) local_clock;
//   method Bit#(TIMESTAMP_LEN) global_clock;
endinterface

typedef 2'b01 INIT_TYPE;
typedef 2'b10 ACK_TYPE;
typedef 2'b11 BEACON_TYPE;

typedef 10 INIT_TIMEOUT;
typedef 10 SYNC_TIMEOUT;

typedef enum {INIT, SENT, SYNC} State
deriving (Bits, Eq);

module mkDtp#(PipeOut#(Bit#(66)) decoderIn, PipeOut#(Bit#(66)) encoderIn, Integer id, Integer c_local_init)(DtpIfc);

   let verbose = True;

   Reg#(Bit#(1))   mode <- mkReg(0); // mode=0 NIC, mode=1 SWITCH
   Reg#(Bit#(32))  cycle   <- mkReg(0);
   Reg#(State) curr_state  <- mkReg(INIT);

   Reg#(Bit#(53))  c_local <- mkReg(fromInteger(c_local_init));
//   Reg#(Bit#(53))  temp    <- mkReg(0);
   Reg#(Bit#(53))  delay   <- mkReg(0);
   Reg#(Bit#(32))  timeout_count_init <- mkReg(0);
   Reg#(Bit#(32))  timeout_count_sync <- mkReg(0);
   Wire#(Bool) init_rcvd    <- mkDWire(False);
   Wire#(Bool) ack_rcvd     <- mkDWire(False);
   Wire#(Bool) beacon_rcvd  <- mkDWire(False);
   Reg#(Bool) is_idle      <- mkReg(False);

   Wire#(Bit#(53)) c_local_next <- mkDWire(0);
   Wire#(Bit#(2))  tx_mux_sel   <- mkDWire(0);

   // Tx Stage 1
   FIFOF#(Bit#(66)) encoderInFifo <- mkFIFOF;
   FIFOF#(Bit#(1))  parityFifo    <- mkFIFOF;
   FIFOF#(Bit#(53)) cLocalFifo    <- mkFIFOF;
   FIFOF#(Bit#(66)) encoderOutFifo <- mkFIFOF;
   FIFOF#(Bool)     isIdleFifo    <- mkFIFOF;

   FIFOF#(Bit#(53)) outstandingInitRequest <- mkSizedFIFOF(8);

   FIFOF#(Bit#(2))  dtpEventFifo   <- mkFIFOF;
   FIFOF#(Bit#(2))  dtpEventOutputFifo   <- mkFIFOF;
   FIFOF#(Bit#(66)) decoderOutFifo <- mkFIFOF;

   FIFOF#(Bit#(53)) localCompareRemoteFifo  <- mkFIFOF;
   FIFOF#(Bit#(53)) localCompareGlobalFifo  <- mkFIFOF;
   FIFOF#(Bit#(53)) remoteCompareGlobalFifo <- mkFIFOF;
   FIFOF#(Bit#(53)) remoteCompareLocalFifo  <- mkFIFOF;
   FIFOF#(Bit#(53)) globalCompareRemoteFifo <- mkFIFOF;
   FIFOF#(Bit#(53)) globalCompareLocalFifo  <- mkFIFOF;

   FIFOF#(Bit#(53)) localOutputFifo  <- mkFIFOF;
   FIFOF#(Bit#(53)) globalOutputFifo <- mkFIFOF;
   FIFOF#(Bit#(53)) remoteOutputFifo <- mkFIFOF;

   FIFOF#(Bool) localLeRemoteFifo  <- mkFIFOF;
   FIFOF#(Bool) localGtRemoteFifo  <- mkFIFOF;
   FIFOF#(Bool) globalLeRemoteFifo <- mkFIFOF;
   FIFOF#(Bool) globalGtRemoteFifo <- mkFIFOF;
   FIFOF#(Bool) globalLeLocalFifo  <- mkFIFOF;
   FIFOF#(Bool) globalGtLocalFifo  <- mkFIFOF;

   FIFOF#(void) cfFifo <- mkFIFOF;
   FIFOF#(void) dmFifo <- mkFIFOF;

   rule cyc;
      cycle <= cycle + 1;
   endrule

   rule tx_stage1;
      let v <- toGet(encoderIn).get();
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

      if(verbose) $display("%d: %d encoderIn=%h, c_local=%h is_idle=%h", cycle, id, v, c_local, mux_sel);
      cfFifo.enq(?);
      dmFifo.enq(?);
      isIdleFifo.enq(mux_sel);
      parityFifo.enq(parity);
      cLocalFifo.enq(c_local+1);
      encoderInFifo.enq(v);
   endrule

   rule tx_stage2;
      let mux_sel <- toGet(isIdleFifo).get();
      let c_local <- toGet(cLocalFifo).get();
      let parity  <- toGet(parityFifo).get();
      let v <- toGet(encoderInFifo).get();

      Bit#(10) block_type;
      Bit#(66) encodeOut;
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
      else begin
         encodeOut = v;
      end
      if(verbose) $display("%d: %d encoderOut=%h %h %h", cycle, id, c_local, parity, encodeOut[11:10]);
      encoderOutFifo.enq(encodeOut);
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
         //timed_out = True;
         tx_mux_sel <= init_type;
         if(verbose) $display("%d: %d, init timed_out %d", cycle, id, timeout_count_init);
      end
      else if (init_rcvd) begin
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
         tx_mux_sel <= beacon_type;
      end
      else if (init_rcvd) begin
         tx_mux_sel <= ack_type;
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
      Bool timed_out = False;

//      let init_timeout = fromInteger(valueOf(INIT_TIMEOUT));
      let init_type = fromInteger(valueOf(INIT_TYPE));
//      let ack_type = fromInteger(valueOf(ACK_TYPE));
      cfFifo.deq;

//      // Timeout driven output
//      if (timeout_count_init > init_timeout) begin
//         if (is_idle) begin
//            timeout_count_init <= 0;
//         end
//         timed_out = True;
//         tx_mux_sel <= init_type;
//         if(verbose) $display("%d: %d, init timed_out %d", cycle, id, timeout_count_init);
//      end
//      else if (init_rcvd) begin
//         tx_mux_sel <= ack_type;
//      end
//      else begin
//         timeout_count_init <= timeout_count_init + 1;
//         tx_mux_sel <= 2'b00;
//      end
//
//      // compute delay
//      if (ack_rcvd) begin
//         let temp = outstandingInitRequest.first;
//         delay <= (c_local - temp - 1) >> 1;
//         if(verbose) $display("%d: %d update delay=%h, %h, %h", cycle, id, c_local, temp, (c_local-temp-1)>>1);
//         outstandingInitRequest.deq;
//      end

      // update states
//      if (timed_out && is_idle) begin
      if (tx_mux_sel == init_type && is_idle) begin
         curr_state <= SENT;
      end
      else if (init_rcvd) begin
         curr_state <= INIT;
      end
      else begin
         curr_state <= INIT;
      end
      if(verbose) $display("%d: %d curr_state=%h", cycle, id, curr_state);
   endrule

   rule state_sent (curr_state == SENT);
//      Bool timed_out = False;
//      let init_timeout = fromInteger(valueOf(INIT_TIMEOUT));
      let init_type = fromInteger(valueOf(INIT_TYPE));
//      let ack_type = fromInteger(valueOf(ACK_TYPE));
      cfFifo.deq;

//      // Timeout driven output
//      if (timeout_count_init > init_timeout) begin
//         if (is_idle) begin
//            timeout_count_init <= 0;
//         end
//         timed_out = True;
//         tx_mux_sel <= init_type;
//      end
//      else if (init_rcvd) begin
//         tx_mux_sel <= ack_type;
//      end
//      else begin
//         timeout_count_init <= timeout_count_init + 1;
//         tx_mux_sel <= 2'b00;
//      end
//
//      // compute delay
//      if (ack_rcvd) begin
//         let temp = outstandingInitRequest.first;
//         delay <= (c_local - temp - 1) >> 1;
//         if(verbose) $display("%d: %d update delay=%h, %h, %h", cycle, id, c_local, temp, (c_local-temp-1)>>1);
//         outstandingInitRequest.deq;
//      end
//
      // update states
      if (init_rcvd) begin
         curr_state <= SENT;
      end
      else if (ack_rcvd) begin
         curr_state <= SYNC;
      end
//      else if (timed_out) begin
      else if (tx_mux_sel == init_type) begin
         curr_state <= INIT;
      end
      else begin
         curr_state <= SENT;
      end
   endrule

   rule state_sync (curr_state == SYNC);
      cfFifo.deq;
//      dmFifo.deq;
//      let sync_timeout = fromInteger(valueOf(SYNC_TIMEOUT));
//      let beacon_type = fromInteger(valueOf(BEACON_TYPE));
//      let ack_type = fromInteger(valueOf(ACK_TYPE));
//      if (timeout_count_sync >= sync_timeout) begin
//         if (is_idle) begin
//            timeout_count_sync <= 0;
//         end
//         tx_mux_sel <= beacon_type;
//      end
//      else if (init_rcvd) begin
//         tx_mux_sel <= ack_type;
//      end
//      else begin
//         timeout_count_sync <= timeout_count_sync + 1;
//         tx_mux_sel <= 2'b00;
//      end
//
//      if (ack_rcvd) begin
//         let temp = outstandingInitRequest.first;
//         delay <= (c_local - temp - 1) >> 1;
//         if(verbose) $display("%d: %d update delay=%h, %h, %h", cycle, id, c_local, temp, (c_local-temp-1)>>1);
//         outstandingInitRequest.deq;
//      end
      // update states
      if (init_rcvd) begin
         curr_state <= SYNC;
      end
      else begin
         curr_state <= SYNC;
      end
   endrule

   rule rx_stage1;
      let init_type   = fromInteger(valueOf(INIT_TYPE));
      let ack_type    = fromInteger(valueOf(ACK_TYPE));
      let beacon_type = fromInteger(valueOf(BEACON_TYPE));
      let v <- toGet(decoderIn).get();
      Bit#(1)  parity = ^v[65:13];
      Bit#(53) c_remote = v[65:13];

      if (v[9:2] == 8'h1e) begin
         if (v[11:10] == init_type) begin
            if (parity == v[12]) begin
               init_rcvd <= True;
               ack_rcvd <= False;
               beacon_rcvd <= False;
               if(verbose) $display("%d: %d init_rcvd %h %h", cycle, id, c_remote, c_local);
            end
            else begin
               $display("parity mismatch: expected %h, found %h", parity, v[12]);
            end
         end
         else if (v[11:10] == ack_type) begin
            if (parity == v[12]) begin
               init_rcvd <= False;
               ack_rcvd <= True;
               beacon_rcvd <= False;
               if(verbose) $display("%d: %d ack_rcvd %h %h", cycle, id, c_remote, c_local);
            end
            else begin
               $display("parity mismatch: expected %h, found %h", parity, v[12]);
            end
         end
         else if (v[11:10] == beacon_type) begin
            if (parity == v[12]) begin
               init_rcvd <= False;
               ack_rcvd <= False;
               beacon_rcvd <= True;
               localCompareRemoteFifo.enq(c_local + 1);
               remoteCompareLocalFifo.enq(c_remote + 1);
               if(verbose) $display("%d: %d beacon_rcvd %h %h", cycle, id, c_remote, c_local);
            end
            else begin
               $display("parity mismatch: expected %h, found %h", parity, v[12]);
            end
         end
         else begin
            init_rcvd <= False;
            ack_rcvd <= False;
            beacon_rcvd <= False;
         end
         dtpEventFifo.enq(v[11:10]);
      end
      else begin
         init_rcvd <= False;
         ack_rcvd <= False;
         beacon_rcvd <= False;
         dtpEventFifo.enq(2'b0);
      end
      if(verbose) $display("%d: %d decoderIn=%h", cycle, id, v);
      if(verbose) $display("%d: %d curr_state=%h", cycle, id, curr_state);
      decoderOutFifo.enq(v);
   endrule

   rule rx_stage2 (mode==0 || mode==1);
      let v_local <- toGet(localCompareRemoteFifo).get();
      let v_remote <- toGet(remoteCompareLocalFifo).get();
      if(verbose) $display("%d: %d, v_local=%h, v_remote=%h, delay=%h", cycle, id, v_local, v_remote, delay);
      if (v_local + 1 <= v_remote + delay) begin
         localLeRemoteFifo.enq(True);
         localGtRemoteFifo.enq(False);
      end
      else begin
         localLeRemoteFifo.enq(False);
         localGtRemoteFifo.enq(True);
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
      let useLocal <- toGet(localGtRemoteFifo).get();
      let _unused_ <- toGet(localLeRemoteFifo).get();
      if(verbose) $display("%d: %d, vLocal=%h", cycle, id, vLocal);
      if(verbose) $display("%d: %d, vRemote=%h", cycle, id, vRemote);
      if(verbose) $display("%d: %d, delay=%h", cycle, id, delay);
      if (useLocal) begin
         c_local_next <= vLocal + 1;
      end
      else begin
         c_local_next <= vRemote + delay + 1;
      end
   endrule

   rule output_switch (mode==1);
      let v_local <- toGet(localOutputFifo).get();
      let v_remote <- toGet(remoteOutputFifo).get();
      let v_global <- toGet(globalOutputFifo).get();
      let isGR <- toGet(globalGtRemoteFifo).get();
      let isGL <- toGet(globalGtLocalFifo).get();
      let isLR <- toGet(localGtRemoteFifo).get();
      let isLG <- toGet(globalLeLocalFifo).get();
      let isRG <- toGet(globalLeRemoteFifo).get();
      let isRL <- toGet(localLeRemoteFifo).get();
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

   interface decoderOut = toPipeOut(decoderOutFifo);
   interface encoderOut = toPipeOut(encoderOutFifo);
endmodule
endpackage
