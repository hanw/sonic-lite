
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

package MacRx;

import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;

import Pipe::*;
import MemTypes::*;
import CRC32::*;
import Utils::*;

`define LANE0 7:0
`define LANE1 15:8
`define LANE2 23:16
`define LANE3 31:24
`define LANE4 39:32
`define LANE5 47:40
`define LANE6 55:48
`define LANE7 63:56

typedef enum {IDLE, RX} State deriving (Bits, Eq);

interface MacRx;
   interface PipeOut#(Bit#(2)) local_fault_out;
   interface PipeOut#(Bit#(2)) remote_fault_out;
endinterface

module mkMacRx#(PipeOut#(Bit#(72)) xgmiiIn)(MacRx);

   let verbose = True;
   Reg#(State) curr_state <- mkReg(IDLE);

   Reg#(Bit#(64)) xgmii_rxd_d1 <- mkReg(0);
   Reg#(Bit#(64)) xgmii_rxc_d1 <- mkReg(0);
   Reg#(Bit#(64)) xgmii_rxd_barrel_d1 <- mkReg(0);
   Reg#(Bit#(64)) xgmii_rxc_barrel_d1 <- mkReg(0);
   Reg#(Bit#(1)) barrel_shift <- mkReg(0);
   Reg#(Bit#(32)) crc32_d64 <- mkReg(0);
   Reg#(Bit#(32)) crc32_d8 <- mkReg(0);

   Reg#(Bit#(14)) curr_byte_cnt <- mkReg(0);
   FIFOF#(Bit#(2)) localFaultFifo <- mkFIFOF;
   FIFOF#(Bit#(2)) remoteFaultFifo <- mkFIFOF;

   FIFOF#(XgmiiTup) xgmiiFifoStage1 <- mkFIFOF;
   FIFOF#(XgmiiTup) xgmiiFifoStage2 <- mkFIFOF;
   FIFOF#(XgmiiTup) checkFragmentFifo <- mkBypassFIFOF;
   FIFOF#(XgmiiTup) checkLengthFifo   <- mkBypassFIFOF;
   FIFOF#(XgmiiTup) checkPauseFifo    <- mkBypassFIFOF;
   FIFOF#(XgmiiTup) checkCtrlFifo     <- mkBypassFIFOF;
   FIFOF#(XgmiiTup) updateByteCntFifo <- mkBypassFIFOF;
   FIFOF#(XgmiiTup) checkEndFrameFifo <- mkBypassFIFOF;

   FIFOF#(Bool) fragmentErrFifo <- mkFIFOF;
   FIFOF#(Bool) pauseFrameFifo  <- mkFIFOF;
   FIFOF#(Bool) codingErrorFifo <- mkFIFOF;
   FIFOF#(Bool) crcStart8bFifo  <- mkFIFOF;
   FIFOF#(Bit#(4)) nextCrcBytesFifo  <- mkFIFOF;
   FIFOF#(Bit#(32)) nextCrcRxFifo  <- mkFIFOF;

   Reg#(Bit#(1)) crc_done <- mkReg(0);
   Reg#(Bit#(4)) crc_bytes <- mkReg(0);
   Reg#(Bit#(1)) coding_error <- mkReg(0);
   Reg#(Bit#(64)) crc_shift_data <- mkReg(0);
   // Link status RC layer
   // Look for local/remote messages on lower 4 lanes and upper
   // 4 lanes. This is a 64-bit interface but look at each 32-bit
   // independantly.
   rule link_status;
      Bit#(8) seqn = fromInteger(valueOf(Sequence));
      Bit#(8) localFault = fromInteger(valueOf(LocalFault));
      Bit#(8) remoteFault = fromInteger(valueOf(RemoteFault));

      Vector#(8, Bit#(8)) rxd;
      Vector#(8, Bit#(1)) rxc;
      Bit#(64) xgmii_rxd;
      Bit#(8)  xgmii_rxc;
      let v <- toGet(xgmiiIn).get;
      for (Integer i=0; i<8; i=i+1) begin
         rxd[i] = v[9*i+7 : 9*i];
         rxc[i] = v[9*i+8];
      end
      xgmii_rxd = pack(rxd);
      xgmii_rxc = pack(rxc);

      Vector#(2, Bit#(1)) local_fault;
      Vector#(2, Bit#(1)) remote_fault;

      local_fault[1] = pack(xgmii_rxd[63:32] == {localFault, 8'h0, 8'h0, seqn} && xgmii_rxc[7:4] == 4'b0001);
      local_fault[0] = pack(xgmii_rxd[31:0] == {localFault, 8'h0, 8'h0, seqn} && xgmii_rxc[3:0] == 4'b0001);
      remote_fault[1] = pack(xgmii_rxd[63:32] == {remoteFault, 8'h0, 8'h0, seqn} && xgmii_rxc[7:4] == 4'b0001);
      remote_fault[0] = pack(xgmii_rxd[31:0] == {remoteFault, 8'h0, 8'h0, seqn} && xgmii_rxc[3:0] == 4'b0001);

      //localFaultFifo.enq(pack(local_fault));    //FIXME
      //remote_fault_msg.enq(pack(remote_fault));
      xgmiiFifoStage1.enq(XgmiiTup{data: xgmii_rxd, ctrl: xgmii_rxc});
   endrule

   // Rotating barrel. This function allow us to always align the start of
   // a frame with LANE0. If frame starts in LANE4, it will be shifted 4 bytes
   // to LANE0, thus reducing the amount of logic needed at the next stage.
   rule shift_xgmii;
      Bit#(8) start = fromInteger(valueOf(Start));
      Bit#(64) xgmii_rxd;
      Bit#(8) xgmii_rxc;
      let v <- toGet(xgmiiFifoStage1).get;
      xgmii_rxd = v.data;
      xgmii_rxc = v.ctrl;

      xgmii_rxd_d1[63:32] <= xgmii_rxd[63:32];
      xgmii_rxc_d1[7:4] <= xgmii_rxc[7:4];

      Bit#(64) xgxs_rxd_barrel;
      Bit#(8)  xgxs_rxc_barrel;
      if (xgmii_rxd[7:0] == start && xgmii_rxc[0] == 1'b1) begin
         xgxs_rxd_barrel = xgmii_rxd;
         xgxs_rxc_barrel = xgmii_rxc;
         barrel_shift <= 1'b0;
      end
      else if (xgmii_rxd[39:32] == start && xgmii_rxc[4] == 1'b1) begin
         xgxs_rxd_barrel = {xgmii_rxd[31:0], xgmii_rxd_d1[63:32]};
         xgxs_rxc_barrel = {xgmii_rxc[3:0], xgmii_rxc_d1[7:4]};
         barrel_shift <= 1'b1;
      end
      else if (barrel_shift == 1'b1) begin
         xgxs_rxd_barrel = {xgmii_rxd[31:0], xgmii_rxd_d1[63:32]};
         xgxs_rxc_barrel = {xgmii_rxc[3:0], xgmii_rxc_d1[7:4]};
      end
      else begin
         xgxs_rxd_barrel = xgmii_rxd;
         xgxs_rxc_barrel = xgmii_rxc;
      end
      xgmiiFifoStage2.enq(XgmiiTup{data: xgxs_rxd_barrel, ctrl: xgxs_rxc_barrel});
   endrule

   // When final CRC calculation begins we capture info relevant to
   // current frame CRC claculation continues while next frame is
   // being received.
   rule compute_crc;
      Bit#(1) crc_clear = 0;
      Bit#(64) xgmii_rxd;
      Bit#(8) xgmii_rxc;

      let v <- toGet(xgmiiFifoStage2).get;
      xgmii_rxd = v.data;
      xgmii_rxc = v.ctrl;

      if (crc_clear == 1'b1) begin
         crc32_d64 <= 32'hFFFFFFFF;
      end
      else begin
         crc32_d64 <= nextCRC32_D64(reverse_64b(xgmii_rxd), crc32_d64);
      end

      if (crc_bytes != 4'b0) begin
         if (crc_bytes == 4'b1) begin
            crc_done <= 1'b1;
         end
         crc32_d8 <= nextCRC32_D8(reverse_8b(crc_shift_data[7:0]), crc32_d8);
         crc_shift_data <= {8'h0, crc_shift_data[63:8]};
         crc_bytes <= crc_bytes - 4'b1;
      end
      else if (crc_bytes == 4'b0) begin
         if (coding_error == 1'b1) begin //FIXME
            crc32_d8 <= ~crc32_d64;
         end
         else begin
            crc32_d8 <= crc32_d64;
         end
         crc_done <= 1'b0;
         crc_shift_data <= xgmii_rxd;
         crc_bytes <= 0; //FIXME
      end

//      if (crc_done && !crc_good) begin
//
//      end
//
//      if (fragment_error) begin
//
//      end
   endrule

   function Bool detectStartFrame(XgmiiTup xgmii);
      Bit#(8) preamble = fromInteger(valueOf(Preamble));
      Bit#(8) start = fromInteger(valueOf(Start));
      Bit#(8) sfd = fromInteger(valueOf(Sfd));
      Bit#(64) xgmii_rxd;
      Bit#(8) xgmii_rxc;
      xgmii_rxd = xgmii.data;
      xgmii_rxc = xgmii.ctrl;

      return ((xgmii_rxd[`LANE0] == start &&     xgmii_rxc[0]==1'b1) &&
              (xgmii_rxd[`LANE1] == preamble && !(xgmii_rxc[1]==1'b1)) &&
              (xgmii_rxd[`LANE2] == preamble && !(xgmii_rxc[2]==1'b1)) &&
              (xgmii_rxd[`LANE3] == preamble && !(xgmii_rxc[3]==1'b1)) &&
              (xgmii_rxd[`LANE4] == preamble && !(xgmii_rxc[4]==1'b1)) &&
              (xgmii_rxd[`LANE5] == preamble && !(xgmii_rxc[5]==1'b1)) &&
              (xgmii_rxd[`LANE6] == preamble && !(xgmii_rxc[6]==1'b1)) &&
              (xgmii_rxd[`LANE7] == sfd &&      !(xgmii_rxc[7]==1'b1)));
   endfunction

   rule fragement_received;
      Bit#(8) start = fromInteger(valueOf(Start));
      Bit#(8) sfd = fromInteger(valueOf(Sfd));
      Bit#(64) xgmii_rxd;
      Bit#(8) xgmii_rxc;
      let v <- toGet(checkFragmentFifo).get;
      xgmii_rxd = v.data;
      xgmii_rxc = v.ctrl;

      if ((xgmii_rxd[`LANE0] == start && xgmii_rxc[0] == 1'b1) &&
          (xgmii_rxd[`LANE7] == sfd && xgmii_rxc[7] == 1'b1)) begin

          fragmentErrFifo.enq(True);
          // Write Error Status
      end

      // don't write to output
      // else write fake EOP
      checkLengthFifo.enq(XgmiiTup{data: xgmii_rxd, ctrl: xgmii_rxc});
   endrule

   rule too_long (curr_state == RX);
      Bit#(64) xgmii_rxd;
      Bit#(8) xgmii_rxc;
      let v <- toGet(checkLengthFifo).get;
      xgmii_rxd = v.data;
      xgmii_rxc = v.ctrl;

      if (curr_byte_cnt > 14'd9900) begin
         fragmentErrFifo.enq(True);
         // write Error status
         // write EOP
         // change state
      end
      curr_state <= IDLE;
      checkPauseFifo.enq(XgmiiTup{data: xgmii_rxd, ctrl: xgmii_rxc});
   endrule

   rule filter_pause (curr_state == RX);
      Bit#(48) pause_frame = fromInteger(valueOf(PauseFrame));
      Bit#(64) xgmii_rxd;
      Bit#(8) xgmii_rxc;
      let v <- toGet(checkLengthFifo).get;
      xgmii_rxd = v.data;
      xgmii_rxc = v.ctrl;

      if (curr_byte_cnt == 14'd0 && xgmii_rxd[47:0] == pause_frame) begin
         pauseFrameFifo.enq(True);
      end
      checkCtrlFifo.enq(XgmiiTup{data: xgmii_rxd, ctrl: xgmii_rxc});
   endrule

   function Bit#(1) vectorAnd(Bit#(n) value);
      Bit#(1) res = 1;
      for (Integer i=0; i< valueOf(n); i=i+1) begin
         res = res & value[i];
      end
      return res;
   endfunction

   rule ctrl_in_data_error;
      Bit#(8) terminate = fromInteger(valueOf(Terminate));
      Bit#(64) xgmii_rxd;
      Bit#(8) xgmii_rxc;
      let v <- toGet(checkLengthFifo).get;
      xgmii_rxd = v.data;
      xgmii_rxc = v.ctrl;

      Vector#(8, Bit#(1)) addmask;
      Vector#(8, Bit#(1)) datamask;

      addmask[0] = pack(xgmii_rxd[`LANE0] == terminate && xgmii_rxc[0] == 1'b1);
      addmask[1] = pack(xgmii_rxd[`LANE1] == terminate && xgmii_rxc[1] == 1'b1);
      addmask[2] = pack(xgmii_rxd[`LANE2] == terminate && xgmii_rxc[2] == 1'b1);
      addmask[3] = pack(xgmii_rxd[`LANE3] == terminate && xgmii_rxc[3] == 1'b1);
      addmask[4] = pack(xgmii_rxd[`LANE4] == terminate && xgmii_rxc[4] == 1'b1);
      addmask[5] = pack(xgmii_rxd[`LANE5] == terminate && xgmii_rxc[5] == 1'b1);
      addmask[6] = pack(xgmii_rxd[`LANE6] == terminate && xgmii_rxc[6] == 1'b1);
      addmask[7] = pack(xgmii_rxd[`LANE7] == terminate && xgmii_rxc[7] == 1'b1);

      datamask[0] = addmask[0];
      datamask[1] = vectorAnd(pack(addmask)[1:0]);
      datamask[2] = vectorAnd(pack(addmask)[2:0]);
      datamask[3] = vectorAnd(pack(addmask)[3:0]);
      datamask[4] = vectorAnd(pack(addmask)[4:0]);
      datamask[5] = vectorAnd(pack(addmask)[5:0]);
      datamask[6] = vectorAnd(pack(addmask)[6:0]);
      datamask[7] = vectorAnd(pack(addmask)[7:0]);

      Bit#(1) ctrlInDataErr = 0;
      for (Integer i=0; i<8; i=i+1) begin
         ctrlInDataErr = ctrlInDataErr | (xgmii_rxc[i] & datamask[i]);
      end

      if (ctrlInDataErr == 1'b1) begin
         codingErrorFifo.enq(True);
      end
      updateByteCntFifo.enq(XgmiiTup{data: xgmii_rxd, ctrl: xgmii_rxc});
   endrule

   rule update_byte_cnt;
      Bit#(64) xgmii_rxd;
      Bit#(8) xgmii_rxc;
      let v <- toGet(updateByteCntFifo).get;
      xgmii_rxd = v.data;
      xgmii_rxc = v.ctrl;

      curr_byte_cnt <= curr_byte_cnt;
      checkEndFrameFifo.enq(XgmiiTup{data: xgmii_rxd, ctrl: xgmii_rxc});
   endrule

   rule check_terminate;
      Bit#(8) terminate = fromInteger(valueOf(Terminate));
      Bit#(64) xgmii_rxd;
      Bit#(8) xgmii_rxc;
      let v <- toGet(checkEndFrameFifo).get;
      xgmii_rxd = v.data;
      xgmii_rxc = v.ctrl;

      // Look ahead for TERMINATE
      if (xgmii_rxd[`LANE4] == terminate && xgmii_rxc[4] == 1'b1) begin
         crcStart8bFifo.enq(True);
         nextCrcBytesFifo.enq(4'd8);
         nextCrcRxFifo.enq(xgmii_rxd[31:0]); //FIXME
         curr_state <= IDLE;
      end
      else if (xgmii_rxd[`LANE3] == terminate && xgmii_rxc[3] == 1'b1) begin
         crcStart8bFifo.enq(True);
         nextCrcBytesFifo.enq(4'd7);
         nextCrcRxFifo.enq(xgmii_rxd[31:0]); //FIXME
         curr_state <= IDLE;
      end
      else if (xgmii_rxd[`LANE2] == terminate && xgmii_rxc[2] == 1'b1) begin
         crcStart8bFifo.enq(True);
         nextCrcBytesFifo.enq(4'd6);
         nextCrcRxFifo.enq(xgmii_rxd[31:0]); //FIXME
         curr_state <= IDLE;
      end
      else if (xgmii_rxd[`LANE1] == terminate && xgmii_rxc[1] == 1'b1) begin
         crcStart8bFifo.enq(True);
         nextCrcBytesFifo.enq(4'd5);
         nextCrcRxFifo.enq(xgmii_rxd[31:0]); //FIXME
         curr_state <= IDLE;
      end
      else if (xgmii_rxd[`LANE0] == terminate && xgmii_rxc[0] == 1'b1) begin
         crcStart8bFifo.enq(True);
         nextCrcBytesFifo.enq(4'd4);
         nextCrcRxFifo.enq(xgmii_rxd[31:0]); //FIXME
         curr_state <= IDLE;
      end
      // Look at current cycle for TERMINATE in lane5 to 7
      else if (xgmii_rxd[`LANE7] == terminate && xgmii_rxc[7] == 1'b1) begin
         crcStart8bFifo.enq(True);
         nextCrcBytesFifo.enq(4'd3);
         nextCrcRxFifo.enq(xgmii_rxd[31:0]); //FIXME
         curr_state <= IDLE;
      end
      else if (xgmii_rxd[`LANE6] == terminate && xgmii_rxc[6] == 1'b1) begin
         crcStart8bFifo.enq(True);
         nextCrcBytesFifo.enq(4'd2);
         nextCrcRxFifo.enq(xgmii_rxd[31:0]); //FIXME
         curr_state <= IDLE;
      end
      else if (xgmii_rxd[`LANE5] == terminate && xgmii_rxc[5] == 1'b1) begin
         crcStart8bFifo.enq(True);
         nextCrcBytesFifo.enq(4'd1);
         nextCrcRxFifo.enq(xgmii_rxd[31:0]); //FIXME
         curr_state <= IDLE;
      end
   endrule

   //interface local_fault_out = local_fault_msg;
   //interface remote_fault_out = remote_fault_msg;
endmodule
endpackage

