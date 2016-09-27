import FIFO::*;
import FIFOF::*;
import DefaultValue::*;
import Vector::*;
import BuildVector::*;
import GetPut::*;
import ClientServer::*;
import Connectable::*;
import Clocks::*;
import Gearbox::*;

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
   method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
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
   Gearbox#(2, 1, PacketDataT#(64)) fifoTxData <- mkNto1Gearbox(txClock, txReset, txClock, txReset);

   PacketBuffer buff <- mkPacketBuffer();
   EthMacIfc mac1 <- mkEthMac(defaultClock, txClock, rxClock, txReset);
   EthMacIfc mac2 <- mkEthMac(defaultClock, txClock, rxClock, txReset);

   SyncFIFOIfc#(Bit#(72)) lpbk_fifo1 <- mkSyncFIFO(5, txClock, txReset, rxClock);
   SyncFIFOIfc#(Bit#(72)) lpbk_fifo2 <- mkSyncFIFO(5, txClock, txReset, rxClock);

   SyncFIFOIfc#(ByteStream#(16)) tx_fifo <- mkSyncFIFO(5, defaultClock, defaultReset, txClock);

   rule every1;
      cycle <= cycle + 1;
   endrule

   rule tx_mac1;
      let v <- mac1.tx.get;
      lpbk_fifo1.enq(v);
   endrule

   rule tx_mac2;
      let v <- mac2.tx.get;
      lpbk_fifo2.enq(v);
   endrule

   rule rx_mac1;
      let v <- toGet(lpbk_fifo2).get;
      mac1.rx.put(v);
   endrule

   rule rx_mac2;
      let v <- toGet(lpbk_fifo1).get;
      mac2.rx.put(v);
   endrule

   rule readDataStart;
      let pktLen <- buff.readServer.readLen.get;
      if (verbose) $display(fshow(" read packt ") + fshow(pktLen));
      buff.readServer.readReq.put(EtherReq{len: truncate(pktLen)});
   endrule

   function Vector#(2, PacketDataT#(64)) split(ByteStream#(16) in);
      Vector#(2, PacketDataT#(64)) v = defaultValue;
      Vector#(8, Bit#(8)) v0_data = unpack(in.data[63:0]);
      Vector#(8, Bit#(8)) v1_data = unpack(in.data[127:64]);
      v[0].sop = pack(in.sop);
      v[0].data = pack(reverse(v0_data)); //in.data[63:0];
      v[0].eop = (in.mask[15:8] == 0) ? pack(in.eop) : 0;
      v[0].mask = in.mask[7:0];
      v[1].sop = 0;
      v[1].data = pack(reverse(v1_data)); //in.data[127:64];
      v[1].eop = pack(in.eop);
      v[1].mask = in.mask[15:8];
      return v;
   endfunction

   rule cross_clocking;
      let v <- buff.readServer.readData.get;
      tx_fifo.enq(v);
   endrule

   rule process_incoming_packet;
      let v <- toGet(tx_fifo).get;
      fifoTxData.enq(split(v));
   endrule

   rule process_outgoing_packet;
      let data = fifoTxData.first; fifoTxData.deq;
      let temp = head(data);
      if (temp.mask != 0) begin
         if (verbose) $display("tx data %h", temp.data);
         mac1.packet_tx.put(temp);
      end
   endrule

   rule rx_packet;
      let v <- mac2.packet_rx.get();
      $display("rx data %h", v.data);
   endrule

   interface TestRequest request;
      method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
         ByteStream#(16) beat = defaultValue;
         beat.data = pack(reverse(data));
         beat.mask = pack(reverse(mask));
         beat.sop = unpack(sop);
         beat.eop = unpack(eop);
         buff.writeServer.writeData.put(beat);
      endmethod
   endinterface
endmodule

