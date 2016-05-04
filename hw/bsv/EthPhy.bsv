
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
import EthPcsTx                      ::*;
import EthPcsRx                      ::*;
import DtpTx                         ::*;
import DtpRx                         ::*;
import DtpSwitch                     ::*;
import DtpDCFifo            ::*;
import ALTERA_SI570_WRAPPER          ::*;
import ALTERA_EDGE_DETECTOR_WRAPPER  ::*;
import AlteraExtra                   ::*;
import BuildVector                  ::*;

`ifdef NUMBER_OF_10G_PORTS
typedef `NUMBER_OF_10G_PORTS NumPorts;
`else
typedef 4 NumPorts;
`endif

interface DtpPhyIfc;
   interface EthPhyIfc phys;
   interface DtpPhyApiIfc api;
endinterface

function Bit#(n) reverseBits(Bit#(n) x);
   Vector#(n, Bit#(1)) vx = unpack(x);
   Vector#(n, Bit#(1)) rvx = Vector::reverse(vx);
   Bit#(n) prvx = pack(rvx);
   return(prvx);
endfunction

//(* synthesize *)
module mkEthPhy#(Clock mgmt_clk, Clock clk_156_25, Clock clk_644)(DtpPhyIfc);
   let verbose = False;

   Reg#(Bit#(128)) cycle <- mkReg(0);
   Reset defaultReset <- exposeCurrentReset;
   Reset rst_50_n <- mkAsyncReset(2, defaultReset, mgmt_clk);
   //Reset rst_156_25_n <- mkAsyncReset(2, defaultReset, clk_156_25);
   let rst_156_25_n = defaultReset;

   FIFOF#(Bit#(128)) tsFifo <- mkFIFOF();
   Reg#(Bool) loopback_en <- mkReg(False);
   Reg#(Bool) switch_en <- mkReg(False);

   let bypass_dtp = False;

   Vector#(NumPorts, EthPcsRx) pcs_rx = newVector;
   Vector#(NumPorts, EthPcsTx) pcs_tx = newVector;
   Vector#(NumPorts, DtpRx)    dtp_rx = newVector;
   Vector#(NumPorts, DtpTx)    dtp_tx = newVector;


`ifdef SYNTHESIS
   EthSonicPma#(NumPorts)      pma4 <- mkEthSonicPma(mgmt_clk, clk_644, clk_156_25, rst_50_n, clocked_by mgmt_clk, reset_by rst_50_n);
   Vector#(NumPorts, ReadOnly#(Bool)) rx_ready_tx;
   Vector#(NumPorts, ReadOnly#(Bool)) tx_ready_tx;
   Vector#(NumPorts, ReadOnly#(Bool)) rx_ready_rx;
   Vector#(NumPorts, ReadOnly#(Bool)) tx_ready_rx;
   Vector#(NumPorts, CrossingReg#(Bool)) lock_tx;
   for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
      rx_ready_tx[i] <- mkNullCrossingWire(clk_156_25, pma4.rx_ready[i]);
      tx_ready_tx[i] <- mkNullCrossingWire(clk_156_25, pma4.tx_ready[i]);
      rx_ready_rx[i] <- mkNullCrossingWire(pma4.rx_clkout[i], pma4.rx_ready[i]);
      tx_ready_rx[i] <- mkNullCrossingWire(pma4.rx_clkout[i], pma4.tx_ready[i]);
      lock_tx[i] <- mkNullCrossingReg(clk_156_25, False, clocked_by pma4.rx_clkout[i], reset_by pma4.rx_reset[i]);
   end
`else
   Vector#(NumPorts, Reg#(Bool)) rx_ready_tx;
   Vector#(NumPorts, Reg#(Bool)) tx_ready_tx;
   Vector#(NumPorts, Reg#(Bool)) rx_ready_rx;
   Vector#(NumPorts, Reg#(Bool)) tx_ready_rx;
   Vector#(NumPorts, Reg#(Bool)) lock_tx;
   for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
      rx_ready_tx[i] <- mkReg(True);
      tx_ready_tx[i] <- mkReg(True);
      rx_ready_rx[i] <- mkReg(True);
      tx_ready_rx[i] <- mkReg(True);
      lock_tx[i] <- mkReg(False);
   end
