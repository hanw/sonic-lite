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
import DbgDefs::*;
import Ethernet::*;
import EthMac::*;
import GetPut::*;
import MemMgmt::*;
import MemTypes::*;
import Pipe::*;
import PacketBuffer::*;
import StoreAndForward::*;
import SharedBuff::*;

import `PARSER::*;

// Encapsulate Egress Pipeline, Tx Ring
interface TxChannel;
   interface MemReadClient#(`DataBusWidth) readClient;
   interface MemFreeClient freeClient;
   interface PipeIn#(MetadataRequest) eventPktSend;
   interface Get#(PacketDataT#(64)) macTx;
   method TxChannelDbgRec read_debug_info;
   method DeparserPerfRec read_deparser_perf_info;
endinterface

module mkTxChannel#(Clock txClock, Reset txReset)(TxChannel);
   PacketBuffer pktBuff <- mkPacketBuffer();
   Deparser deparser <- mkDeparser();
   StoreAndFwdFromMemToRing egress <- mkStoreAndFwdFromMemToRing();
   StoreAndFwdFromRingToMac ringToMac <- mkStoreAndFwdFromRingToMac(txClock, txReset);

   mkConnection(egress.writeClient, deparser.writeServer);
   mkConnection(deparser.writeClient, pktBuff.writeServer);
   mkConnection(ringToMac.readClient, pktBuff.readServer);

   interface macTx = ringToMac.macTx;
   interface readClient = egress.readClient;
   interface freeClient = egress.free;
   interface PipeIn eventPktSend;
      method Action enq (MetadataRequest req);
         case (req) matches
            tagged ForwardQueueRequest {pkt: .pkt, meta: .meta}: begin
               egress.eventPktSend.enq(pkt);
               deparser.metadata.enq(meta);
            end
         endcase
      endmethod
      method notFull = egress.eventPktSend.notFull;
   endinterface
   method TxChannelDbgRec read_debug_info;
      return TxChannelDbgRec {
         egressCount : 0,
         pktBuff: pktBuff.dbg
         };
   endmethod
   method read_deparser_perf_info = deparser.read_perf_info;
endmodule

