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

package EthPcs;

import Clocks ::*;
import Vector ::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;
import Connectable::*;

import Pipe::*;
import MemTypes::*;

import Ethernet ::*;
import Dtp ::*;
import Encoder ::*;
import Decoder ::*;
import Scrambler ::*;
import Descrambler ::*;
import BlockSync ::*;

(* always_ready, always_enabled *)
interface EthPcs;
   interface PipeOut#(Bit#(72)) decoderOut;
   interface PipeOut#(Bit#(66)) scramblerOut;
endinterface

module mkEthPcs#(PipeOut#(Bit#(72)) encoderIn, PipeOut#(Bit#(66)) bsyncIn, Integer id, Integer c_local)(EthPcs);

   let verbose = True;

   // Debug variable, make sure only enable one at a time.
   let use_dtp     = False;
   let lpbk_enc   = False;
   let lpbk_scram = True;

   Reg#(Bit#(32)) cycle <- mkReg(0);
   // Tx Path
   FIFOF#(Bit#(72)) txEncoderInFifo <- mkBypassFIFOF;
   FIFOF#(Bit#(66)) txDtpInFifo     <- mkBypassFIFOF;
   FIFOF#(Bit#(66)) txScramInFifo   <- mkBypassFIFOF;
   PipeIn#(Bit#(66)) txDtpPipeIn = toPipeIn(txDtpInFifo);
   PipeIn#(Bit#(66)) txScramPipeIn = toPipeIn(txScramInFifo);
   // Rx Path
   FIFOF#(Bit#(72)) rxDecoderOutFifo <- mkBypassFIFOF;
   FIFOF#(Bit#(66)) rxDtpOutFifo     <- mkBypassFIFOF;
   FIFOF#(Bit#(66)) rxDescramOutFifo <- mkBypassFIFOF;
   FIFOF#(Bit#(66)) rxDescramInFifo  <- mkBypassFIFOF;
   FIFOF#(Bit#(66)) rxBlockSyncInFifo  <- mkBypassFIFOF;
   PipeIn#(Bit#(66)) rxDtpPipeIn = toPipeIn(rxDescramOutFifo);
   PipeIn#(Bit#(66)) rxDecoderPipeIn = toPipeIn(rxDtpOutFifo);
   PipeIn#(Bit#(66)) rxDescramblePipeIn = toPipeIn(rxDescramInFifo);
   PipeIn#(Bit#(66)) rxBlockSyncPipeIn = toPipeIn(rxBlockSyncInFifo);

   Encoder encoder <- mkEncoder(encoderIn);
   Scrambler scram <- mkScrambler(toPipeOut(txScramInFifo));
   Dtp dtp <- mkDtp(toPipeOut(rxDescramOutFifo), toPipeOut(txDtpInFifo), id, c_local);
   Decoder decoder <- mkDecoder(toPipeOut(rxDtpOutFifo));
   Descrambler descram <- mkDescrambler(toPipeOut(rxDescramInFifo));
   BlockSync bsync <- mkBlockSync(toPipeOut(rxBlockSyncInFifo));

//   if (use_dtp) begin // use dtp
//      mkConnection(encoder.encoderOut, txDtpPipeIn);
//      mkConnection(dtp.encoderOut, txScramPipeIn);
//      mkConnection(descram.descrambledOut, rxDtpPipeIn);
//      mkConnection(dtp.decoderOut, rxDecoderPipeIn);
//      mkConnection(bsync.dataOut, rxDescramblePipeIn);
//      mkConnection(bsyncIn, rxBlockSyncPipeIn);
//   end
//   else if (lpbk_enc) begin //local loopback at encoder <-> decoder
//      mkConnection(encoder.encoderOut, rxDecoderPipeIn);
//   end
//   else if (lpbk_scram) begin //local loopback at scrambler <-> descrambler
      mkConnection(encoder.encoderOut, txScramPipeIn);
      mkConnection(descram.descrambledOut, rxDecoderPipeIn);
      mkConnection(bsync.dataOut, rxDescramblePipeIn);
      mkConnection(bsyncIn, rxBlockSyncPipeIn);
//   end
//   else begin // bypass dtp
//      mkConnection(encoder.encoderOut, txScramPipeIn);
//      mkConnection(descram.descrambledOut, rxDecoderPipeIn);
//      mkConnection(bsync.dataOut, rxDescramblePipeIn);
//      mkConnection(bsyncIn, rxBlockSyncPipeIn);
//   end

   rule bsync_output;
      let v = rxBlockSyncInFifo.first;
      if(verbose) $display("%d: pcs, blocksync input=%h", cycle, v);
   endrule

   rule cyc;
      cycle <= cycle + 1;
   endrule

   interface decoderOut = decoder.decoderOut;
   interface scramblerOut = scram.scrambledOut;
endmodule
endpackage: EthPcs
