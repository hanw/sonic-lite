
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
endinterface

interface SonicUserRequest;
   method Action read_timestamp_req(Bit#(8) cmd);
   method Action log_write(Bit#(8) port_no, Bit#(64) local_cnt);
   method Action log_read_req(Bit#(8) port_no);
endinterface

interface SonicUserIndication;
   method Action read_timestamp_resp(Bit#(64) val);
   method Action log_read_resp(Bit#(8) port_no, Bit#(64) local_cnt, Bit#(64) global_cnt);
   method Action debug_probe(Bit#(8) port_no, Bit#(64) host_ts, Bit#(64) host_buffer);
endinterface

interface SonicUser;
   interface SonicUserRequest request;
   interface DtpIfc           dtp;
endinterface

module mkSonicUser#(SonicUserIndication indication)(SonicUser);
   let verbose = False;
   Reg#(Bit#(64))  cycle_count <- mkReg(0);
   Reg#(Bit#(64))  last_count  <- mkReg(0);

   FIFOF#(Bit#(128)) rxFifo    <- mkFIFOF();
   Reg#(Bit#(128)) timestamp_reg <- mkReg(0);

   Vector#(4, FIFOF#(Bit#(53))) fromHostFifo <- replicateM(mkSizedFIFOF(4));
   Vector#(4, FIFOF#(Bit#(53))) toHostFifo <- replicateM(mkSizedFIFOF(4));
   FIFOF#(BufData) toHostBuffered <- mkSizedFIFOF(16);

   Reg#(Bit#(8))  lwrite_port <- mkReg(0);
   Reg#(Bit#(53)) lwrite_timestamp <- mkReg(0);
   FIFOF#(BufData) lwrite_cf <- mkSizedFIFOF(8);

   Reg#(Bit#(8))  lread_port <- mkReg(0);
   FIFOF#(void)   lread_cf <- mkSizedFIFOF(8);

   rule count;
      cycle_count <= cycle_count + 1;
   endrule

   rule snapshot_dtp_timestamp;
      let v <- toGet(rxFifo).get;
      timestamp_reg <= v;
   endrule

//   rule log_from_host (lwrite_cf.notEmpty);
//      let v = lwrite_cf.first;
//      //if (fromHostFifo[v.port_no].notFull) begin
//         //fromHostFifo[v.port_no].enq(truncate(v.data));
//         lwrite_cf.deq;
//      //end
//   endrule

   Wire#(Bit#(8))  debug_port_no <- mkDWire(0);
   Wire#(Bit#(53)) debug_host_timestamp <- mkDWire(0);
   rule cannot_log_from_host(!fromHostFifo[lwrite_port].notFull);
      debug_port_no <= lwrite_port;
      debug_host_timestamp <= lwrite_timestamp;
   endrule

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

   Wire#(Bit#(64)) debug_host_buffer <-mkDWire(0);
   rule log_to_host(toHostBuffered.notEmpty);
      let v = toHostBuffered.first;
      indication.log_read_resp(v.port_no, truncate(timestamp_reg), v.data);
      debug_host_buffer <= 64'hAAAA;
      toHostBuffered.deq;
   endrule

   rule cannot_log_to_host(!toHostBuffered.notEmpty);
      debug_host_buffer <= cycle_count;
   endrule

   rule debug_portal;
      indication.debug_probe(debug_port_no, zeroExtend(debug_host_timestamp), debug_host_buffer);
   endrule

   interface dtp = (interface DtpIfc;
      interface timestamp = toPipeIn(rxFifo);
      interface toHost = map(toPipeIn, toHostFifo);
      interface fromHost = map(toPipeOut, fromHostFifo);
   endinterface);

   interface SonicUserRequest request;
   method Action read_timestamp_req(Bit#(8) cmd);
      indication.read_timestamp_resp(truncate(timestamp_reg));
   endmethod
//   method Action log_write(Bit#(8) port_no, Bit#(64) host_timestamp);
      // Check valid port No.
//      if (port_no < 4) begin
//         lwrite_cf.enq(BufData{port_no: port_no, data: host_timestamp});
//      end
//   endmethod
   method Action log_read_req(Bit#(8) port_no);
      if (port_no < 4) begin
         lread_port <= port_no;
      end
   endmethod
endinterface
endmodule

