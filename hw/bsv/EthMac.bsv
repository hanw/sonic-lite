
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

package EthMac;

import Clocks::*;
import Vector::*;
import Connectable                   ::*;
import Pipe                          ::*;
import FIFOF                         ::*;
import GetPut                        ::*;
import Pipe::*;

import Ethernet::*;

// 4-port 10GbE MAC Qsys wrapper
import ALTERA_MAC_WRAPPER::*;

`ifdef NUMBER_OF_10G_PORTS
typedef `NUMBER_OF_10G_PORTS NumPorts;
`else
typedef 4 NumPorts;
`endif

//(* always_ready, always_enabled *)
interface EthMacIfc;
   interface Vector#(NumPorts, PipeOut#(Bit#(72))) tx;
   interface Vector#(NumPorts, PipeIn#(Bit#(72))) rx;
endinterface

(* synthesize *)
module mkEthMac#(Clock clk_50, Clock clk_156_25, Vector#(4, Clock) rx_clk, Reset rst_156_25_n)(EthMacIfc);
    Vector#(NumPorts, FIFOF#(Bit#(72))) txFifo = newVector;
    Vector#(NumPorts, FIFOF#(Bit#(72))) rxFifo = newVector;
    Vector#(NumPorts, Reset) rx_rst = newVector;
    Clock defaultClock <- exposeCurrentClock;
    Reset defaultReset <- exposeCurrentReset;

    for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
       rx_rst[i] <- mkAsyncReset(2, rst_156_25_n, rx_clk[i]);
    end
    Reset rst_50_n <- mkAsyncReset(2, defaultReset, clk_50);
    MacWrap mac <- mkMacWrap(clk_50, clk_156_25, rx_clk, rx_rst, rst_50_n, rst_156_25_n, clocked_by clk_156_25, reset_by rst_156_25_n);

    for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
       txFifo[i] <- mkFIFOF(clocked_by clk_156_25, reset_by rst_156_25_n);
       rxFifo[i] <- mkFIFOF(clocked_by rx_clk[i], reset_by rx_rst[i]);

       rule receive;
          let v <- toGet(rxFifo[i]).get;
          case(i)
             0: mac.p0_xgmii.rx_data(v);
             1: mac.p1_xgmii.rx_data(v);
             2: mac.p2_xgmii.rx_data(v);
             3: mac.p3_xgmii.rx_data(v);
          endcase
       endrule
    end

    for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
       rule transmit;
          case(i)
             0: txFifo[0].enq(mac.p0_xgmii.tx_data);
             1: txFifo[1].enq(mac.p1_xgmii.tx_data);
             2: txFifo[2].enq(mac.p2_xgmii.tx_data);
             3: txFifo[3].enq(mac.p3_xgmii.tx_data);
          endcase
       endrule
    end

    interface tx = map(toPipeOut, txFifo);
    interface rx = map(toPipeIn, rxFifo);
endmodule

endpackage: EthMac