`endif

   Vector#(NumPorts, FIFOF#(Bit#(72)))   txFifo     = newVector;
   Vector#(NumPorts, FIFOF#(Bit#(72)))   rxFifo     = newVector;
   Vector#(NumPorts, PipeIn#(Bit#(72)))  vRxPipeIn  = newVector;
   Vector#(NumPorts, Get#(Bit#(72))) vRxPipeOut = newVector;
   Vector#(NumPorts, Put#(Bit#(72)))  vTxPipeIn  = newVector;
   Vector#(NumPorts, PipeOut#(Bit#(72))) vTxPipeOut = newVector;

   // Loopback FIFO
   Vector#(NumPorts, SyncFIFOIfc#(Bit#(66))) lpbkSyncFifo = newVector;
   Vector#(NumPorts, PipeOut#(Bit#(66))) lpbkSyncPipeOut = newVector;
   Vector#(NumPorts, PipeIn#(Bit#(66))) lpbkSyncPipeIn = newVector;

   // DtpRx to DtpTx Fifo
   Vector#(NumPorts, SyncFIFOIfc#(DtpEvent)) dtpEventFifo = newVector;
   Vector#(NumPorts, PipeOut#(DtpEvent)) dtpEventOut = newVector;
   Vector#(NumPorts, PipeIn#(DtpEvent)) dtpEventIn = newVector;
   Vector#(NumPorts, SyncFIFOIfc#(Bit#(32))) dtpErrCntFifo = newVector;
   Vector#(NumPorts, PipeOut#(Bit#(32))) dtpErrCntOut = newVector;
   Vector#(NumPorts, PipeIn#(Bit#(32))) dtpErrCntIn = newVector;

   // Debugging
   Vector#(NumPorts, SyncFIFOIfc#(PcsDbgRec)) phyRxDebug = newVector;
   Vector#(NumPorts, FIFOF#(PcsDbgRec)) phyTxDebug <- replicateM(mkFIFOF(clocked_by clk_156_25, reset_by rst_156_25_n));

   // 156.25MHz to pma4.tx
   Vector#(NumPorts, SyncFIFOIfc#(Bit#(66))) txSyncFifo = newVector;

   FIFOF#(Bit#(1)) switchModeFifo <- mkFIFOF();

   for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
`ifdef SYNTHESIS
      Clock rxClock = pma4.rx_clkout[i];
      Reset rxReset = pma4.rx_reset[i];
