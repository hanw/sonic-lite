
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
import SpecialFIFOs::*;
import Vector::*;
import Pipe::*;
import GetPut::*;

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
   interface Vector#(4, PipeIn#(Bit#(64)))  jumpCount;
   interface Vector#(4, PipeIn#(Bit#(53)))  cLocal;
   interface PipeIn#(Bit#(53)) globalOut;
   interface Vector#(4, PipeOut#(Bit#(32))) interval;
   interface Vector#(4, PipeIn#(Bit#(32))) dtpErrCnt;
   interface Reset rst;
   interface PipeOut#(Bit#(1)) switchMode;
endinterface

interface DtpUserRequest;
   method Action dtp_read_version();
   method Action dtp_reset(Bit#(32) len);
   method Action dtp_set_cnt(Bit#(8) port_no, Bit#(64) c);
   method Action dtp_read_delay(Bit#(8) port_no);
   method Action dtp_read_state(Bit#(8) port_no);
   method Action dtp_read_error(Bit#(8) port_no);
   method Action dtp_read_cnt(Bit#(8) cmd);
   method Action dtp_logger_write_cnt(Bit#(8) port_no, Bit#(64) local_cnt);
   method Action dtp_logger_read_cnt(Bit#(8) port_no);
   method Action dtp_read_local_cnt(Bit#(8) port_no);
   method Action dtp_read_global_cnt();
   method Action dtp_set_beacon_interval(Bit#(8) port_no, Bit#(32) interval);
   method Action dtp_read_beacon_interval(Bit#(8) port_no);
   method Action dtp_debug_rcvd_msg(Bit#(8) port_no);
   method Action dtp_debug_sent_msg(Bit#(8) port_no);
   method Action dtp_debug_rcvd_err(Bit#(8) port_no);
   method Action dtp_set_mode(Bit#(8) mode);
   method Action dtp_get_mode();
/* NOT IMPLEMENTED YET.
   method Action dtp_ctrl_disable();
   method Action dtp_ctrl_enable();
*/
endinterface

interface DtpUserIndication;
   method Action dtp_read_version_resp(Bit#(32) version);
   method Action dtp_read_delay_resp(Bit#(8) port_no, Bit#(32) delay);
   method Action dtp_read_state_resp(Bit#(8) port_no, Bit#(32) state);
   method Action dtp_read_error_resp(Bit#(8) port_no, Bit#(64) jumpc);
   method Action dtp_read_cnt_resp(Bit#(64) val);
   method Action dtp_logger_read_cnt_resp(Bit#(8) port_no, Bit#(64) localc, Bit#(64) msg1, Bit#(64) msg2);
   method Action dtp_read_local_cnt_resp(Bit#(8) port_no, Bit#(64) val);
   method Action dtp_read_global_cnt_resp(Bit#(64) val);
   method Action dtp_read_beacon_interval_resp(Bit#(8) port_no, Bit#(32) interval);
   method Action dtp_debug_rcvd_msg_resp(Bit#(8) port_no, Bit#(32) lread_cnt_enq1, Bit#(32) lread_cnt_enq2, Bit#(32) lread_cnt_deq);
   method Action dtp_debug_sent_msg_resp(Bit#(8) port_no, Bit#(32) lwrite_cnt_enq, Bit#(32) lwrite_cnt_deq1, Bit#(32) lwrite_cnt_deq2);
   method Action dtp_debug_rcvd_err_resp(Bit#(8) port_no, Bit#(32) err_cnt);
   method Action dtp_get_mode_resp(Bit#(8) mode);
endinterface

interface DtpUser;
   interface DtpUserRequest request;
   interface DtpIfc           dtp;
endinterface

module mkDtpUser#(DtpUserIndication indication)(DtpUser);
   let verbose = False;
   Clock defaultClock <- exposeCurrentClock();

   Reg#(Bit#(64))  cycle_count <- mkReg(0);
   Reg#(Bit#(64))  last_count  <- mkReg(0);

   FIFOF#(Bit#(128)) cntFifo <- mkFIFOF();
   Reg#(Bit#(128))   cycle_reg <- mkReg(0);
   Reg#(Bit#(1))     switch_mode_reg <- mkReg(0);
   Vector#(4, Reg#(Bit#(32))) beacon_interval <- replicateM(mkReg(1000)); //default beacon interval is 1000.

   Vector#(4, FIFOF#(Bit#(53))) fromHostFifo <- replicateM(mkSizedFIFOF(4));
   Vector#(4, FIFOF#(Bit#(53))) toHostFifo   <- replicateM(mkSizedFIFOF(4));
   Vector#(4, FIFOF#(Bit#(32))) delayFifo    <- replicateM(mkSizedFIFOF(4));
   Vector#(4, FIFOF#(Bit#(32))) stateFifo    <- replicateM(mkSizedFIFOF(4));
   Vector#(4, FIFOF#(Bit#(64))) jumpCountFifo <- replicateM(mkSizedFIFOF(4));
   Vector#(4, FIFOF#(Bit#(53))) cLocalFifo   <- replicateM(mkSizedFIFOF(4));
   FIFOF#(Bit#(53)) cGlobalFifo <- mkSizedFIFOF(4);
   Vector#(4, FIFOF#(Bit#(32))) intervalFifo <- replicateM(mkSizedFIFOF(4));
   Vector#(4, FIFOF#(Bit#(32))) dtpErrCntFifo <- replicateM(mkSizedFIFOF(4));
   FIFOF#(Bit#(1)) switchModeFifo <- mkSizedFIFOF(4);

   Reg#(Bit#(8))  lwrite_port <- mkReg(0);
   FIFOF#(BufData) lwrite_data_cycle1 <- mkSizedBypassFIFOF(3);
   FIFOF#(BufData) lwrite_data_cycle2 <- mkSizedBypassFIFOF(3);
   FIFOF#(void) log_write_cf <- mkFIFOF;
   Vector#(4, Reg#(Bit#(32))) lwrite_cnt_enq <- replicateM(mkReg(0));
   Vector#(4, Reg#(Bit#(32))) lwrite_cnt_deq1 <- replicateM(mkReg(0));
   Vector#(4, Reg#(Bit#(32))) lwrite_cnt_deq2 <- replicateM(mkReg(0));

   Vector#(4, FIFOF#(BufData)) lread_data_cycle1 <- replicateM(mkSizedBypassFIFOF(4));
   Vector#(4, FIFOF#(BufData)) lread_data_cycle2 <- replicateM(mkSizedBypassFIFOF(4));
   Vector#(4, FIFOF#(Bit#(53))) lread_data_timestamp <- replicateM(mkSizedBypassFIFOF(4));
   Vector#(4, Reg#(Bit#(32)))  lread_cnt_enq1 <- replicateM(mkReg(0));
   Vector#(4, Reg#(Bit#(32)))  lread_cnt_enq2 <- replicateM(mkReg(0));
   Vector#(4, Reg#(Bit#(32)))  lread_cnt_deq <- replicateM(mkReg(0));

   Reg#(Bit#(28)) dtp_rst_cntr <- mkReg(0);
   MakeResetIfc dtpResetOut <- mkResetSync(0, False, defaultClock);

   rule count;
      cycle_count <= cycle_count + 1;
   endrule

   // clear all fifo on reset
   rule clearOnReset(dtpResetOut.isAsserted);
      for (Integer i=0; i<4; i=i+1) begin
         fromHostFifo[i].clear();
         toHostFifo[i].clear();
         delayFifo[i].clear();
         stateFifo[i].clear();
         jumpCountFifo[i].clear();
         cLocalFifo[i].clear();
         intervalFifo[i].clear();
         dtpErrCntFifo[i].clear();
         lread_data_cycle1[i].clear();
         lread_data_cycle2[i].clear();
         lread_data_timestamp[i].clear();
      end
      cGlobalFifo.clear();
      cntFifo.clear();
      lwrite_data_cycle1.clear();
      lwrite_data_cycle2.clear();
      log_write_cf.clear();
   endrule

   // dtp_read_cnt
   rule snapshot_dtp_timestamp;
      let v <- toGet(cntFifo).get;
      cycle_reg <= v;
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
   Vector#(4, Reg#(Bit#(64))) jumpc_reg <- replicateM(mkReg(0));
   for (Integer i=0; i<4; i=i+1) begin
      rule snapshot_jumpc;
         let v <- toGet(jumpCountFifo[i]).get;
         jumpc_reg[i] <= v;
      endrule
   end

   // dtp_read_local_cnt
   Vector#(4, Reg#(Bit#(53))) clocal_reg <- replicateM(mkReg(0));
   for (Integer i=0; i<4; i=i+1) begin
      rule snapshot_clocal;
         let v <- toGet(cLocalFifo[i]).get;
         clocal_reg[i] <= v;
      endrule
   end

   // dtp_read_global_cnt
   Reg#(Bit#(53)) cglobal_reg <- mkReg(0);
   rule snapshot_cglobal;
      let v <- toGet(cGlobalFifo).get;
      cglobal_reg <= v;
   endrule

   // dtp_set_interval
   for (Integer i=0; i<4; i=i+1) begin
      rule set_interval;
         let v = beacon_interval[i];
         intervalFifo[i].enq(v);
      endrule
   end

   Vector#(4, Reg#(Bit#(32))) dtp_err_cnt <- replicateM(mkReg(0));
   for (Integer i=0; i<4; i=i+1) begin
      rule snapshot_dtp_err_cnt;
         let v <- toGet(dtpErrCntFifo[i]).get;
         dtp_err_cnt[i] <= v;
      endrule
   end

   Integer chunk_a = 0;
   Integer chunk_b = 1;
   function Bit#(2) toState(Integer st);
      return (1<<st);
   endfunction

   Reg#(Bit#(2)) lwstate <- mkReg(toState(chunk_a));
   // dtp_logger_write_cnt
   rule log_from_host_cycle (!dtpResetOut.isAsserted);
      if ((lwstate[chunk_a] == 1) && lwrite_data_cycle1.notEmpty) begin
         let v1 = lwrite_data_cycle1.first;
         if (fromHostFifo[v1.port_no].notFull) begin
            fromHostFifo[v1.port_no].enq({1'b0, truncate(v1.data)});
            lwrite_data_cycle1.deq;
            lwstate <= toState(chunk_b);
            lwrite_cnt_deq1[v1.port_no] <= lwrite_cnt_deq1[v1.port_no] + 1;
         end
      end
      else if((lwstate[chunk_b] == 1) && lwrite_data_cycle2.notEmpty) begin
         let v2 = lwrite_data_cycle2.first;
         if (fromHostFifo[v2.port_no].notFull) begin
            fromHostFifo[v2.port_no].enq({1'b1, truncate(v2.data)});
            lwrite_data_cycle2.deq;
            lwstate <= toState(chunk_a);
            lwrite_cnt_deq2[v2.port_no] <= lwrite_cnt_deq2[v2.port_no] + 1;
         end
      end
   endrule
   rule reset_from_host (dtpResetOut.isAsserted);
      for (Integer i=0; i<4; i=i+1) begin
         lwrite_cnt_deq1[i]<= 0;
         lwrite_cnt_deq2[i]<= 0;
      end
   endrule

   for (Integer i=0; i<4; i=i+1) begin
      rule save_host_data (!dtpResetOut.isAsserted);
         let v <- toGet(toHostFifo[i]).get;

         Bit#(53) timestamp = 0;
            if (switch_mode_reg == 0) begin // 0 for NIC, 1 for Switch
               timestamp = clocal_reg[i] + 3;
            end
            else begin
               timestamp = cglobal_reg + 3;
            end 

         if (v[52] == 0) begin
            lread_data_cycle1[i].enq(BufData{port_no:fromInteger(i), data:zeroExtend(v[51:0])});
            lread_data_timestamp[i].enq(timestamp); 
            lread_cnt_enq1[i] <= lread_cnt_enq1[i] + 1;
         end
         else if (v[52] == 1) begin
            lread_data_cycle2[i].enq(BufData{port_no:fromInteger(i), data:zeroExtend(v[51:0])});
            Bit#(53) timestamp = 0;
            if (switch_mode_reg == 0) begin // 0 for NIC, 1 for Switch
               timestamp = clocal_reg[i];
            end
            else begin
               timestamp = cglobal_reg;
            end
            lread_data_timestamp[i].enq(timestamp);
            lread_cnt_enq2[i] <= lread_cnt_enq2[i] + 1;
         end
      endrule
      rule reset_host_data (dtpResetOut.isAsserted);
         lread_cnt_enq1[i] <= 0;
         lread_cnt_enq2[i] <= 0;
      endrule
   end

   rule assert_reset (dtp_rst_cntr > 0);
      dtpResetOut.assertReset;
      dtp_rst_cntr <= dtp_rst_cntr - 1;
   endrule

   rule switch_mode;
      switchModeFifo.enq(switch_mode_reg);
   endrule

   // Interface to external modules.
   interface dtp = (interface DtpIfc;
      interface timestamp = toPipeIn(cntFifo);
      interface delay     = map(toPipeIn, delayFifo);
      interface state     = map(toPipeIn, stateFifo);
      interface jumpCount = map(toPipeIn, jumpCountFifo);
      interface toHost    = map(toPipeIn, toHostFifo);
      interface fromHost  = map(toPipeOut, fromHostFifo);
      interface cLocal    = map(toPipeIn, cLocalFifo);
      interface globalOut = toPipeIn(cGlobalFifo);
      interface interval  = map(toPipeOut, intervalFifo);
      interface dtpErrCnt = map(toPipeIn, dtpErrCntFifo);
      interface rst       = dtpResetOut.new_rst;
      interface switchMode  = toPipeOut(switchModeFifo);
   endinterface);

   // API implementation
   interface DtpUserRequest request;
   method Action dtp_read_version();
      let v = `DtpVersion; //Defined in Makefile as time of compilation.
      indication.dtp_read_version_resp(v);
   endmethod
   method Action dtp_reset(Bit#(32) len) if (dtp_rst_cntr == 0);
      Bit#(28) limit = truncate(len) & 28'hFFFFFFF;
      if (limit < 32) begin
         limit = 32;
      end
      dtp_rst_cntr <= limit;
      for (Integer i=0; i<4; i=i+1) begin
         lwrite_cnt_enq[i] <= 0;
         lread_cnt_deq[i]  <= 0;
      end
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
      if (port_no < 4) begin
         indication.dtp_read_error_resp(port_no, jumpc_reg[port_no]);
      end
   endmethod
   method Action dtp_read_cnt(Bit#(8) port_no);
      indication.dtp_read_cnt_resp(truncate(cycle_reg));
   endmethod
   method Action dtp_logger_write_cnt(Bit#(8) port_no, Bit#(64) host_timestamp);
      // Check valid port No.
      if (port_no < 4) begin
         lwrite_data_cycle1.enq(BufData{port_no: port_no, data: host_timestamp});
         lwrite_data_cycle2.enq(BufData{port_no: port_no, data: zeroExtend(clocal_reg[port_no])});
         lwrite_cnt_enq[port_no] <= lwrite_cnt_enq[port_no] + 1;
      end
   endmethod
   method Action dtp_logger_read_cnt(Bit#(8) port_no);
      if (port_no < 4) begin
         if (lread_data_cycle1[port_no].notEmpty &&
             lread_data_cycle2[port_no].notEmpty &&
             lread_data_timestamp[port_no].notEmpty) begin
            Bit#(64) remote_message1 = lread_data_cycle1[port_no].first.data;
            Bit#(64) remote_message2 = lread_data_cycle2[port_no].first.data;
            Bit#(53) timestamp = lread_data_timestamp[port_no].first;
            indication.dtp_logger_read_cnt_resp(port_no,
                                                zeroExtend(timestamp),
                                                zeroExtend(remote_message1),
                                                zeroExtend(remote_message2));
            lread_data_cycle1[port_no].deq;
            lread_data_cycle2[port_no].deq;
            lread_data_timestamp[port_no].deq;
            lread_cnt_deq[port_no] <= lread_cnt_deq[port_no] + 1;
         end
      end
   endmethod
   method Action dtp_read_local_cnt(Bit#(8) port_no);
      if (port_no < 4) begin
         indication.dtp_read_local_cnt_resp(port_no, zeroExtend(clocal_reg[port_no]));
      end
   endmethod
   method Action dtp_read_global_cnt();
      indication.dtp_read_global_cnt_resp(zeroExtend(cglobal_reg));
   endmethod
   method Action dtp_set_beacon_interval(Bit#(8) port_no, Bit#(32) interval);
      if (port_no < 4) begin
         beacon_interval[port_no] <= interval;
      end
   endmethod
   method Action dtp_read_beacon_interval(Bit#(8) port_no);
      if (port_no < 4) begin
         indication.dtp_read_beacon_interval_resp(port_no, beacon_interval[port_no]);
      end
   endmethod
   method Action dtp_debug_rcvd_msg (Bit#(8) port_no);
      if (port_no < 4) begin
         indication.dtp_debug_rcvd_msg_resp(port_no, lread_cnt_enq1[port_no], lread_cnt_enq2[port_no], lread_cnt_deq[port_no]);
      end
   endmethod
   method Action dtp_debug_sent_msg (Bit#(8) port_no);
      if (port_no < 4) begin
         indication.dtp_debug_sent_msg_resp(port_no, lwrite_cnt_enq[port_no], lwrite_cnt_deq1[port_no], lwrite_cnt_deq2[port_no]);
      end
   endmethod
   method Action dtp_debug_rcvd_err (Bit#(8) port_no);
      if (port_no < 4) begin
         indication.dtp_debug_rcvd_err_resp(port_no, dtp_err_cnt[port_no]);
      end
   endmethod
   method Action dtp_set_mode(Bit#(8) mode);
      switch_mode_reg <= mode[0];
   endmethod
   method Action dtp_get_mode();
      indication.dtp_get_mode_resp(zeroExtend(switch_mode_reg));
   endmethod
   endinterface
endmodule

