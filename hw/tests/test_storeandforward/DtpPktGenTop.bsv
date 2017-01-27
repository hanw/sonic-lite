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
import PktGen::*;
import StoreAndForward::*;

import Ethernet::*;
import EthPhy::*;
import EthMac::*;
import DtpController::*;
import DtpPktGenAPI::*;
import MemTypes::*;
import MemReadEngine::*;
import MemWriteEngine::*;
import PacketBuffer::*;
import HostInterface::*;
import `PinTypeInclude::*;
import ConnectalClocks::*;
import Sims::*;

interface DtpPktGenTop;
   interface DtpPktGenRequest request2;
   interface `PinType pins;
endinterface

module mkDtpPktGenTop#(DtpPktGenIndication indication2)(DtpPktGenTop);
   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

   SimClocks clocks <- mkSimClocks();
   Clock txClock = clocks.clock_156_25;
   Clock phyClock = clocks.clock_644_53;
   Clock mgmtClock = clocks.clock_50;

   Reset txReset <- mkAsyncReset(2, defaultReset, txClock);

   Vector#(3, PacketBuffer) pkt_buff <- replicateM(mkPacketBuffer(clocked_by txClock, reset_by txReset));
   Vector#(3, StoreAndFwdFromRingToMac) ringToMac; //<- replicateM(mkStoreAndFwdFromRingToMac(txClock, txReset, clocked_by txClock, reset_by txReset));
   Vector#(3, StoreAndFwdFromMacToRing) macToRing; //<- replicateM(mkStoreAndFwdFromMacToRing(txClock, txReset, clocked_by txClock, reset_by txReset));

   for (Integer i = 0 ; i < 3 ; i = i +1) begin
      ringToMac[i] <- mkStoreAndFwdFromRingToMac(txClock, txReset, clocked_by txClock, reset_by txReset);
      macToRing[i] <- mkStoreAndFwdFromMacToRing(txClock, txReset, clocked_by txClock, reset_by txReset);
   end

   // port 0:Packet Generator
   PktGen pktgen <- mkPktGen(clocked_by txClock, reset_by txReset);
   mkConnection(pktgen.writeClient, pkt_buff[0].writeServer);
   mkConnection(ringToMac[0].readClient, pkt_buff[0].readServer);
   mkConnection(ringToMac[0].macTx, macToRing[0].macRx);
   mkConnection(macToRing[0].writeClient, pkt_buff[1].writeServer);
   mkConnection(ringToMac[1].readClient, pkt_buff[1].readServer);
   mkConnection(ringToMac[1].macTx, macToRing[1].macRx);
   mkConnection(macToRing[1].writeClient, pkt_buff[2].writeServer);
   mkConnection(ringToMac[2].readClient, pkt_buff[2].readServer);

//   mkConnection(ringToMac[1].macTx, macToRing[1].macRx);

   rule drain_mac0;
      let v <- toGet(ringToMac[2].macTx).get;
   endrule

   DtpPktGenAPI api <- mkDtpPktGenAPI(indication2, pktgen, pkt_buff, ringToMac, macToRing, txClock, txReset);

   // PktGen start/stop
   SyncFIFOIfc#(Tuple2#(Bit#(32),Bit#(32))) pktGenStartSyncFifo <- mkSyncFIFO(4, defaultClock, defaultReset, txClock);
   SyncFIFOIfc#(Bit#(1)) pktGenStopSyncFifo <- mkSyncFIFO(4, defaultClock, defaultReset, txClock);
   SyncFIFOIfc#(ByteStream#(16)) pktGenWriteSyncFifo <- mkSyncFIFO(4, defaultClock, defaultReset, txClock);
   mkConnection(api.pktGenStart, toPut(pktGenStartSyncFifo));
   mkConnection(api.pktGenStop, toPut(pktGenStopSyncFifo));
   mkConnection(api.pktGenWrite, toPut(pktGenWriteSyncFifo));
   rule req_start;
      let v <- toGet(pktGenStartSyncFifo).get;
      pktgen.start(tpl_1(v), tpl_2(v));
   endrule

   rule req_stop;
      let v <- toGet(pktGenStopSyncFifo).get;
      pktgen.stop();
   endrule

   rule req_write;
      let v <- toGet(pktGenWriteSyncFifo).get;
      pktgen.writeServer.writeData.put(v);
   endrule

   interface request2 = api.request;
endmodule
