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
import GetPut::*;
import FIFO::*;
import MemMgmt::*;
import MemTypes::*;
import PacketBuffer::*;
import Pipe::*;
import StoreAndForward::*;
import SharedBuff::*;
import Tap::*;

import PaxosTypes::*;
import Paxos::*;

interface HostChannel;
   interface PktWriteServer writeServer;
   interface MemWriteClient#(`DataBusWidth) writeClient;
   interface MemAllocClient mallocClient;
   interface Client#(MetadataRequest, MetadataResponse) next;
   method PktBuffDbgRec dbg;
   method HostChannelDbgRec hostdbg;
endinterface

module mkHostChannel(HostChannel);
   let verbose = True;
   FIFO#(MetadataRequest) outReqFifo <- mkFIFO;
   FIFO#(MetadataResponse) inRespFifo <- mkFIFO;

   Reg#(Bit#(64)) paxosCount <- mkReg(0);
   Reg#(Bit#(64)) ipv6Count <- mkReg(0);
   Reg#(Bit#(64)) udpCount <- mkReg(0);

   PacketBuffer pktBuff <- mkPacketBuffer();
   TapPktRead tap <- mkTapPktRead();
   Parser parser <- mkParser();
   StoreAndFwdFromRingToMem ingress <- mkStoreAndFwdFromRingToMem();

   mkConnection(tap.readClient, pktBuff.readServer);
   mkConnection(ingress.readClient, tap.readServer);
   mkConnection(tap.tap_out, toPut(parser.frameIn));

   rule dispatch_packet;
      let v <- toGet(ingress.eventPktCommitted).get;
      let meta <- toGet(parser.meta).get;
      MetadataRequest nextReq = tagged DefaultRequest { pkt: v, meta: meta};
      outReqFifo.enq(nextReq);
   endrule

   interface writeServer = pktBuff.writeServer;
   interface writeClient = ingress.writeClient;
   interface next = (interface Client#(MetadataRequest, MetadataResponse);
      interface request = toGet(outReqFifo);
      interface response = toPut(inRespFifo);
   endinterface);
   interface mallocClient = ingress.malloc;
   method dbg = pktBuff.dbg;
   method HostChannelDbgRec hostdbg();
      return HostChannelDbgRec {
         paxosCount : paxosCount,
         ipv6Count : ipv6Count,
         udpCount : udpCount
      };
   endmethod
endmodule