`else
      Clock rxClock = clk_156_25;
      Reset rxReset = rst_156_25_n;
`endif

      rxFifo[i] <- mkFIFOF(clocked_by rxClock, reset_by rxReset);
      txFifo[i] <- mkFIFOF(clocked_by clk_156_25, reset_by rst_156_25_n);
      vRxPipeIn[i] = toPipeIn(rxFifo[i]);
      vRxPipeOut[i] = toGet(rxFifo[i]);
      vTxPipeIn[i] = toPut(txFifo[i]);
      vTxPipeOut[i] = toPipeOut(txFifo[i]);

      // Gearbox Level Loopback FIFO
      lpbkSyncFifo[i] <- mkSyncFIFO(10, clk_156_25, rst_156_25_n, rxClock);//, pma4.rx_reset[i]);
      lpbkSyncPipeOut[i] = toPipeOut(lpbkSyncFifo[i]);
      lpbkSyncPipeIn[i] = toPipeIn(lpbkSyncFifo[i]);

      //pcs_rx[i]    <- mkEthPcsRxTop(clocked_by rxClock, reset_by rxReset);
      //pcs_tx[i]    <- mkEthPcsTxTop(clocked_by clk_156_25, reset_by rst_156_25_n);
      pcs_rx[i]    <- mkEthPcsRx(i, clocked_by rxClock, reset_by rxReset);
      pcs_tx[i]    <- mkEthPcsTx(i, clocked_by clk_156_25, reset_by rst_156_25_n);
      dtp_rx[i]    <- mkDtpRxTop(clocked_by rxClock, reset_by rxReset);
      dtp_tx[i]    <- mkDtpTxTop(clocked_by clk_156_25, reset_by rst_156_25_n);

      dtpEventFifo[i] <- mkSyncFIFO(10, rxClock, rxReset, clk_156_25);//, rst_156_25_n);
      //dtpEventFifo[i] <- mkDtpDCFifo(pma4.rx_clkout[i], pma4.rx_reset[i], clk_156_25);//, rst_156_25_n);
      dtpEventOut[i] = toPipeOut(dtpEventFifo[i]);
      dtpEventIn[i]  = toPipeIn(dtpEventFifo[i]);

      dtpErrCntFifo[i] <- mkSyncFIFO(10, rxClock, rxReset, clk_156_25);//, rst_156_25_n);
      dtpErrCntOut[i] = toPipeOut(dtpErrCntFifo[i]);
      dtpErrCntIn[i]  = toPipeIn(dtpErrCntFifo[i]);

      if (bypass_dtp) begin
          // Rx Path: bypassing dtp
          mkConnection(pcs_rx[i].dtpRxIn, pcs_rx[i].dtpRxOut);
      end
      else begin
          // Rx Path: PcsRx -> DtpRx
          mkConnection(pcs_rx[i].dtpRxIn, dtp_rx[i].dtpRxIn);
          // Rx Path: DtpRx -> PcsRx
          mkConnection(dtp_rx[i].dtpRxOut, pcs_rx[i].dtpRxOut);
      end
      // Rx Path: DtpRx -> SyncFIFO
      mkConnection(dtp_rx[i].dtpEventOut, dtpEventIn[i]);
      // Rx Path DtpRx -> SyncFifo
      mkConnection(dtp_rx[i].dtpErrCnt, dtpErrCntIn[i]);

      // Tx Path SyncFIfo -> DtpTx
      mkConnection(dtpErrCntOut[i], dtp_tx[i].dtpErrCnt);
      // Tx Path; SyncFifo -> DtpTx
      mkConnection(dtpEventOut[i], dtp_tx[i].dtpEventIn);
      // Tx Path: Mac -> Encoder
      mkConnection(vTxPipeOut[i], pcs_tx[i].encoderIn);
      if (bypass_dtp) begin
          // Tx Path: bypassing dtp
          mkConnection(pcs_tx[i].dtpTxIn, pcs_tx[i].dtpTxOut);
      end
      else begin
          // Tx Path: PcsTx -> DtpTx
          mkConnection(pcs_tx[i].dtpTxIn, dtp_tx[i].dtpTxIn);
          // Tx Path: DtpTx -> PcsTx
          mkConnection(dtp_tx[i].dtpTxOut, pcs_tx[i].dtpTxOut);
      end

`ifdef SYNTHESIS
      // debugging
      phyRxDebug[i] <- mkSyncFIFO(4, pma4.rx_clkout[i], pma4.rx_reset[i], clk_156_25); 
      rule update_rx_debug;
         let v = pcs_rx[i].dbg;
         phyRxDebug[i].enq(v);
      endrule
      rule update_tx_debug ;
        let v = pcs_tx[i].dbg;
        phyTxDebug[i].enq(v);
      endrule
`endif

      // Loopback Enable Signal
      //ReadOnly#(Bool) rx_lpbk_en <- mkNullCrossingWire(pma4.rx_clkout[i], loopback_en);
      //ReadOnly#(Bool) tx_lpbk_en <- mkNullCrossingWire(clk_156_25, loopback_en);
      let rx_lpbk_en = False;
      let tx_lpbk_en = False;

      rule cross_lock_tx;
         lock_tx[i] <= pcs_rx[i].lock;
      endrule

`ifdef SYNTHESIS
      // Normal Operation: XCVR -> Pcs
      rule rx_no_loopback(!rx_lpbk_en);
         let v <- toGet(pma4.rx[i]).get;
         let reversed_v = reverseBits(v);
         pcs_rx[i].bsyncIn.enq(reversed_v);
      endrule
      rule tx_no_loopback(!tx_lpbk_en);
         let v <- toGet(pcs_tx[i].scramblerOut).get;
         let reversed_v = reverseBits(v);
         pma4.tx[i].enq(reversed_v);
      endrule
      // END Normal Operation

      // Loopback Operation: Pcs -> lpbk Fifo -> Pcs
      ReadOnly#(Bit#(32)) cycle_cross <- mkNullCrossingWire(clk_156_25, truncate(cycle));
      rule tx_loopback(tx_lpbk_en);
         let v <- toGet(pcs_tx[i].scramblerOut).get;
         lpbkSyncPipeIn[i].enq(v);
      endrule
      rule tx_pma_loopback(tx_lpbk_en);
         // Make sure PMA is up by sending fake data.
         Bit#(66) count = 66'hAAAAA55555AAAAAA;
         pma4.tx[i].enq(count);
      endrule
      rule rx_loopback(rx_lpbk_en);
         let v <- toGet(lpbkSyncPipeOut[i]).get;
         pcs_rx[i].bsyncIn.enq(v);
      endrule
      rule rx_pma_loopback(rx_lpbk_en);
         let v <- toGet(pma4.rx[i]).get;
      endrule
      // END Loopback Operation
`else
    rule tx_sim;
        let v <- toGet(pcs_tx[i].scramblerOut).get;
        lpbkSyncPipeIn[i].enq(v);
    endrule
    rule rx_sim;
        let v <- toGet(lpbkSyncPipeOut[i]).get;
        pcs_rx[i].bsyncIn.enq(v);
    endrule
