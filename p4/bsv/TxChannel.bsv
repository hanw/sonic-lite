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
import MemMgmt::*;
import MemTypes::*;
import PacketBuffer::*;
import StoreAndForward::*;
import SharedBuff::*;

// Encapsulate Egress Pipeline, Tx Ring
interface TxChannel;
   interface MemReadClient#(`DataBusWidth) readClient;
   interface MemFreeClient freeClient;
   interface Put#(PacketInstance) eventPktSend;
   interface Get#(PacketDataT#(64)) macTx;
   method PktBuffDbgRec dbg;
endinterface

module mkTxChannel#(Clock txClock, Reset txReset)(TxChannel);
   PacketBuffer pktBuff <- mkPacketBuffer();
   StoreAndFwdFromMemToRing egress <- mkStoreAndFwdFromMemToRing();
   StoreAndFwdFromRingToMac ringToMac <- mkStoreAndFwdFromRingToMac(txClock, txReset);
   mkConnection(egress.writeClient, pktBuff.writeServer);
   mkConnection(ringToMac.readClient, pktBuff.readServer);

   interface macTx = ringToMac.macTx;
   interface readClient = egress.readClient;
   interface freeClient = egress.free;
   interface eventPktSend = egress.eventPktSend;
   method dbg = pktBuff.dbg;
endmodule

