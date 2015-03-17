
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
//import EthPma                        ::*;
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
   interface Vector#(numPorts, Clock) tx_clkout;
   interface Vector#(numPorts, Clock) rx_clkout;
   interface Vector#(numPorts, Bool)  rx_ready;
   interface Vector#(numPorts, Bool)  tx_ready;
endinterface

(* synthesize *)
module mkEthPhy#(Clock mgmt_clk, Clock clk_156_25, Clock clk_644, Reset rst_156_25_n)(EthPhyIfc#(NumPorts));

   //Clock defaultClock <- exposeCurrentClock;
   //Reset defaultReset <- exposeCurrentReset;
   Reset rst_50_n <- mkAsyncReset(2, rst_156_25_n, mgmt_clk);

   Vector#(NumPorts, EthPcs) pcs;
   //EthPma#(NumPorts)         pma4 <- mkEthPma(mgmt_clk, clk_644, rst_50_n);
   EthSonicPma#(NumPorts)      pma4 <- mkEthSonicPma(mgmt_clk, clk_156_25, clk_644, rst_50_n, clocked_by mgmt_clk, reset_by rst_50_n);

   Vector#(NumPorts, Gearbox_40_66) gearboxUp;
   Vector#(NumPorts, Gearbox_66_40) gearboxDn;

   Vector#(NumPorts, FIFOF#(Bit#(72))) txFifo <- replicateM(mkFIFOF(clocked_by clk_156_25, reset_by rst_156_25_n));
   Vector#(NumPorts, FIFOF#(Bit#(72))) rxFifo <- replicateM(mkFIFOF(clocked_by clk_156_25, reset_by rst_156_25_n));
   Vector#(NumPorts, PipeIn#(Bit#(72)))  vRxPipeIn = newVector;
   Vector#(NumPorts, PipeOut#(Bit#(72))) vRxPipeOut = newVector;
   Vector#(NumPorts, PipeIn#(Bit#(72)))  vTxPipeIn = newVector;
   Vector#(NumPorts, PipeOut#(Bit#(72))) vTxPipeOut = newVector;

   for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
      vRxPipeIn[i]  = toPipeIn(rxFifo[i]);
      vRxPipeOut[i] = toPipeOut(rxFifo[i]);
      vTxPipeIn[i]  = toPipeIn(txFifo[i]);
      vTxPipeOut[i] = toPipeOut(txFifo[i]);
   end

   for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
      gearboxUp[i] <- mkGearbox40to66(clk_156_25, clocked_by pma4.rx_clkout[i], reset_by pma4.rx_reset[i]);
      mkConnection(pma4.rx[i], gearboxUp[i].gbIn);

      pcs[i]       <- mkEthPcs(i, clocked_by clk_156_25, reset_by rst_156_25_n);
      mkConnection(vTxPipeOut[i], pcs[i].encoderIn);
      mkConnection(gearboxUp[i].gbOut, pcs[i].bsyncIn);

      gearboxDn[i] <- mkGearbox66to40(clk_156_25, clocked_by pma4.tx_clkout[i], reset_by pma4.tx_reset[i]);
      mkConnection(pcs[i].scramblerOut, gearboxDn[i].gbIn);
      mkConnection(gearboxDn[i].gbOut, pma4.tx[i], clocked_by pma4.tx_clkout[i], reset_by pma4.tx_reset[i]);
   end

   rule receive;
      for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
         let v <- toGet(pcs[i].decoderOut).get;
         vRxPipeIn[i].enq(v);
      end
   endrule

   interface tx_ready = pma4.tx_ready;
   interface rx_ready = pma4.rx_ready;
   interface rx_clkout = pma4.rx_clkout;
   interface tx_clkout = pma4.tx_clkout;
   interface serial = pma4.pmd;
   interface rx = vRxPipeOut;
   interface tx = vTxPipeIn;

endmodule: mkEthPhy
endpackage: EthPhy
