
// Copyright (c) 2013 Nokia, Inc.

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

typedef struct {
   Bit#(8) port_no;
   Bit#(64) local_cnt;
   Bit#(64) global_cnt;
   } S3 deriving (Bits, Eq);

interface DtpIfc;
   interface PipeIn#(Bit#(128)) timestamp; // streaming time counter from NetTop.
   interface PipeOut#(Bit#(128)) logOut; //
   interface Vector#(4, PipeIn#(Bit#(128))) logIn;
endinterface

interface SonicUserRequest;
   method Action read_timestamp_req(Bit#(8) cmd);
   method Action write_delay(Bit#(64) host_cnt);
   method Action log_write(Bit#(8) port_no, Bit#(64) local_cnt);
   method Action log_read_req(Bit#(8) port_no);
endinterface

interface SonicUserIndication;
   method Action read_timestamp_resp(Bit#(64) val);
   method Action log_read_resp(Bit#(8) port_no, Bit#(64) local_cnt, Bit#(64) global_cnt);
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

   Vector#(4, FIFOF#(Bit#(128))) logOutFifo <- replicateM(mkSizedFIFOF(32));
   Vector#(4, FIFOF#(Bit#(128))) logInFifo <- replicateM(mkSizedFIFOF(32));
   Vector#(4, Reg#(Bit#(128)))   logInReg <- replicateM(mkReg(0));

   rule count;
      cycle_count <= cycle_count + 1;
   endrule

   rule receive_dtp_timestamp;
      let v <- toGet(rxFifo).get;
      timestamp_reg <= v;
   endrule

   for (Integer i=0; i<4; i=i+1) begin
      rule log_read_timestamp;
         let v <- toGet(logInFifo[i]).get;
         logInReg[i] <= v;
      endrule
   end

   interface dtp = (interface DtpIfc;
      interface timestamp = toPipeIn(rxFifo);
   endinterface);

   interface SonicUserRequest request;
   method Action read_timestamp_req(Bit#(8) cmd);
      indication.read_timestamp_resp(truncate(timestamp_reg));
   endmethod
   method Action write_delay(Bit#(64) host_cnt);
      Bit#(64) delay = (host_cnt - cycle_count) >> 1;
   endmethod
   method Action log_write(Bit#(8) port_no, Bit#(64) host_timestamp);
      case (port_no)
         0: logOutFifo[0].enq(zeroExtend(host_timestamp));
         1: logOutFifo[1].enq(zeroExtend(host_timestamp));
         2: logOutFifo[2].enq(zeroExtend(host_timestamp));
         3: logOutFifo[3].enq(zeroExtend(host_timestamp));
      endcase
   endmethod
   method Action log_read_req(Bit#(8) port_no);
      Int#(64) invalid_data=-1;
      Int#(8)  invalid_port=-1;
      case (port_no)
         0: indication.log_read_resp(0, truncate(timestamp_reg), truncate(logInReg[0]));
         1: indication.log_read_resp(1, truncate(timestamp_reg), truncate(logInReg[1]));
         2: indication.log_read_resp(2, truncate(timestamp_reg), truncate(logInReg[2]));
         3: indication.log_read_resp(3, truncate(timestamp_reg), truncate(logInReg[3]));
         default: indication.log_read_resp(pack(signExtend(invalid_port)), pack(signExtend(invalid_data)), pack(signExtend(invalid_data)));
      endcase
   endmethod
   endinterface
endmodule
