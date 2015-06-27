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

package EthPcsRx;

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

import Ethernet ::*;
import Decoder ::*;
import Descrambler ::*;
import BlockSync ::*;

interface EthPcsRx;
   interface PipeIn#(Bit#(66)) bsyncIn;
   interface PipeOut#(Bit#(72)) decoderOut;
   interface PipeOut#(Bit#(66)) dtpRxIn;
   interface PipeIn#(Bit#(66))  dtpRxOut;
   (* always_ready, always_enabled *)
   method Action rx_ready(Bool v);
   (* always_ready, always_enabled *)
   method Bool lock();
endinterface

(* synthesize *)
module mkEthPcsRxTop(EthPcsRx);
   EthPcsRx _a <- mkEthPcsRx(0);
   return _a;
endmodule

module mkEthPcsRx#(Integer id)(EthPcsRx);

   let verbose = False;
   let bypass_dtp = False;

   Reg#(Bit#(32)) cycle <- mkReg(0);
   FIFOF#(Bit#(66)) dtpRxInFifo <- mkFIFOF;
   FIFOF#(Bit#(66)) dtpRxOutFifo <- mkFIFOF;
   PipeIn#(Bit#(66)) dtpRxInPipeIn = toPipeIn(dtpRxInFifo);
   PipeOut#(Bit#(66)) dtpRxOutPipeOut = toPipeOut(dtpRxOutFifo);

   Decoder decoder     <- mkDecoder();
   Descrambler descram <- mkDescrambler();
   BlockSync bsync     <- mkBlockSync();

   if (!bypass_dtp) begin
      mkConnection(dtpRxOutPipeOut, decoder.decoderIn);
      mkConnection(descram.descrambledOut, dtpRxInPipeIn);
      mkConnection(bsync.dataOut,  descram.descramblerIn);
   end
   else begin
      mkConnection(descram.descrambledOut, decoder.decoderIn);
      mkConnection(bsync.dataOut, descram.descramblerIn);
   end

   rule cyc;
      cycle <= cycle + 1;
   endrule

   method Action rx_ready(Bool v);
      decoder.rx_ready(v);
      descram.rx_ready(v);
      bsync.rx_ready(v);
   endmethod

   interface bsyncIn      = bsync.blockSyncIn;
   interface decoderOut   = decoder.decoderOut;
   interface dtpRxIn      = toPipeOut(dtpRxInFifo);
   interface dtpRxOut     = toPipeIn(dtpRxOutFifo);
   interface lock         = bsync.lock;
endmodule
endpackage: EthPcsRx
