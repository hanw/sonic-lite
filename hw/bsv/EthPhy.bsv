
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
import EthPcsTx                      ::*;
import EthPcsRx                      ::*;
import DtpTx                         ::*;
import DtpRx                         ::*;
import Gearbox_40_66                 ::*;
import Gearbox_66_40                 ::*;
import ALTERA_SI570_WRAPPER          ::*;
import ALTERA_EDGE_DETECTOR_WRAPPER  ::*;
import DtpSwitch                     ::*;
import ALTERA_PLL_PMA_156            ::*;
import AlteraExtra        :: *;

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
   (* always_ready, always_enabled *)
   interface LoopbackIfc loopback;
   (* always_ready, always_enabled *)
   interface SwitchIfc switchctrl;

   interface Vector#(numPorts, Bool) led_rx_ready;
   interface Vector#(numPorts, DtpToPhyIfc) api;
endinterface

function Bit#(n) reverseBits(Bit#(n) x);
   Vector#(n, Bit#(1)) vx = unpack(x);
   Vector#(n, Bit#(1)) rvx = Vector::reverse(vx);
   Bit#(n) prvx = pack(rvx);
   return(prvx);
endfunction

(* synthesize *)
module mkEthPhy#(Clock mgmt_clk, Clock clk_156_25, Clock clk_644, Reset rst_n)(EthPhyIfc#(NumPorts));

   Reg#(Bit#(32)) cycle <- mkReg(0);
   Reset rst_50_n <- mkAsyncReset(2, rst_n, mgmt_clk);
   Reset rst_156_25_n <- mkAsyncReset(2, rst_n, clk_156_25);

   Reg#(Bool) loopback_en <- mkReg(False);
   Reg#(Bool) switch_en <- mkReg(False);

   Vector#(NumPorts, PllPma)   pll_pma = newVector;
   Vector#(NumPorts, EthPcsRx) pcs_rx = newVector;
   Vector#(NumPorts, EthPcsTx) pcs_tx = newVector;
   Vector#(NumPorts, DtpRx)    dtp_rx = newVector;
   Vector#(NumPorts, DtpTx)    dtp_tx = newVector;
   Vector#(NumPorts, Clock)    pma_156_clkout = newVector;
   Vector#(NumPorts, Reset)    pma_156_rst_n  = newVector;
   Vector#(NumPorts, Reset)    pll_pma_rst = newVector;
   Vector#(NumPorts, AltClkCtrl) pma_clkctrl = newVector;

   EthSonicPma#(NumPorts)      pma4 <- mkEthSonicPma(mgmt_clk, clk_644, rst_50_n, clocked_by mgmt_clk, reset_by rst_50_n);

   for (Integer i=0; i< valueOf(NumPorts); i=i+1) begin
      pma_clkctrl[i] <- mkAltClkCtrl(pma4.rx_clkout[i]);
      pll_pma_rst[i] <- mkResetInverter(rst_n, clocked_by pma_clkctrl[i].outclk);
      pll_pma[i] <- mkPllPma(pma_clkctrl[i].outclk, pll_pma_rst[i], clocked_by pma_clkctrl[i].outclk, reset_by pll_pma_rst[i]);
      pma_156_clkout[i] = pll_pma[i].outclk0;
      pma_156_rst_n[i] <- mkAsyncReset(1, rst_n, pma_156_clkout[i], clocked_by pma_156_clkout[i]);
   end

   Vector#(NumPorts, ReadOnly#(Bool)) rx_ready_cross;
   Vector#(NumPorts, ReadOnly#(Bool)) tx_ready_cross;
   Vector#(NumPorts, ReadOnly#(Bool)) rx_ready_cross_rx;
   Vector#(NumPorts, ReadOnly#(Bool)) tx_ready_cross_rx;
   for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
      rx_ready_cross[i] <- mkNullCrossingWire(clk_156_25, pma4.rx_ready[i]);
      tx_ready_cross[i] <- mkNullCrossingWire(clk_156_25, pma4.tx_ready[i]);
      rx_ready_cross_rx[i] <- mkNullCrossingWire(pma_156_clkout[i], pma4.rx_ready[i]);
      tx_ready_cross_rx[i] <- mkNullCrossingWire(pma_156_clkout[i], pma4.tx_ready[i]);
   end

   Vector#(NumPorts, Gearbox_40_66)      gearboxUp  = newVector;
   Vector#(NumPorts, Gearbox_66_40)      gearboxDn  = newVector;
   Vector#(NumPorts, FIFOF#(Bit#(72)))   txFifo     = newVector;
   Vector#(NumPorts, FIFOF#(Bit#(72)))   rxFifo     = newVector;
   Vector#(NumPorts, PipeIn#(Bit#(72)))  vRxPipeIn  = newVector;
   Vector#(NumPorts, PipeOut#(Bit#(72))) vRxPipeOut = newVector;
   Vector#(NumPorts, PipeIn#(Bit#(72)))  vTxPipeIn  = newVector;
   Vector#(NumPorts, PipeOut#(Bit#(72))) vTxPipeOut = newVector;

   // Loopback FIFO
   Vector#(NumPorts, SyncFIFOIfc#(Bit#(40))) lpbkSyncFifo = newVector;
   Vector#(NumPorts, PipeOut#(Bit#(40))) lpbkSyncPipeOut = newVector;
   Vector#(NumPorts, PipeIn#(Bit#(40))) lpbkSyncPipeIn = newVector;

   // DtpRx to DtpTx Fifo
   Vector#(NumPorts, SyncFIFOIfc#(DtpEvent)) dtpEventFifo = newVector;
   Vector#(NumPorts, PipeOut#(DtpEvent)) dtpEventOut = newVector;
   Vector#(NumPorts, PipeIn#(DtpEvent)) dtpEventIn = newVector;

   for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
      rxFifo[i] <- mkFIFOF(clocked_by pma_156_clkout[i], reset_by pma_156_rst_n[i]);
      txFifo[i] <- mkFIFOF(clocked_by clk_156_25, reset_by rst_156_25_n);
      vRxPipeIn[i] = toPipeIn(rxFifo[i]);
      vRxPipeOut[i] = toPipeOut(rxFifo[i]);
      vTxPipeIn[i] = toPipeIn(txFifo[i]);
      vTxPipeOut[i] = toPipeOut(txFifo[i]);
      // Gearbox Level Loopback FIFO
      lpbkSyncFifo[i] <- mkSyncBRAMFIFO(10, pma4.tx_clkout[i], pma4.tx_reset[i], pma4.rx_clkout[i], pma4.rx_reset[i]);
      lpbkSyncPipeOut[i] = toPipeOut(lpbkSyncFifo[i]);
      lpbkSyncPipeIn[i] = toPipeIn(lpbkSyncFifo[i]);

      // Gearbox Upstream
      gearboxUp[i] <- mkGearbox40to66(pma_156_clkout[i], clocked_by pma4.rx_clkout[i], reset_by pma4.rx_reset[i]);
      // Gearbox Downstream
      gearboxDn[i] <- mkGearbox66to40(clk_156_25, clocked_by pma4.tx_clkout[i], reset_by pma4.tx_reset[i]);
      // PCS
      pcs_rx[i]    <- mkEthPcsRx(i, clocked_by pma_156_clkout[i], reset_by pma_156_rst_n[i]);
      pcs_tx[i]    <- mkEthPcsTx(i, clocked_by clk_156_25, reset_by rst_156_25_n);
      dtp_rx[i]    <- mkDtpRxTop(clocked_by pma_156_clkout[i], reset_by pma_156_rst_n[i]);
      dtp_tx[i]    <- mkDtpTxTop(clocked_by clk_156_25, reset_by rst_156_25_n);

      dtpEventFifo[i] <- mkSyncBRAMFIFO(10, pma_156_clkout[i], pma_156_rst_n[i], clk_156_25, rst_156_25_n);
      dtpEventOut[i] = toPipeOut(dtpEventFifo[i]);
      dtpEventIn[i]  = toPipeIn(dtpEventFifo[i]);

      // Rx Path: Gearbox 40/66 -> Blocksync
      mkConnection(gearboxUp[i].gbOut, pcs_rx[i].bsyncIn);
      // Rx Path: PcsRx -> DtpRx
      mkConnection(pcs_rx[i].dtpRxIn, dtp_rx[i].dtpRxIn);
      // Rx Path: DtpRx -> PcsRx
      mkConnection(dtp_rx[i].dtpRxOut, pcs_rx[i].dtpRxOut);
      // Rx Path: DtpRx -> SyncFIFO
      mkConnection(dtp_rx[i].dtpEventOut, dtpEventIn[i]);

      // Tx Path; SyncFifo -> DtpTx
      mkConnection(dtpEventOut[i], dtp_tx[i].dtpEventIn);
      // Tx Path: Mac -> Encoder
      mkConnection(vTxPipeOut[i], pcs_tx[i].encoderIn);
      // Tx Path: PcsTx -> DtpTx
      mkConnection(pcs_tx[i].dtpTxIn, dtp_tx[i].dtpTxIn);
      // Tx Path: DtpTx -> PcsTx
      mkConnection(dtp_tx[i].dtpTxOut, pcs_tx[i].dtpTxOut);
      // Tx Path: Scrambler -> Gearbox 66/40
      mkConnection(pcs_tx[i].scramblerOut, gearboxDn[i].gbIn);

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
         let v <- toGet(gearboxDn[i].gbOut).get;
         let reversed_v = reverseBits(v);
         pma4.tx[i].enq(reversed_v);
      endrule
      // END Normal Operation

      // Loopback Operation: Gearbox 66/40 -> lpbk Fifo -> Gearbox 40/66
      ReadOnly#(Bit#(32)) cycle_cross <- mkNullCrossingWire(pma4.tx_clkout[i], cycle);
      rule tx_loopback(tx_lpbk_en);
         let v <- toGet(gearboxDn[i].gbOut).get;
         lpbkSyncPipeIn[i].enq(v);
      endrule
      rule tx_pma_loopback(tx_lpbk_en);
         // Make sure PMA is up by sending fake data.
         Bit#(40) count = 40'hAAAAA55555;
         pma4.tx[i].enq(count);
      endrule
      rule rx_loopback(rx_lpbk_en);
         let v <- toGet(lpbkSyncPipeOut[i]).get;
         gearboxUp[i].gbIn.enq(v);
      endrule
      rule rx_pma_loopback(rx_lpbk_en);
         let v <- toGet(pma4.rx[i]).get;
      endrule
      // END Loopback Operation
   end

   rule cyc;
      cycle <= cycle + 1;
   endrule

   ReadOnly#(Bool) switch_mode_cross;
   switch_mode_cross <- mkNullCrossingWire(clk_156_25, switch_en);

   DtpSwitch#(4) dtpswitch <- mkDtpSwitch(clocked_by clk_156_25, reset_by rst_156_25_n);
   for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
      mkConnection(dtp_tx[i].dtpLocalOut, dtpswitch.dtpLocalIn[i]);
      mkConnection(dtpswitch.dtpGlobalOut[i], dtp_tx[i].dtpGlobalIn);
   end

   for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
      rule pcs_tx_every1;
         pcs_tx[i].tx_ready(tx_ready_cross[i]);
      endrule
      rule pcs_rx_every1;
         pcs_rx[i].rx_ready(rx_ready_cross_rx[i]);
      endrule
      rule dtp_tx_every1;
         dtp_tx[i].tx_ready(tx_ready_cross[i]);
         dtp_tx[i].rx_ready(rx_ready_cross[i]);
         dtp_tx[i].switch_mode(switch_mode_cross);
      endrule
      rule dtp_rx_every1;
         dtp_rx[i].rx_ready(rx_ready_cross_rx[i]);
      endrule
   end

   rule dtpswitch_mode;
      dtpswitch.switch_mode(switch_mode_cross);
   endrule

   for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
      rule receive;
         let v <- toGet(pcs_rx[i].decoderOut).get;
         vRxPipeIn[i].enq(v);
      endrule
   end

   Vector#(NumPorts, DtpToPhyIfc) vapi;
   for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
      vapi[i] = dtp_tx[i].api;
   end

   interface loopback = (interface LoopbackIfc;
      method Action lpbk_en (Bool en);
         loopback_en <= en;
      endmethod
   endinterface);

   interface switchctrl = (interface SwitchIfc;
      method Action ena (Bool en);
         switch_en <= en;
      endmethod
   endinterface);

   interface rx_clkout = pma_156_clkout; //pma4.rx_clkout;
   interface tx_clkout = pma4.tx_clkout;
   interface serial = pma4.pmd;
   interface rx = vRxPipeOut;
   interface tx = vTxPipeIn;
   interface led_rx_ready = pma4.rx_ready;

   interface api = vapi;

endmodule: mkEthPhy
endpackage: EthPhy
