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
import IPv4Parser::*;
import MemMgmt::*;
import MemTypes::*;
import PacketBuffer::*;
import PacketTypes::*;
import StoreAndForward::*;
import SharedBuff::*;
import Tap::*;

interface HostChannel;
   interface PktWriteServer writeServer;
   interface MemWriteClient#(`DataBusWidth) writeClient;
   interface Client#(MetadataRequest, MetadataResponse) next;
   interface MemAllocClient mallocClient;
   method PktBuffDbgRec dbg;
endinterface

module mkHostChannel(HostChannel);
   let verbose = True;
   FIFO#(MetadataRequest) outReqFifo <- mkFIFO;
   FIFO#(MetadataResponse) inRespFifo <- mkFIFO;

   PacketBuffer pktBuff <- mkPacketBuffer();
   TapPktRead tap <- mkTapPktRead();
   Parser parser <- mkParser();
   StoreAndFwdFromRingToMem ingress <- mkStoreAndFwdFromRingToMem();

   mkConnection(tap.readClient, pktBuff.readServer);
   mkConnection(ingress.readClient, tap.readServer);
   mkConnection(tap.tap_out, toPut(parser.frameIn));

   rule handle_packet_process;
      let v <- ingress.eventPktCommitted.get;
      let ipv4 <- toGet(parser.parsedOut_ipv4_dstAddr).get;
      if (verbose) $display("HostChannel: ipv4=%h, size=%d", ipv4, v.size);
      MetadataRequest nextReq = tagged RouteLookupRequest {pkt: v, dstip: ipv4};
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
endmodule

