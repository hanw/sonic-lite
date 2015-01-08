
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

package Ethernet;

import Clocks                        ::*;
import Vector                        ::*;

import EthPma                        ::*;

import ALTERA_ETH_PORT_WRAPPER       ::*;

`ifdef USE_4_PORTS
typedef 4 PortNum;
`elsif USE_2_PORTS
typedef 2 PortNum;
`endif

interface Xgmii#(numeric type np);
   method Vector#(np, Bit#(72)) rx_dc;
   method Action tx_dc (Vector#(np, Bit#(72)) v);
endinterface

interface Pma#(numeric type np);
   method Action serial_rxin(Bit#(np) v);
   method Bit#(np) serial_txout;
endinterface

interface EthPhyIfc#(numeric type np);
   interface Xgmii#(np) xgmii;
   interface Pma#(np)   pma;
endinterface

(* synthesize *)
module mkEthernet(EthPhyIfc#(PortNum));

Clock clk_50     <- exposeCurrentClock;
Reset rst_50     <- exposeCurrentReset;
Clock clk_156_25 <- exposeCurrentClock;
Reset rst_156_25 <- exposeCurrentReset;

Vector#(4, EthPortWrap) pcs4 <- replicateM(mkEthPortWrap(clk_156_25, rst_156_25, rst_156_25));
EthPmaIfc#(4)           pma4 <- mkEthPma(clk_50, clk_156_25, rst_50, rst_156_25);

//pcs.cntr
//pcs.ctrl
//pcs.log
//pcs.lpbk
//pcs.timeout

rule pcs_pma;
   Vector#(PortNum, Bit#(40)) tx_dataout;
   for (Integer i=0; i < valueOf(PortNum); i=i+1) begin
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
   method Action serial_rxin(Bit#(PortNum) v);
      pma4.serial.rx_serial_data(v);
   endmethod

   method Bit#(PortNum) serial_txout;
      return pma4.serial.tx_serial_data;
   endmethod
endinterface

interface Xgmii xgmii;
   method Vector#(PortNum, Bit#(72)) rx_dc;
      Vector#(PortNum, Bit#(72)) ret_val;
      for (Integer i=0; i<valueOf(PortNum); i=i+1) begin
         ret_val[i] = pcs4[i].xgmii.rx_data;
      end
      return ret_val;
   endmethod

   method Action tx_dc (Vector#(PortNum, Bit#(72)) v);
      for (Integer i=0; i<valueOf(PortNum); i=i+1) begin
         pcs4[i].xgmii.tx_data(v[i]);
      end
   endmethod
endinterface

endmodule: mkEthernet
endpackage: Ethernet
