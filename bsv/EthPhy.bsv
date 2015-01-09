
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

import Ethernet                      ::*;
import EthPma                        ::*;

import ALTERA_ETH_PORT_WRAPPER       ::*;
import ALTERA_SI570_WRAPPER          ::*;
import ALTERA_EDGE_DETECTOR_WRAPPER  ::*;
import DTP_GLOBAL_TIMESTAMP_WRAPPER  ::*;

`ifdef USE_4_CHANNELS
typedef 4 N_CHAN;
`elsif USE_2_CHANNELS
typedef 2 N_CHAN;
`endif

interface EthPhyIfc#(numeric type np);
   interface Xgmii#(np) xgmii;
   interface Pma#(np)   pma;
endinterface

(* synthesize *)
module mkEthPhy(EthPhyIfc#(N_CHAN));

Clock clk_50     <- exposeCurrentClock;
Reset rst_50     <- exposeCurrentReset;
Clock clk_156_25 <- exposeCurrentClock;
Reset rst_156_25 <- exposeCurrentReset;

Vector#(4, EthPortWrap) pcs4 <- replicateM(mkEthPortWrap(clk_156_25, rst_156_25, rst_156_25));
EthPmaIfc#(4)           pma4 <- mkEthPma(clk_50, clk_156_25, rst_50, rst_156_25);

Si570Wrap               si570 <- mkSi570Wrap(clk_50, rst_50, rst_50);
EdgeDetectorWrap        edgedetect <- mkEdgeDetectorWrap(clk_50, rst_50, rst_50);
DtpGlobalWrap           dtpg <- mkDtpGlobalWrap(clk_156_25, rst_156_25, rst_156_25);

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

//pcs.ctrl
//pcs.log
//pcs.lpbk
//pcs.timeout

rule cntrs;
   for (Integer i=0; i < valueOf(N_CHAN); i=i+1) begin
      pcs4[i].cntr.global_state(dtpg.timestamp.maximum);
   end
   dtpg.timestamp.p0(pcs4[0].cntr.local_state);
   dtpg.timestamp.p1(pcs4[1].cntr.local_state);
   dtpg.timestamp.p2(pcs4[2].cntr.local_state);
   dtpg.timestamp.p3(pcs4[3].cntr.local_state);
endrule

rule pcs_pma;
   Vector#(N_CHAN, Bit#(40)) tx_dataout;
   for (Integer i=0; i < valueOf(N_CHAN); i=i+1) begin
      pcs4[i].xcvr.rx_datain(pma4.parallel.rx_parallel_data[i]);
      pcs4[i].xcvr.rx_clkout(pma4.parallel.rx_clkout[i]);
      pcs4[i].xcvr.tx_clkout(pma4.parallel.tx_clkout[i]);
      pcs4[i].xcvr.tx_ready(pma4.parallel.tx_ready[i]);
      pcs4[i].xcvr.rx_ready(pma4.parallel.rx_ready[i]);
      tx_dataout[i] = pcs4[i].xcvr.tx_dataout;
   end
   pma4.parallel.tx_parallel_data(tx_dataout);
endrule

interface Pma pma;
   method Action serial_rxin(Bit#(N_CHAN) v);
      pma4.serial.rx_serial_data(v);
   endmethod

   method Bit#(N_CHAN) serial_txout;
      return pma4.serial.tx_serial_data;
   endmethod
endinterface

interface Xgmii xgmii;
   method Vector#(N_CHAN, Bit#(72)) rx_dc;
      Vector#(N_CHAN, Bit#(72)) ret_val;
      for (Integer i=0; i<valueOf(N_CHAN); i=i+1) begin
         ret_val[i] = pcs4[i].xgmii.rx_data;
      end
      return ret_val;
   endmethod

   method Action tx_dc (Vector#(N_CHAN, Bit#(72)) v);
      for (Integer i=0; i<valueOf(N_CHAN); i=i+1) begin
         pcs4[i].xgmii.tx_data(v[i]);
      end
   endmethod
endinterface

endmodule: mkEthPhy
endpackage: EthPhy
