
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
import FIFO                          ::*;
import BRAMFIFO                      ::*;
import FIFOF                         ::*;
import SpecialFIFOs                  ::*;
import GetPut                        ::*;
import Ethernet                      ::*;
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
   interface Vector#(numPorts, PipeIn#(Bit#(72)))  tx;
   interface Vector#(numPorts, PipeOut#(Bit#(72))) rx;
   (* always_ready, always_enabled *)
   interface Vector#(numPorts, SerialIfc) serial;
   interface Vector#(numPorts, Clock) tx_clkout;
   interface Vector#(numPorts, Clock) rx_clkout;
   interface LoopbackIfc loopback;
endinterface

function Bit#(n) reverseBits(Bit#(n) x);
   Vector#(n, Bit#(1)) vx = unpack(x);
   Vector#(n, Bit#(1)) rvx = Vector::reverse(vx);
   Bit#(n) prvx = pack(rvx);
   return(prvx);
endfunction

(* synthesize *)
module mkEthPhy#(Clock mgmt_clk, Clock clk_156_25, Clock clk_644, Reset rst_156_25_n)(EthPhyIfc#(NumPorts));

   Reg#(Bit#(32)) cycle <- mkReg(0);
   //Clock defaultClock <- exposeCurrentClock;
   //Reset defaultReset <- exposeCurrentReset;
   Reset rst_50_n <- mkAsyncReset(2, rst_156_25_n, mgmt_clk);

   Reg#(Bool) loopback_en <- mkReg(False);

   Vector#(NumPorts, EthPcs) pcs;
   //EthPma#(NumPorts)         pma4 <- mkEthPma(mgmt_clk, clk_644, rst_50_n);
   EthSonicPma#(NumPorts)      pma4 <- mkEthSonicPma(mgmt_clk, clk_644, rst_50_n, clocked_by mgmt_clk, reset_by rst_50_n);

   let tx_xcvr_reset_n <- mkResetSync(2, True, clk_156_25, clocked_by clk_156_25, reset_by rst_156_25_n);
   let rx_xcvr_reset_n <- mkResetSync(2, True, clk_156_25, clocked_by clk_156_25, reset_by rst_156_25_n);

   ReadOnly#(Bool) rx_ready_cross;
   ReadOnly#(Bool) tx_ready_cross;
   rx_ready_cross <- mkNullCrossingWire(clk_156_25, pma4.rx_ready);
   tx_ready_cross <- mkNullCrossingWire(clk_156_25, pma4.tx_ready);
   rule tx_pma_assert_reset;
      if (!tx_ready_cross) begin
         tx_xcvr_reset_n.assertReset();
      end
   endrule
   rule rx_pma_assert_reset;
      if (!rx_ready_cross) begin
         rx_xcvr_reset_n.assertReset();
      end
   endrule
   Reset tx_xcvr_reset_156_n <- mkSyncReset(2, tx_xcvr_reset_n.new_rst, clk_156_25);
   Reset rx_xcvr_reset_156_n <- mkSyncReset(2, rx_xcvr_reset_n.new_rst, clk_156_25);
   Reset tx_pcs_reset_n <- mkResetEither(tx_xcvr_reset_156_n, rst_156_25_n, clocked_by clk_156_25);
   Reset rx_pcs_reset_n <- mkResetEither(rx_xcvr_reset_156_n, rst_156_25_n, clocked_by clk_156_25);

   Vector#(NumPorts, Gearbox_40_66) gearboxUp;
   Vector#(NumPorts, Gearbox_66_40) gearboxDn;

   Vector#(NumPorts, FIFOF#(Bit#(72))) txFifo <- replicateM(mkFIFOF(clocked_by clk_156_25, reset_by tx_pcs_reset_n));//rst_156_25_n));
   Vector#(NumPorts, FIFOF#(Bit#(72))) rxFifo <- replicateM(mkFIFOF(clocked_by clk_156_25, reset_by rx_pcs_reset_n));//rst_156_25_n));
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

   //Vector#(NumPorts, SyncFIFOIfc#(Bit#(66))) txSynchronizer = newVector;
   //Vector#(NumPorts, SyncFIFOIfc#(Bit#(66))) rxSynchronizer = newVector;
   //Vector#(NumPorts, PipeOut#(Bit#(66)))     txSyncPipeOut  = newVector;
   //Vector#(NumPorts, PipeIn#(Bit#(66)))      txSyncPipeIn   = newVector;
   //Vector#(NumPorts, PipeOut#(Bit#(66)))     rxSyncPipeOut  = newVector;
   //Vector#(NumPorts, PipeIn#(Bit#(66)))      rxSyncPipeIn   = newVector;

   // Loopback FIFO
   Vector#(NumPorts, SyncFIFOIfc#(Bit#(40))) lpbkSyncFIfo = newVector;
   Vector#(NumPorts, PipeOut#(Bit#(40))) lpbkSyncPipeOut = newVector;
   Vector#(NumPorts, PipeIn#(Bit#(40))) lpbkSyncPipeIn = newVector;

   for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
      // Gearbox Level Loopback FIFO
      lpbkSyncFIfo[i] <- mkSyncBRAMFIFO(10, pma4.tx_clkout[i], pma4.tx_reset[i], pma4.rx_clkout[i], pma4.rx_reset[i]);
      lpbkSyncPipeOut[i] = toPipeOut(lpbkSyncFIfo[i]);
      lpbkSyncPipeIn[i] = toPipeIn(lpbkSyncFIfo[i]);

      // Gearbox Upstream
      gearboxUp[i] <- mkGearbox40to66(clk_156_25, clocked_by pma4.rx_clkout[i], reset_by pma4.rx_reset[i]);
      // Gearbox Downstream
      gearboxDn[i] <- mkGearbox66to40(clk_156_25, clocked_by pma4.tx_clkout[i], reset_by pma4.tx_reset[i]);
      // PCS
      pcs[i]       <- mkEthPcs(i, rx_pcs_reset_n, tx_pcs_reset_n, clocked_by clk_156_25, reset_by rst_156_25_n);

      // Rx Path: Gearbox 40/66 -> Blocksync
      mkConnection(gearboxUp[i].gbOut, pcs[i].bsyncIn);

      // Tx Path: Mac -> Encoder
      mkConnection(vTxPipeOut[i], pcs[i].encoderIn);
      // Tx Path: Scrambler -> Gearbox 66/40
      mkConnection(pcs[i].scramblerOut, gearboxDn[i].gbIn);

      // Loopback Enable Signal
      ReadOnly#(Bool) rx_lpbk_en <- mkNullCrossingWire(pma4.rx_clkout[i], loopback_en);
      ReadOnly#(Bool) tx_lpbk_en <- mkNullCrossingWire(pma4.tx_clkout[i], loopback_en);

      // Normal Operation: XCVR -> Gearbox
      rule rx_no_loopback(!rx_lpbk_en);
         let v <- toGet(pma4.rx[i]).get;
         let reversed_v = reverseBits(v);
         gearboxUp[i].gbIn.enq(reversed_v);
      endrule
      rule tx_no_loopback(!tx_lpbk_en);
         //mkConnection(gearboxDn[i].gbOut, pma4.tx[i], clocked_by pma4.tx_clkout[i], reset_by pma4.tx_reset[i]);
         let v <- toGet(gearboxDn[i].gbOut).get;
         let reversed_v = reverseBits(v);
         pma4.tx[i].enq(reversed_v);
      endrule

      ReadOnly#(Bit#(32)) cycle_cross <- mkNullCrossingWire(pma4.tx_clkout[i], cycle);
      // Loopback Operation: Gearbox 66/40 -> lpbk Fifo -> Gearbox 40/66
      rule tx_loopback(tx_lpbk_en);
         //mkConnection(gearboxDn[i].gbOut, lpbkSyncPipeIn[i]);
         let v <- toGet(gearboxDn[i].gbOut).get;
         lpbkSyncPipeIn[i].enq(v);
         // Make sure PMA is up by sending fake data.
         Bit#(40) count = {8'hA1, cycle_cross};
         pma4.tx[i].enq(count);
      endrule
      rule rx_loopback(rx_lpbk_en);
         //mkConnection(lpbkSyncPipeOut[i], gearboxUp[i].gbIn);
         let v <- toGet(lpbkSyncPipeOut[i]).get;
         gearboxUp[i].gbIn.enq(v);
      endrule

      // Use these code to move syncFifo out of Gearbox
      //rxSynchronizer[i] <- mkSyncBRAMFIFO(10, pma4.rx_clkout[i], pma4.rx_reset[i], clk_156_25, rst_156_25_n);
      //rxSyncPipeOut[i] = toPipeOut(rxSynchronizer[i]);
      //rxSyncPipeIn[i] = toPipeIn(rxSynchronizer[i]);
      //mkConnection(gearboxUp[i].gbOut, rxSyncPipeIn[i]);
      //mkConnection(rxSyncPipeOut[i], pcs[i].bsyncIn);

      //txSynchronizer[i] <- mkSyncBRAMFIFO(10, clk_156_25, rst_156_25_n, pma4.tx_clkout[i], pma4.tx_reset[i]);
      //txSyncPipeOut[i] = toPipeOut(txSynchronizer[i]);
      //txSyncPipeIn[i] = toPipeIn(txSynchronizer[i]);
      //mkConnection(pcs[i].scramblerOut, txSyncPipeIn[i]);
      //mkConnection(txSyncPipeOut[i], gearboxDn[i].gbIn);
   end

   rule cyc;
      cycle <= cycle + 1;
   endrule

   for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
      rule receive;
         let v <- toGet(pcs[i].decoderOut).get;
         vRxPipeIn[i].enq(v);
      endrule
   end

   interface loopback = (interface LoopbackIfc;
      method Action lpbk_en (Bool en);
         loopback_en <= en;
      endmethod
   endinterface);
   interface rx_clkout = pma4.rx_clkout;
   interface tx_clkout = pma4.tx_clkout;
   interface serial = pma4.pmd;
   interface rx = vRxPipeOut;
   interface tx = vTxPipeIn;

endmodule: mkEthPhy
endpackage: EthPhy