`endif
   end

   rule cyc;
      cycle <= cycle + 1;
   endrule

   rule send_dtp_cycle;
      tsFifo.enq(cycle);
   endrule

   ReadOnly#(Bool) switch_en_tx;
   switch_en_tx <- mkNullCrossingWire(clk_156_25, switch_en);

   DtpSwitch#(4) dtpswitch <- mkDtpSwitch(clocked_by clk_156_25, reset_by rst_156_25_n);
   for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
      mkConnection(dtp_tx[i].dtpLocalOut, dtpswitch.dtpLocalIn[i]);
      mkConnection(dtpswitch.dtpGlobalOut[i], dtp_tx[i].dtpGlobalIn);
   end

   for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
      rule pcs_tx_every1;
         pcs_tx[i].tx_ready(tx_ready_tx[i]);
      endrule
      rule pcs_rx_every1;
         pcs_rx[i].rx_ready(rx_ready_rx[i]);
      endrule
      rule dtp_tx_every1;
         dtp_tx[i].tx_ready(tx_ready_tx[i]);
         dtp_tx[i].rx_ready(rx_ready_tx[i]);
         dtp_tx[i].switch_mode(switch_en_tx);
`ifdef SYNTHESIS
         dtp_tx[i].bsync_lock(lock_tx[i].crossed);
`else
         dtp_tx[i].bsync_lock(lock_tx[i]);
`endif

      endrule
      rule dtp_rx_every1;
         dtp_rx[i].rx_ready(rx_ready_rx[i]);
         dtp_rx[i].bsync_lock(pcs_rx[i].lock);
      endrule
   end

   rule switch_mode;
      let v <- toGet(switchModeFifo).get;
      switch_en <= unpack(v);
   endrule

   rule dtpswitch_mode;
      dtpswitch.switch_mode(switch_en_tx);
   endrule

   for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
      rule receive;
         let v <- toGet(pcs_rx[i].decoderOut).get;
         if (verbose) $display("EthPhy %d: decoderOut=%h", i, v);
         vRxPipeIn[i].enq(v);
      endrule
   end

   Vector#(NumPorts, DtpToPhyIfc) vapi;
   for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
      vapi[i] = dtp_tx[i].api;
   end
   function PcsDbgRec getPcsTxDbgRec (EthPcsTx tx);
    return tx.dbg;
   endfunction
   function PcsDbgRec getPcsRxDbgRec (EthPcsRx rx);
    return rx.dbg;
   endfunction

/*   interface loopback = (interface LoopbackIfc;
      method Action lpbk_en (Bool en);
         loopback_en <= en;
      endmethod
   endinterface);*/

   interface phys = (interface EthPhyIfc;
`ifdef SYNTHESIS
      interface rx_clkout = pma4.rx_clkout;
      method serial_tx = pma4.serial_tx;
      method serial_rx = pma4.serial_rx;
`else  
      interface rx_clkout = replicate(clk_156_25);
`endif
      interface rx = vRxPipeOut;
      interface tx = vTxPipeIn;
   endinterface);
   interface api = (interface DtpPhyApiIfc;
      interface timestamp = toPipeOut(tsFifo);
      interface phys = vapi;
      interface switchMode = toPipeIn(switchModeFifo);
      interface globalOut = dtpswitch.globalOut;

      interface tx_dbg = map(toPipeOut, phyTxDebug);
      interface rx_dbg = map(toPipeOut, phyRxDebug);
   endinterface);
endmodule: mkEthPhy
endpackage: EthPhy
