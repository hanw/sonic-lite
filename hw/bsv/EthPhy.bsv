
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

package EthPhy;

import Clocks                        ::*;
import Vector                        ::*;
import Connectable                   ::*;
import Pipe                          ::*;
import FIFOF                         ::*;
import GetPut                        ::*;
import Ethernet                      ::*;
import EthPma                        ::*;
import EthSonicPma                   ::*;
import EthPcs                        ::*;
import Gearbox_40_66                 ::*;
import Gearbox_66_40                 ::*;
import ALTERA_SI570_WRAPPER          ::*;
import ALTERA_EDGE_DETECTOR_WRAPPER  ::*;

`ifdef NUMBER_OF_10G_PORTS
typedef `NUMBER_OF_10G_PORTS NumPorts;
`else
typedef 4 NumPorts;
`endif

interface EthPhyIfc#(numeric type numPorts);
   interface Vector#(numPorts, PipeOut#(Bit#(72))) rx;
   interface Vector#(numPorts, PipeIn#(Bit#(72)))  tx;
   (* always_ready, always_enabled *)
   interface Vector#(numPorts, SerialIfc) serial;
endinterface

(* synthesize *)
module mkEthPhy#(Clock mgmt_clk, Clock clk_156_25, Clock clk_644)(EthPhyIfc#(NumPorts));

   Clock defaultClock <- exposeCurrentClock;
   Reset defaultReset <- exposeCurrentReset;

   Vector#(NumPorts, EthPcs) pcs;
   //EthPma#(NumPorts)         pma4 <- mkEthPma(mgmt_clk, clk_644, defaultReset);
   EthSonicPma#(NumPorts)      pma4 <- mkEthSonicPma(mgmt_clk, clk_644, defaultReset);

   Vector#(NumPorts, Gearbox_40_66) gearboxUp;
   Vector#(NumPorts, Gearbox_66_40) gearboxDn;

   Vector#(NumPorts, FIFOF#(Bit#(72))) txFifo <- replicateM(mkFIFOF());
   Vector#(NumPorts, FIFOF#(Bit#(72))) rxFifo <- replicateM(mkFIFOF());
   Vector#(NumPorts, PipeOut#(Bit#(72))) vRxPipe = newVector;
   Vector#(NumPorts, PipeIn#(Bit#(72)))  vTxPipe = newVector;

   for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
      gearboxUp[i] <- mkGearbox40to66(pma4.rx[i]);
      pcs[i]       <- mkEthPcs(toPipeOut(txFifo[i]), gearboxUp[i].gbOut, 0, 0);
      gearboxDn[i] <- mkGearbox66to40(pcs[i].scramblerOut);
   end

   for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
      vRxPipe[i] = toPipeOut(rxFifo[i]);
      vTxPipe[i] = toPipeIn(txFifo[i]);
   end

   rule receive (True);
      for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
         let v <- toGet(pcs[i].decoderOut).get;
         rxFifo[i].enq(v);
      end
   endrule

   interface serial = pma4.pmd;
   interface rx = vRxPipe;
   interface tx = vTxPipe;

endmodule: mkEthPhy
endpackage: EthPhy
