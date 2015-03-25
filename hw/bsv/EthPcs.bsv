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
//import MemTypes::*;

import Ethernet ::*;
import Dtp ::*;
import Encoder ::*;
import Decoder ::*;
import Scrambler ::*;
import Descrambler ::*;
import BlockSync ::*;

(* always_ready, always_enabled *)
interface EthPcs;
   interface PipeIn#(Bit#(72)) encoderIn;
   interface PipeIn#(Bit#(66)) bsyncIn;
   interface PipeOut#(Bit#(72)) decoderOut;
   interface PipeOut#(Bit#(66)) scramblerOut;
   method Action rx_ready(Bool v);
   method Action tx_ready(Bool v);
endinterface

module mkEthPcs#(Integer id)(EthPcs);

   let verbose = False;

   // Debug variable, make sure at most one is enabled.
   let use_dtp    = True;
   let lpbk_enc   = False;
   let lpbk_scm   = False;
   let lpbk_ext   = False;
   let bypass     = False;

   Reg#(Bit#(32)) cycle <- mkReg(0);

   Encoder encoder     <- mkEncoder   ();
   Scrambler scram     <- mkScrambler ();
   Dtp dtp             <- mkDtpTop    ();
   Decoder decoder     <- mkDecoder   ();
   Descrambler descram <- mkDescrambler ();
   BlockSync bsync     <- mkBlockSync ();

   if (use_dtp) begin // use dtp
      // Tx Path
      mkConnection(encoder.encoderOut, dtp.dtpTxIn);
      mkConnection(dtp.dtpTxOut,       scram.scramblerIn);
      // Rx Path
      mkConnection(dtp.dtpRxOut,           decoder.decoderIn);
      mkConnection(descram.descrambledOut, dtp.dtpRxIn);
      mkConnection(bsync.dataOut,          descram.descramblerIn);
   end
   else if (lpbk_enc) begin //local loopback at encoder <-> decoder
      // Loopback
      mkConnection(encoder.encoderOut, decoder.decoderIn);
   end
   else if (lpbk_scm) begin //local loopback at scrambler <-> descrambler
      // Loopback
      mkConnection(encoder.encoderOut,     scram.scramblerIn);
      mkConnection(descram.descrambledOut, decoder.decoderIn);
      mkConnection(bsync.dataOut,          descram.descramblerIn);
   end
   else if (lpbk_ext) begin //external loopback at scrambler <-> descrambler
      // Loopback
      mkConnection(descram.descrambledOut, scram.scramblerIn);
      mkConnection(bsync.dataOut,          descram.descramblerIn);
   end
   else if (bypass) begin // bypass dtp
      mkConnection(encoder.encoderOut,     scram.scramblerIn);
      mkConnection(descram.descrambledOut, decoder.decoderIn);
      mkConnection(bsync.dataOut,          descram.descramblerIn);
   end
   else begin //For testing purpose.
      // scram -> descram loopback
      //mkConnection(scram.scrambledOut,     descram.descramblerIn);
      mkConnection(encoder.encoderOut,     scram.scramblerIn);
      mkConnection(descram.descrambledOut, decoder.decoderIn);
      mkConnection(bsync.dataOut,          descram.descramblerIn);
   end

   rule cyc;
      cycle <= cycle + 1;
   endrule

   method Action tx_ready(Bool v);
      encoder.tx_ready(v);
      scram.tx_ready(v);
      dtp.tx_ready(v);
   endmethod

   method Action rx_ready(Bool v);
      dtp.rx_ready(v);
      decoder.rx_ready(v);
      descram.rx_ready(v);
      bsync.rx_ready(v);
   endmethod

   interface encoderIn    = encoder.encoderIn;
   interface bsyncIn      = bsync.blockSyncIn;
   interface decoderOut   = decoder.decoderOut;
   interface scramblerOut = scram.scrambledOut;
endmodule
endpackage: EthPcs
