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
import DbgTypes::*;
import Ethernet::*;
import EthMac::*;
import GetPut::*;
import IPv4Parser::*;
import MemMgmt::*;
import MemTypes::*;
import PacketBuffer::*;
import StoreAndForward::*;
import SharedBuff::*;

// Encapsulate Rx Ring, Tap, Parser
interface RxChannel;
   interface Put#(PacketDataT#(64)) macRx;
   interface MemWriteClient#(`DataBusWidth) writeClient;
   interface MemAllocClient mallocClient;
   interface Get#(PacketInstance) eventPktCommitted;
   method PktBuffDbgRec dbg;
endinterface

module mkRxChannel#(Clock rxClock, Reset rxReset)(RxChannel);

   PacketBuffer pktBuff <- mkPacketBuffer();
   StoreAndFwdFromRingToMem ingress <- mkStoreAndFwdFromRingToMem();
   StoreAndFwdFromMacToRing macToRing <- mkStoreAndFwdFromMacToRing(rxClock, rxReset);

   // Rx Channel
   mkConnection(macToRing.writeClient, pktBuff.writeServer);
   mkConnection(ingress.readClient, pktBuff.readServer);

   interface macRx = macToRing.macRx;
   interface writeClient = ingress.writeClient;
   interface eventPktCommitted = ingress.eventPktCommitted;
   interface mallocClient = ingress.malloc;
   method dbg = pktBuff.dbg;
endmodule
