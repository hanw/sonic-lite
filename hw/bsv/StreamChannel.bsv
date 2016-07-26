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

import BUtils::*;
import ClientServer::*;
import Connectable::*;
import CBus::*;
import ConfigReg::*;
import DbgDefs::*;
import DefaultValue::*;
import Ethernet::*;
import EthMac::*;
import GetPut::*;
import FIFO::*;
import FIFOF::*;
import MemMgmt::*;
import MemTypes::*;
import MIMO::*;
import Pipe::*;
import PacketBuffer::*;
import PrintTrace::*;
import StoreAndForward::*;
import SpecialFIFOs::*;
import SharedBuff::*;
import HeaderSerializer::*;

import `PARSER::*;
import `DEPARSER::*;
import `TYPEDEF::*;

interface StreamOutChannel;
   interface PktWriteServer writeServer;
   interface Server#(MetadataRequest, MetadataResponse) prev;
   interface Get#(PacketDataT#(64)) macTx;
   method Action set_verbosity (int verbosity);
endinterface

// Streaming version of TxChannel
module mkStreamOutChannel#(Clock txClock, Reset txReset)(StreamOutChannel);
   FIFO#(PacketInstance) pkt_ff <- mkFIFO;

   // RingBuffer Read Client
   FIFO#(EtherData) readDataFifo <- mkFIFO;
   FIFO#(Bit#(EtherLen)) readLenFifo <- mkFIFO;
   FIFO#(EtherReq) readReqFifo <- mkFIFO;
   FIFO#(EtherData) writeDataFifo <- mkFIFO;
   Reg#(Bool) readStarted <- mkReg(False);

   PacketBuffer pktBuff <- mkPacketBuffer();
   Deparser deparser <- mkDeparser();
   HeaderSerializer serializer <- mkHeaderSerializer();
   StoreAndFwdFromRingToMac ringToMac <- mkStoreAndFwdFromRingToMac(txClock, txReset);
   PacketBuffer pktBuffOut <- mkPacketBuffer();

   PktReadClient readClient = (interface PktReadClient;
      interface readData = toPut(readDataFifo);
      interface readLen = toPut(readLenFifo);
      interface readReq = toGet(readReqFifo);
   endinterface);

   PktWriteClient writeClient = (interface PktWriteClient;
      interface writeData = toGet(writeDataFifo);
   endinterface);

   rule packetReadStart if (!readStarted);
      let pktId = toGet(pkt_ff).get;
      let pktLen <- toGet(readLenFifo).get;
      readStarted <= True;
   endrule

   rule packetReadInProgress if (readStarted);
      let v <- toGet(readDataFifo).get;
      if (v.eop) begin
         readStarted <= False;
      end
      writeDataFifo.enq(v);
   endrule

   mkConnection(readClient, pktBuff.readServer);
   mkConnection(writeClient, deparser.writeServer);
   mkConnection(deparser.writeClient, serializer.writeServer); 
   mkConnection(serializer.writeClient, pktBuffOut.writeServer);
   mkConnection(ringToMac.readClient, pktBuffOut.readServer);

   interface writeServer= pktBuff.writeServer;
   interface macTx = ringToMac.macTx;
   interface prev = (interface Server#(MetadataRequest, MetadataResponse);
      interface request = (interface Put;
         method Action put (MetadataRequest req);
            let meta = req.meta;
            let pkt = req.pkt;
            pkt_ff.enq(pkt);
            deparser.metadata.enq(meta);
         endmethod
      endinterface);
   endinterface);
   method Action set_verbosity (int verbosity);
      deparser.set_verbosity(verbosity);
      serializer.set_verbosity(verbosity);
   endmethod
endmodule

// Streaming version of HostChannel
interface StreamInChannel;
   interface PktWriteServer writeServer;
   interface Client#(MetadataRequest, MetadataResponse) next;
   method Action set_verbosity (int verbosity);
endinterface

module mkStreamInChannel(StreamInChannel);
   let verbose = True;
   FIFO#(MetadataRequest) outReqFifo <- mkFIFO;
   FIFO#(MetadataResponse) inRespFifo <- mkFIFO;

   // RingBuffer Read Client
   FIFO#(EtherData) readDataFifo <- mkFIFO;
   FIFO#(Bit#(EtherLen)) readLenFifo <- mkFIFO;
   FIFO#(EtherReq) readReqFifo <- mkFIFO;
   FIFO#(EtherData) writeDataFifo <- mkFIFO;
   Reg#(Bool) readStarted <- mkReg(False);
   FIFO#(Bit#(EtherLen)) pktLenFifo <- mkFIFO;

   PacketBuffer pktBuff <- mkPacketBuffer();
   Parser parser <- mkParser();

   PktReadClient readClient = (interface PktReadClient;
      interface readData = toPut(readDataFifo);
      interface readLen = toPut(readLenFifo);
      interface readReq = toGet(readReqFifo);
   endinterface);

   PktWriteClient writeClient = (interface PktWriteClient;
      interface writeData = toGet(writeDataFifo);
   endinterface);

   mkConnection(readClient, pktBuff.readServer);
   mkConnection(toGet(writeDataFifo), toPut(parser.frameIn));

   rule packetReadStart if (!readStarted);
      let pktLen <- toGet(readLenFifo).get;
      pktLenFifo.enq(pktLen);
      readStarted <= True;
   endrule

   rule packetReadInProgress if (readStarted);
      let v <- toGet(readDataFifo).get;
      if (v.eop) begin
         readStarted <= False;
      end
      writeDataFifo.enq(v);
   endrule

   rule dispatch_packet;
      let pktLen <- toGet(pktLenFifo).get;
      let meta <- parser.meta.get;
      let pktInst = PacketInstance {id: 0, size: pktLen};
      MetadataRequest nextReq = MetadataRequest {pkt: pktInst, meta: meta};
      outReqFifo.enq(nextReq);
   endrule

   interface writeServer = pktBuff.writeServer;
   interface next = (interface Client#(MetadataRequest, MetadataResponse);
      interface request = toGet(outReqFifo);
      interface response = toPut(inRespFifo);
   endinterface);
   method Action set_verbosity (int verbosity);
      parser.set_verbosity(verbosity);
   endmethod
endmodule
