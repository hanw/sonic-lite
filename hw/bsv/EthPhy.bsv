
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

import Ethernet                      ::*;
import EthPma                        ::*;
import EthPcs                        ::*;
import ALTERA_SI570_WRAPPER          ::*;
import ALTERA_EDGE_DETECTOR_WRAPPER  ::*;

`ifdef USE_4_CHANNELS
typedef 4 N_CHAN;
`elsif USE_2_CHANNELS
typedef 2 N_CHAN;
`endif

(* always_ready, always_enabled *)
interface EthPhyIfc#(numeric type np);
   interface Vector#(np, XGMII_PCS) xgmii;
   interface Vector#(np, SerialIfc) serial;
endinterface


(* synthesize *)
module mkEthPhy#(Clock clk_50, Reset rst_50, Clock clk_156_25, Reset rst_156_25, Clock clk_644)(EthPhyIfc#(N_CHAN));

   Clock defaultClock <- exposeCurrentClock;
   Reset defaultReset <- exposeCurrentReset;

   EthPcsIfc#(N_CHAN)   pcs4 <- mkEthPcs(clk_156_25, rst_156_25);
   EthPmaIfc#(N_CHAN)   pma4 <- mkEthPma(clk_50, clk_644, rst_50);

   Si570Wrap            si570 <- mkSi570Wrap(clk_50, rst_50, rst_50);
   EdgeDetectorWrap     edgedetect <- mkEdgeDetectorWrap(clk_50, rst_50, rst_50);

   rule si570_connections;
      //ifreq_mode = 3'b000;  //100.0 MHZ
      //ifreq_mode = 3'b001;  //125.0 MHZ
      //ifreq_mode = 3'b010;  //156.25.0 MHZ
      //ifreq_mode = 3'b011;  //250 MHZ
      //ifreq_mode = 3'b100;  //312.5 MHZ
      //ifreq_mode = 3'b101;  //322.26 MHZ
      //ifreq_mode = 3'b110;  //644.53125 MHZ
      si570.ifreq.mode(3'b110); //644.53125 MHZ
      si570.istart.go(edgedetect.odebounce.out);
   endrule

   for (Integer i=0; i< valueOf(N_CHAN); i=i+1) begin
      mkConnection(pma4.fpga[i], pcs4.xcvr[i]);
   end

   //pcs.ctrl
   //pcs.log
   //pcs.lpbk
   //pcs.timeout

   interface serial = pma4.fiber;
   interface xgmii = pcs4.xgmii;

endmodule: mkEthPhy
endpackage: EthPhy
