
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

package MacTx;

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

interface MacTx;
   interface PipeOut#(Bit#(72)) macTxOut;
endinterface

typedef enum {IDLE, PREAMBLE, TX, EOP, TERM, TERM_FAIL, IFG} State
deriving (Bits, Eq);

module mkMacTx#(PipeOut#(Bit#(72)) macTxIn)(MacTx);

   Reg#(Bool) tx_enable <- mkBool(True);
   Reg#(Bit#(1)) status_local_fault_ctx <- mkReg(0);
   Reg#(Bit#(1)) status_remote_fault_ctx <- mkReg(0);

   FIFOF#(XgmiiTup) barrelOutFifo <- mkFIFOF;
   FIFOF#(XgmiiTup) macOutFifo <- mkFIFOF;
   FIFOF#(XgmiiTup) statePeambleFifo <- mkBypassFIFOF;
   FIFOF#(XgmiiTup) stateTxFifo <- mkBypassFIFOF;
   FIFOF#(XgmiiTup) stateEopFifo <- mkBypassFIFOF;
   FIFOF#(XgmiiTup) stateTermFifo <- mkBypassFIFOF;
   FIFOF#(XgmiiTup) stateTermFailFifo <- mkBypassFIFOF;
   FIFOF#(XgmiiTup) stateIfgFifo <- mkBypassFIFOF;

   Reg#(Bit#(8)) eop <- mkReg(0);

   rule rc;
      Bit#(8) localFault = fromInteger(valueOf(LocalFault));
      Bit#(8) remoteFault = fromInteger(valueOf(RemoteFault));
      Bit#(8) seqn = fromInteger(valueOf(Sequence));
      Bit#(8) idle = fromInteger(valueOf(Idle));

      if (status_local_fault_ctx == 1'b1) begin
         macOutFifo.enq(XgmiiTup{data: {remoteFault, 8'h0, 8'h0, seqn,
                                        remoteFault, 8'h0, 8'h0, seqn},
                                 ctrl: {4'b0001, 4'b0001}});
      end
      else if (status_remote_fault_ctx == 1'b1) begin
         macOutFifo.enq(XgmiiTup{data: {idle, idle, idle, idle,
                                        idle, idle, idle, idle},
                                 ctrl: 8'hff});
      end
      else begin
         let v <- toGet(barrelOutFifo).get;
         macOutFifo.enq(v);
      end
   endrule

   rule barrelshift;

   endrule

   // Wait for frame to be available. There should be a least N bytes in the
   // data fifo or a crc in the control fifo. The N bytes in the data fifo
   // give time to the enqueue engine to calculate crc and write it to the
   // control fifo. If crc is already in control fifo we can start transmitting
   // with no concern. Transmission is inhibited if local or remote faults
   // are detected.
   rule state_idle (state == IDLE);
      Vector#(8, Bit#(8)) txd;
      Vector#(8, Bit#(1)) txc;
      Bit#(64) xgmii_txd;
      Bit#(8)  xgmii_txc;
      let v <- toGet(macTxIn).get;
      for (Integer i=0; i<8; i=i+1) begin
         txd[i] = v[9*i+7 : 9*i];
         txc[i] = v[9*i+8];
      end
      xgmii_txd = pack(txd);
      xgmii_txc = pack(txc);

      state <= PREAMBLE;
      statePeambleFifo.enq(XgmiiTup{data: xgmii_txd, ctrl: xgmii_txc});
   endrule

   rule state_preamble (state == PREAMBLE);
      Bit#(8) start = fromInteger(valueOf(Start));
      Bit#(8) sfd = fromInteger(valueOf(Sfd));
      Bit#(8) preamble = fromInteger(valueOf(Preamble));
      Bit#(64) xgmii_txd;
      Bit#(8) xgmii_txc;
      let v <- toGet(statePeambleFifo).get;
      xgmii_rxd = v.data;
      xgmii_rxc = v.ctrl;

      macOutFifo.enq({sfd, preamble, preamble, preamble,
                      preamble, preamble, premable, start});

      // if SOP;
      state <= TX;
      // else IDLE

      // Depending on deficit idle count calculations, add 4 bytes
      // or IFG or not. This will determine on which lane start the
      // next frame.
      // if (ifg_4b_add) begin
      //
   endrule

   rule state_tx (state == TX);

      Bit#(64) xgmii_txd;
      Bit#(8) xgmii_txc;
      let v <- toGet(macTxIn).get;
      xgmii_rxd = v.data;
      xgmii_rxc = 8'h00;

      // Wait for EOP indication to be read from the fifo, then
      // transition to next state.

      if (v.eop == 1'b1) begin
         state <= EOP;
      end
      else if (v.sop == 1'b1) begin
         state <= TERM_FAIL;
      end

      // compute next_eop
   endrule

   rule state_eop (state == EOP);
      Bit#(8) idle = fromInteger(valueOf(Idle));
      Bit#(8) terminate = fromInteger(valueOf(Terminate));
      // Insert TERMINATE character in correct lane depending on position
      // of EOP read from fifo. Also insert CRC read from control fifo.
      Bit#(64) xgmii_txd;
      Bit#(8) xgmii_txc;
      let v <- toGet(macTxIn).get;
      Bit#(64) data = v.data;
      if (eop[0] == 1'b1) begin
         xgmii_txd = {idle, idle, terminate, crc32_tx[31:0], data[7:0]};
         xgmii_txc = 8'b11100000;
      end
      if (eop[1] == 1'b1) begin
         xgmii_txd = {idle, terminate, crc32_tx[31:0], data[15:0]};
         xgmii_txc = 8'b11000000;
      end
      if (eop[2] == 1'b1) begin
         xgmii_txd = {terminate, crc32_tx[31:0], data[23:0]};
         xgmii_txc = 8'b10000000;
      end
      if (eop[3] == 1'b1) begin
         xgmii_txd = {crc32_tx[31:0], data[31:0]};
         xgmii_txc = 8'b00000000;
      end
      if (eop[4] == 1'b1) begin
         xgmii_txd = {crc32_tx[23:0], data[39:0]};
         xgmii_txc = 8'b00000000;
      end
      if (eop[5] == 1'b1) begin
         xgmii_txd = {crc32_tx[15:0], data[47:0]};
         xgmii_txc = 8'b00000000;
      end
      if (eop[6] == 1'b1) begin
         xgmii_txd = {crc32_tx[7:0], data[55:0]};
         xgmii_txc = 8'b00000000;
      end
      if (eop[7] == 1'b1) begin
         xgmii_txd = {data[63:0]};
         xgmii_txc = 8'b00000000;
      end

      //FIXME: update ifg deficit
      // If there is not another frame ready to be transmitted, interface
      // will go idle and idle deficit idle count calculation is irrelevant.
      // Set deficit to 0.
      //ifg_deficit <= 3'b0;

      if (eop[2:0] != 3'b0) begin
         // Next state depends on number of IFG bytes to be inserted.
         // Skip idle state if needed.
         //FIXME
         state <= IFG;
      end
      if (eop[7:3] != 5'b0) begin
         state <= TERM;
      end
   endrule

   rule state_term (state == TERM);
      Bit#(8) idle = fromInteger(valueOf(Idle));
      Bit#(8) terminate = fromInteger(valueOf(Terminate));
      Bit#(64) xgmii_txd;
      Bit#(8) xgmii_txc;
      let v <- toGet(macTxIn).get;
      Bit#(64) data = v.data;
      // Insert TERMINATE character in correct lane depending on position
      // of EOP read from fifo. Also insert CRC read from control fifo.
      if (eop[3] == 1'b1) begin
         xgmii_txd = {idle, idle, idle, idle, idle, idle, idle, terminate};
         xgmii_txc = 8'b11111111;
      end
      if (eop[4] == 1'b1) begin
         xgmii_txd = {idle, idle, idle, idle, idle, idle, terminate, crc32_tx[31:24]};
         xgmii_txc = 8'b11111110;
      end
      if (eop[5] == 1'b1) begin
         xgmii_txd = {idle, idle, idle, idle, idle, terminate, crc32_tx[31:16]};
         xgmii_txc = 8'b11111100;
      end
      if (eop[6] == 1'b1) begin
         xgmii_txd = {idle, idle, idle, idle, terminate, crc32_tx[31:8]};
         xgmii_txc = 8'b11111000;
      end
      if (eop[7] == 1'b1) begin
         xgmii_txd = {idle, idle, idle, terminate, crc32_tx[31:0]};
         xgmii_txc = 8'b11110000;
      end

      // Next state depends on number of IFG bytes to be inserted.
      // Skip idle state if needed.
      if (frame_available && !ifg_8b_add) begin
         state <= PREAMBLE;
      end
      else if (frame_available) begin
         state <= IDLE;
      end
      else begin
         state <= IFG;
      end
   endrule

   rule state_term_fail (state == TERM_FAIL);
      Bit#(8) idle = fromInteger(valueOf(Idle));
      Bit#(8) terminate = fromInteger(valueOf(Terminate));
      Bit#(64) xgmii_txd;
      Bit#(8) xgmii_txc;
      xgmii_txd = {idle, idle, idle, idle, idle, idle, idle, terminate};
      xgmii_txc = 8'b11111111;
      state <= IFG;
   endrule

   rule state_ifg (state == IFG);
      state <= IDLE;
   endrule

   // read from data fifo

   rule compute_crc;

   endrule

   interface macTxOut = toPipeOut(macOutFifo);
endmodule

endpackage
