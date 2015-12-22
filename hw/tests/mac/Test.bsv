import FIFO::*;
import FIFOF::*;
import DefaultValue::*;
import Vector::*;
import BuildVector::*;
import GetPut::*;
import ClientServer::*;
import Connectable::*;
import Clocks::*;

import Pipe::*;
import MemTypes::*;
import Ethernet::*;
import PacketBuffer::*;
import AlteraMacWrap::*;
import EthMac::*;

interface TestIndication;
   method Action done(Bit#(32) matchCount);
endinterface

interface TestRequest;
   method Action writePacketData(Vector#(2, Bit#(64)) data, Bit#(1) sop, Bit#(1) eop);
endinterface

interface Test;
   interface TestRequest request;
endinterface

module mkTest#(TestIndication indication) (Test);
   let verbose = True;
   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

   Clock txClock <- mkAbsoluteClock(0, 64);
   Reset txReset <- mkSyncReset(2, defaultReset, txClock);
   Clock rxClock <- mkAbsoluteClock(0, 64);
   Reset rxReset <- mkSyncReset(2, defaultReset, rxClock);

   Reg#(Bit#(32)) cycle <- mkReg(0, clocked_by rxClock, reset_by rxReset);

   SyncFIFOIfc#(Bit#(72)) rx_fifo <- mkSyncFIFO(5, defaultClock, defaultReset, rxClock);

   PacketBuffer buff <- mkPacketBuffer();
   EthMacIfc mac1 <- mkEthMac(defaultClock, txClock, rxClock, txReset);
   EthMacIfc mac2 <- mkEthMac(defaultClock, txClock, rxClock, txReset);

   SyncFIFOIfc#(Bit#(72)) lpbk_fifo1 <- mkSyncFIFO(5, txClock, txReset, rxClock);
   SyncFIFOIfc#(Bit#(72)) lpbk_fifo2 <- mkSyncFIFO(5, txClock, txReset, rxClock);

   SyncFIFOIfc#(PacketDataT#(Bit#(64))) tx_fifo <- mkSyncFIFO(5, defaultClock, defaultReset, txClock);

   rule every1;
      cycle <= cycle + 1;
   endrule

   rule tx_mac1;
      let v = mac1.tx;
      lpbk_fifo1.enq(v);
   endrule

   rule tx_mac2;
      let v = mac2.tx;
      lpbk_fifo2.enq(v);
   endrule

   rule rx_mac1;
      let v <- toGet(lpbk_fifo2).get;
      mac1.rx(v);
   endrule

   rule rx_mac2;
      let v <- toGet(lpbk_fifo1).get;
      mac2.rx(v);
   endrule

   rule readDataStart;
      let pktLen <- buff.readServer.readLen.get;
      if (verbose) $display(fshow(" read packt ") + fshow(pktLen));
      buff.readServer.readReq.put(EtherReq{len: truncate(pktLen)});
   endrule

   rule readDataInProgress;
      let v <- buff.readServer.readData.get;
      tx_fifo.enq(PacketDataT{d: v.data[63:0], sop: pack(v.sop), eop: pack(v.eop)});
//      if (v.eop) begin
//         indication.done(0);
//      end
   endrule

   rule tx_packet;
      let v <- toGet(tx_fifo).get;
      if (verbose) $display("tx data %h", v.d);
      mac1.packet_tx.put(v);
   endrule

   rule rx_packet;
      let v <- mac2.packet_rx.get();
      $display("rx data %h", v.d);
   endrule

   interface TestRequest request;
      method Action writePacketData(Vector#(2, Bit#(64)) data, Bit#(1) sop, Bit#(1) eop);
         EtherData beat = defaultValue;
         beat.data = pack(reverse(data));
         beat.sop = unpack(sop);
         beat.eop = unpack(eop);
         buff.writeServer.writeData.put(beat);
      endmethod
   endinterface
endmodule

