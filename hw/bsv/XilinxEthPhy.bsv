
// Copyright (c) 2015 Cornell University.

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

package XilinxEthPhy;

import Clocks::*;
import Vector::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Connectable::*;
import GetPut::*;
import Pipe::*;
import XilinxPhyWrap::*; 

interface EthPhyIfc;
   (*always_ready, always_enabled*)
   interface Put#(Bit#(72))  tx;
   (*always_ready, always_enabled*)
   interface Get#(Bit#(72)) rx;
   (*always_ready, always_enabled*)
   method Bit#(1) serial_tx;
   (*always_ready, always_enabled*)
   method Action serial_rx(Bit#(1) v);
   interface Clock rx_clkout;
endinterface

(* synthesize *)
module mkXilinxEthPhy#(Clock clk_50, Clock clk_156_25, Reset rst_50)(EthPhyIfc#(numPorts));

   FIFOF#(Bit#(72)) txFifo <- mkUGFIFOF(clocked_by clk_156_25, reset_by noReset);

   PhyWrap phy <- mkPhyWrap();

   FIFOF#(Bit#(72)) rxFifo <- mkUGFIFOF(clocked_by phy.rxrecclk, reset_by noReset);

   rule tx_mac;
      let v <- toGet(txFifo).get;
      phy.xgmii.txd(v[71:8]);
      phy.xgmii.txc(v[7:0]);
   endrule

   rule rx_mac;
      rxFifo.enq({phy.xgmii.rxd, phy.xgmii.rxc});
   endrule

   Wire#(Bit#(1)) tx_serial <- mkDWire(0);
   Wire#(Bit#(1)) rx_serial <- mkDWire(0);

   rule tx_serial;
      //tx_serial <= phy.tx_serial.
      //txn
      //txp
   endrule

   rule rx_serial;
      //rxn
      //rxp
   endrule

   interface tx = toPut(txFifo);
   interface rx = toGet(rxFifo);
   // txserial
   // rxserial
   // rxclockout
endmodule
endpackage
