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

package EthPcsTx;

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
import Encoder ::*;
import Scrambler ::*;

interface EthPcsTx;
   interface PipeIn#(Bit#(72)) encoderIn;
   interface PipeOut#(Bit#(66)) scramblerOut;
   interface PipeOut#(Bit#(66)) dtpTxIn;
   interface PipeIn#(Bit#(66)) dtpTxOut;
   (* always_ready, always_enabled *)
   method Action tx_ready(Bool v);
   method PcsDbgRec dbg;
endinterface

(* synthesize *)
module mkEthPcsTxTop(EthPcsTx);
   EthPcsTx _a <- mkEthPcsTx(0);
   return _a;
endmodule

module mkEthPcsTx#(Integer id)(EthPcsTx);

   let verbose = False;
   let bypass_dtp = False;

   Reg#(Bit#(32)) cycle <- mkReg(0);
   FIFOF#(Bit#(66)) dtpTxInFifo <- mkFIFOF();
   FIFOF#(Bit#(66)) dtpTxOutFifo <- mkFIFOF();
   PipeIn#(Bit#(66)) dtpTxInPipeIn = toPipeIn(dtpTxInFifo);
   PipeOut#(Bit#(66)) dtpTxOutPipeOut = toPipeOut(dtpTxOutFifo);

   Encoder encoder     <- mkEncoder   ();
   Scrambler scram     <- mkScrambler ();

   if (!bypass_dtp) begin
      mkConnection(encoder.encoderOut, dtpTxInPipeIn);
      mkConnection(dtpTxOutPipeOut, scram.scramblerIn);
   end
   else begin
      mkConnection(encoder.encoderOut, scram.scramblerIn);
   end

   rule cyc;
      cycle <= cycle + 1;
   endrule

   method Action tx_ready(Bool v);
      encoder.tx_ready(v);
      scram.tx_ready(v);
   endmethod

   interface encoderIn    = encoder.encoderIn;
   interface scramblerOut = scram.scrambledOut;
   interface dtpTxIn      = toPipeOut(dtpTxInFifo);
   interface dtpTxOut     = toPipeIn(dtpTxOutFifo);
   method PcsDbgRec dbg = encoder.dbg;
endmodule
endpackage: EthPcsTx
