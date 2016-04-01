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

import Arith ::*;
import BuildVector::*;
import ClientServer::*;
import Clocks::*;
import ConfigCounter::*;
import Connectable::*;
import DefaultValue::*;
import FIFO ::*;
import FIFOF ::*;
import GetPut ::*;
import Gearbox ::*;
import Pipe ::*;
import SpecialFIFOs ::*;
import Vector ::*;
import ConnectalConfig::*;
import StoreAndForward::*;

import Ethernet::*;
import EthMac::*;
import AlteraEthPhy::*;
import AlteraMacWrap::*;
import DmaEth::*;
import TestAPI::*;
import MemTypes::*;
import MemReadEngine::*;
import MemWriteEngine::*;
import PacketBuffer::*;
import HostInterface::*;
import ConnectalClocks::*;
import `PinTypeInclude::*;
import ALTERA_SI570_WRAPPER::*;
import AlteraExtra::*;
//import Sims::*;

interface TestTop;
   interface TestRequest request1;
   interface DmaRequest request2;
   interface DmaRequest request3;
   interface DmaRequest request4;
   interface DmaRequest request5;
   interface Vector#(1, MemReadClient#(DataBusWidth)) readClient;
   interface Vector#(1, MemWriteClient#(DataBusWidth)) writeClient;
   interface `PinType pins;
endinterface

module mkTestTop#(TestIndication indication1, DmaIndication indication2, DmaIndication indication3, DmaIndication indication4, DmaIndication indication5)(TestTop);
   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

   Wire#(Bit#(1)) clk_644_wire <- mkDWire(0);
   Wire#(Bit#(1)) clk_50_wire <- mkDWire(0);

   De5Clocks clocks <- mkDe5Clocks(clk_50_wire, clk_644_wire);
   De5SfpCtrl#(4) sfpctrl <- mkDe5SfpCtrl();
   Clock txClock = clocks.clock_156_25;
   Clock phyClock = clocks.clock_644_53;
   Clock mgmtClock = clocks.clock_50;

   MakeResetIfc dummyReset <- mkResetSync(0, False, defaultClock);
   Reset txReset <- mkAsyncReset(2, defaultReset, txClock);
   Reset dummyTxReset <- mkAsyncReset(2, dummyReset.new_rst, txClock);

   EthPhyIfc phys <- mkAlteraEthPhy(mgmtClock, phyClock, txClock, defaultReset);
   Clock rxClock = phys.rx_clkout;
   Reset rxReset <- mkAsyncReset(2, defaultReset, rxClock);
   Vector#(4, EthMacIfc) mac <- replicateM(mkEthMac(mgmtClock, txClock, rxClock, txReset, clocked_by txClock, reset_by txReset));

   Vector#(4, PacketBuffer) txPktBuff <- replicateM(mkPacketBuffer(clocked_by txClock, reset_by txReset));
   Vector#(4, PacketBuffer) rxPktBuff <- replicateM(mkPacketBuffer(clocked_by txClock, reset_by txReset));
   Vector#(4, StoreAndFwdFromRingToMac) ringToMac <- replicateM(mkStoreAndFwdFromRingToMac(txClock, txReset, clocked_by txClock, reset_by txReset));
   //Vector#(4, StoreAndFwdFromMacToRing) macToRing <- replicateM(mkStoreAndFwdFromMacToRing(txClock, txReset, clocked_by txClock, reset_by txReset)); 
   Vector#(4, StoreAndFwdFromMacToRing) macToRing <- replicateM(mkStoreAndFwdFromMacToRing(rxClock, rxReset, clocked_by txClock, reset_by txReset)); 

   DmaController#(4) dmaController <- mkDmaController(vec(indication2, indication3, indication4, indication5), txClock, txReset);

   for (Integer i = 0 ; i < 4 ; i = i +1) begin
      // Connect TX Path
      mkConnection(dmaController.networkWriteClient[i], txPktBuff[i].writeServer);
      mkConnection(ringToMac[i].readClient, txPktBuff[i].readServer);
      mkConnection(ringToMac[i].macTx, mac[i].packet_tx);
      mkConnection(mac[i].tx, toPut(phys.tx[i]));
   
      // debugging
//      mkConnection(mac[i].tx, mac[i].rx);
//      mkConnection(ringToMac[i].macTx, macToRing[i].macRx);

      //Connect RX Path
      mkConnection(toGet(phys.rx[i]), mac[i].rx);
      mkConnection(macToRing[i].macRx, mac[i].packet_rx);
      mkConnection(macToRing[i].writeClient, rxPktBuff[i].writeServer);
      mkConnection(dmaController.networkReadClient[i], rxPktBuff[i].readServer);

   end

   TestAPI api <- mkTestAPI(indication1, txPktBuff, rxPktBuff, ringToMac, macToRing, txClock, txReset, rxClock, rxReset);

   interface request1 = api.request;
   interface request2 = dmaController.request[0];
   interface request3 = dmaController.request[1];
   interface request4 = dmaController.request[2];
   interface request5 = dmaController.request[3];
   interface readClient = dmaController.readClient;
   interface writeClient = dmaController.writeClient;

   interface `PinType pins;
      method Action osc_50(Bit#(1) b3d, Bit#(1) b4a, Bit#(1) b4d, Bit#(1) b7a, Bit#(1) b7d, Bit#(1) b8a, Bit#(1) b8d);
         clk_50_wire <= b4a;
      endmethod
      method Action sfp(Bit#(1) refclk);
         clk_644_wire <= refclk;
      endmethod
      method serial_tx_data = phys.serial_tx;
      method serial_rx = phys.serial_rx;
      interface i2c = clocks.i2c;
      interface sfpctrl = sfpctrl;
      interface deleteme_unused_clock = defaultClock;
      interface deleteme_unused_clock2 = mgmtClock;
      interface deleteme_unused_clock3 = defaultClock;
      interface deleteme_unused_reset = defaultReset;
   endinterface

endmodule
