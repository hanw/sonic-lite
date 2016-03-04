// Copyright (c) 2016 Cornell University.

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

import Connectable::*;
import ClientServer::*;
import DbgTypes::*;
import Ethernet::*;
import EthMac::*;
import GetPut::*;
import FIFO::*;
import MemMgmt::*;
import MemTypes::*;
import PacketBuffer::*;
import PaxosTypes::*;
import Paxos::*;
import Pipe::*;
import StoreAndForward::*;
import SharedBuff::*;
import Tap::*;

// Encapsulate Rx Ring, Tap, Parser
interface RxChannel;
   interface Put#(PacketDataT#(64)) macRx;
   interface MemWriteClient#(`DataBusWidth) writeClient;
   interface MemAllocClient mallocClient;
   interface Client#(MetadataRequest, MetadataResponse) next;
   method PktBuffDbgRec dbg;
endinterface

module mkRxChannel#(Clock rxClock, Reset rxReset)(RxChannel);
   let verbose = True;
   FIFO#(MetadataRequest) outReqFifo0 <- mkFIFO;
   FIFO#(MetadataResponse) inRespFifo0 <- mkFIFO;

   PacketBuffer pktBuff <- mkPacketBuffer();
   TapPktRead tap <- mkTapPktRead();
   Parser parser <- mkParser();
   StoreAndFwdFromRingToMem ingress <- mkStoreAndFwdFromRingToMem();
   StoreAndFwdFromMacToRing macToRing <- mkStoreAndFwdFromMacToRing(rxClock, rxReset);

   // Rx Channel
   mkConnection(tap.readClient, pktBuff.readServer);
   mkConnection(ingress.readClient, tap.readServer);
   mkConnection(tap.tap_out, toPut(parser.frameIn));
   mkConnection(macToRing.writeClient, pktBuff.writeServer);

   rule handle_packet_process;
      let v <- toGet(ingress.eventPktCommitted).get;
      let dstMac <- toGet(parser.parsedOut_ethernet_dstAddr).get;
      let msgtype <- toGet(parser.parsedOut_paxos_msgtype).get;
      if (verbose) $display("HostChannel: dstMac=%h, size=%d", dstMac, v.size);
      if (verbose) $display("HostChannel: msgtype=%h", msgtype);
      MetadataRequest nextReq0 = tagged DstMacLookupRequest { pkt: v, dstMac: dstMac };
      outReqFifo0.enq(nextReq0);
   endrule

   interface macRx = macToRing.macRx;
   interface writeClient = ingress.writeClient;
   interface next = (interface Client#(MetadataRequest, MetadataResponse);
      interface request = toGet(outReqFifo0);
      interface response = toPut(inRespFifo0);
   endinterface);
   interface mallocClient = ingress.malloc;
   method dbg = pktBuff.dbg;
endmodule
