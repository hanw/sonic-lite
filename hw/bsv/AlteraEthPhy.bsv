
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

package AlteraEthPhy;

import Clocks::*;
import Vector::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Connectable::*;
import GetPut::*;
import Pipe::*;

import ALTERA_ETH_10GBASER_WRAPPER::*;

`ifdef NUMBER_OF_10G_PORTS
typedef `NUMBER_OF_10G_PORTS NumPorts;
`else
typedef 4 NumPorts;
`endif

interface SerialIfc;
   method Bit#(NumPorts) tx;
   method Action rx(Bit#(NumPorts) v);
endinterface

interface EthPhyIfc;
   interface Vector#(NumPorts, PipeIn#(Bit#(72)))  tx;
   interface Vector#(NumPorts, PipeOut#(Bit#(72))) rx;
   (*always_ready, always_enabled*)
   interface SerialIfc serial;
   interface Clock rx_clkout;
endinterface

(* synthesize *)
module mkAlteraEthPhy#(Clock clk_50, Clock clk_644, Clock clk_xgmii, Reset rst_50)(EthPhyIfc);
   Vector#(NumPorts, FIFOF#(Bit#(72))) txFifo = newVector;
   Vector#(NumPorts, FIFOF#(Bit#(72))) rxFifo = newVector;
   Clock defaultClock <- exposeCurrentClock;
   Reset defaultReset <- exposeCurrentReset;

   Eth10GPhyWrap phy <- mkEth10GPhyWrap(clk_50, clk_644, clk_xgmii, rst_50);
   Reset xgmii_reset <- mkAsyncReset(2, defaultReset, phy.xgmii_rx_clk);

   for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
      txFifo[i] <- mkBypassFIFOF(clocked_by clk_xgmii, reset_by noReset);
      rule tx_mac;
         let v <- toGet(txFifo[i]).get;
         case (i)
           0: phy.xgmii_tx.dc_0(v);
           1: phy.xgmii_tx.dc_1(v);
           2: phy.xgmii_tx.dc_2(v);
           3: phy.xgmii_tx.dc_3(v);
         endcase
      endrule
   end

   for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
      rxFifo[i] <- mkBypassFIFOF(clocked_by phy.xgmii_rx_clk, reset_by noReset);
      rule rx_mac;
         case(i)
            0: rxFifo[0].enq(phy.xgmii_rx.dc_0);
            1: rxFifo[1].enq(phy.xgmii_rx.dc_1);
            2: rxFifo[2].enq(phy.xgmii_rx.dc_2);
            3: rxFifo[3].enq(phy.xgmii_rx.dc_3);
         endcase
      endrule
   end

   Vector#(NumPorts, Wire#(Bit#(1))) tx_serial <- replicateM(mkDWire(0));
   rule tx_serial0;
      tx_serial[0] <= phy.tx_serial.data_0;
   endrule
   rule tx_serial1;
      tx_serial[1] <= phy.tx_serial.data_1;
   endrule
   rule tx_serial2;
      tx_serial[2] <= phy.tx_serial.data_2;
   endrule
   rule tx_serial3;
      tx_serial[3] <= phy.tx_serial.data_3;
   endrule

   Vector#(NumPorts, Wire#(Bit#(1))) rx_serial_wire <- replicateM(mkDWire(0));

   rule rx_serial0;
      phy.rx_serial.data_0(rx_serial_wire[0]);
   endrule
   rule rx_serial1;
      phy.rx_serial.data_1(rx_serial_wire[1]);
   endrule
   rule rx_serial2;
      phy.rx_serial.data_2(rx_serial_wire[2]);
   endrule
   rule rx_serial3;
      phy.rx_serial.data_3(rx_serial_wire[3]);
   endrule

   interface tx = map(toPipeIn, txFifo);
   interface rx = map(toPipeOut, rxFifo);
   interface SerialIfc serial;
      method tx = pack(readVReg(tx_serial));
      method Action rx (Bit#(NumPorts) v);
         writeVReg(rx_serial_wire, unpack(v));
      endmethod
   endinterface
   interface rx_clkout = phy.xgmii_rx_clk;
endmodule

endpackage
