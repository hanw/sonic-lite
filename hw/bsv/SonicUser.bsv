
// Copyright (c) 2015 Cornell University.

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

import Clocks::*;
import FIFO::*;
import FIFOF::*;
import Vector::*;
import Pipe::*;
import GetPut::*;
import Probe::*;

typedef struct {
   Bit#(8) port_no;
   Bit#(64) data;
} BufData deriving (Bits, Eq);

interface DtpIfc;
   interface PipeIn#(Bit#(128)) timestamp; // streaming time counter from NetTop.
   interface Vector#(4, PipeOut#(Bit#(53))) fromHost;
   interface Vector#(4, PipeIn#(Bit#(53)))  toHost;
   interface Vector#(4, PipeIn#(Bit#(32)))  delay;
   interface Vector#(4, PipeIn#(Bit#(32)))  state;
   interface Reset rst;
endinterface

interface SonicUserRequest;
   method Action dtp_reset(Bit#(8) port_no);
   method Action dtp_set_cnt(Bit#(8) port_no, Bit#(64) c);
   method Action dtp_read_delay(Bit#(8) port_no);
   method Action dtp_read_state(Bit#(8) port_no);
   method Action dtp_read_error(Bit#(8) port_no);
   method Action dtp_read_cnt(Bit#(8) cmd);
   method Action dtp_logger_write_cnt(Bit#(8) port_no, Bit#(64) local_cnt);
   method Action dtp_logger_read_cnt(Bit#(8) port_no);
endinterface

interface SonicUserIndication;
   method Action dtp_read_delay_resp(Bit#(8) port_no, Bit#(32) delay);
   method Action dtp_read_state_resp(Bit#(8) port_no, Bit#(32) state);
   method Action dtp_read_error_resp(Bit#(8) port_no, Bit#(64) jumpc);
   method Action dtp_read_cnt_resp(Bit#(64) val);
   method Action dtp_logger_read_cnt_resp(Bit#(8) port_no, Bit#(64) localc, Bit#(64) msg1, Bit#(64) msg2);
endinterface

interface SonicUser;
   interface SonicUserRequest request;
   interface DtpIfc           dtp;
endinterface

module mkSonicUser#(SonicUserIndication indication)(SonicUser);
   let verbose = False;
   Clock defaultClock <- exposeCurrentClock();

   Reg#(Bit#(64))  cycle_count <- mkReg(0);
   Reg#(Bit#(64))  last_count  <- mkReg(0);

   FIFOF#(Bit#(128)) cntFifo <- mkFIFOF();
   Reg#(Bit#(128))   ts_reg <- mkReg(0);

   Vector#(4, FIFOF#(Bit#(53))) fromHostFifo <- replicateM(mkSizedFIFOF(4));
   Vector#(4, FIFOF#(Bit#(53))) toHostFifo   <- replicateM(mkSizedFIFOF(4));
   Vector#(4, FIFOF#(Bit#(32))) delayFifo    <- replicateM(mkSizedFIFOF(4));
   Vector#(4, FIFOF#(Bit#(32))) stateFifo    <- replicateM(mkSizedFIFOF(4));
   FIFOF#(BufData) toHostBuffered <- mkSizedFIFOF(16);

   Reg#(Bit#(8))  lwrite_port <- mkReg(0);
   Reg#(Bit#(53)) lwrite_timestamp <- mkReg(0);
   FIFOF#(BufData) lwrite_cf <- mkSizedFIFOF(8);

   Reg#(Bit#(8))  lread_port <- mkReg(0);
   FIFOF#(void)   lread_cf <- mkSizedFIFOF(8);

   Reg#(Bit#(5)) dtp_rst_cntr <- mkReg(0);
   MakeResetIfc dtpResetOut <- mkResetSync(0, False, defaultClock);

   rule count;
      cycle_count <= cycle_count + 1;
   endrule

   // dtp_read_cnt
   rule snapshot_dtp_timestamp;
      let v <- toGet(cntFifo).get;
      ts_reg <= v;
   endrule

   // dtp_read_delay
   Vector#(4, Reg#(Bit#(32))) delay_reg <- replicateM(mkReg(0));
   for (Integer i=0; i<4; i=i+1) begin
      rule snapshot_delay;
         let v <- toGet(delayFifo[i]).get;
         delay_reg[i] <= v;
      endrule
   end

   // dtp_read_state
   Vector#(4, Reg#(Bit#(32))) state_reg <- replicateM(mkReg(0));
   for (Integer i=0; i<4; i=i+1) begin
      rule snapshot_state;
         let v <- toGet(stateFifo[i]).get;
         state_reg[i] <= v;
      endrule
   end

   // dtp_read_error


   // dtp_logger_write_cnt
   rule log_from_host;
      let v = lwrite_cf.first;
      lwrite_timestamp <= truncate(v.data);
      if (fromHostFifo[v.port_no].notFull) begin
         fromHostFifo[v.port_no].enq(truncate(v.data));
      end
      lwrite_cf.deq;
   endrule

   // dtp_logger_read_cnt
   Reg#(Bit#(TLog#(4))) arb <- mkReg(0);
   rule arbit;
      arb <= arb + 1;
   endrule
   rule save_port0_to_host_data (arb == 0 && toHostFifo[0].notEmpty);
      let v = toHostFifo[0].first;
      toHostBuffered.enq(BufData{port_no:0, data:zeroExtend(v)});
      toHostFifo[0].deq;
   endrule

   rule save_port1_to_host_data (arb == 1 && toHostFifo[1].notEmpty);
      let v = toHostFifo[1].first;
      toHostBuffered.enq(BufData{port_no:1, data:zeroExtend(v)});
      toHostFifo[1].deq;
   endrule

   rule save_port2_to_host_data (arb == 2 && toHostFifo[2].notEmpty);
      let v = toHostFifo[2].first;
      toHostBuffered.enq(BufData{port_no:2, data:zeroExtend(v)});
      toHostFifo[2].deq;
   endrule

   rule save_port3_to_host_data (arb == 3 && toHostFifo[3].notEmpty);
      let v = toHostFifo[3].first;
      toHostBuffered.enq(BufData{port_no:3, data:zeroExtend(v)});
      toHostFifo[3].deq;
   endrule

   // TODO: support dtp_logger_read_cnt_resp
   rule log_to_host(toHostBuffered.notEmpty);
      let v = toHostBuffered.first;
      toHostBuffered.deq;
   endrule

   rule assert_reset (dtp_rst_cntr != 0);
      dtp_rst_cntr <= dtp_rst_cntr - 1;
      dtpResetOut.assertReset;
   endrule

   // Interface to external modules.
   interface dtp = (interface DtpIfc;
      interface timestamp = toPipeIn(cntFifo);
      interface delay     = map(toPipeIn, delayFifo);
      interface state     = map(toPipeIn, stateFifo);
      interface toHost    = map(toPipeIn, toHostFifo);
      interface fromHost  = map(toPipeOut, fromHostFifo);
      interface rst       = dtpResetOut.new_rst;
   endinterface);

   // API implementation
   interface SonicUserRequest request;
   method Action dtp_reset(Bit#(8) port_no);
      dtp_rst_cntr <= 5'h1f;
   endmethod
   method Action dtp_set_cnt(Bit#(8) port_no, Bit#(64) c);
      //
   endmethod
   method Action dtp_read_delay(Bit#(8) port_no);
      if (port_no < 4) begin
         indication.dtp_read_delay_resp(port_no, truncate(delay_reg[port_no]));
      end
   endmethod
   method Action dtp_read_state(Bit#(8) port_no);
      if (port_no < 4) begin
         indication.dtp_read_state_resp(port_no, state_reg[port_no]);
      end
   endmethod
   method Action dtp_read_error(Bit#(8) port_no);
      //
   endmethod
   method Action dtp_read_cnt(Bit#(8) port_no);
      indication.dtp_read_cnt_resp(truncate(ts_reg));
   endmethod
   method Action dtp_logger_write_cnt(Bit#(8) port_no, Bit#(64) host_timestamp);
      // Check valid port No.
      if (port_no < 4) begin
         lwrite_cf.enq(BufData{port_no: port_no, data: host_timestamp});
      end
   endmethod
   method Action dtp_logger_read_cnt(Bit#(8) port_no);
      if (port_no < 4) begin
         lread_port <= port_no;
      end
      indication.dtp_logger_read_cnt_resp(port_no,
                                          zeroExtend(lwrite_timestamp),
                                          truncate(ts_reg),
                                          zeroExtend(lwrite_timestamp));
   endmethod
   endinterface
endmodule

