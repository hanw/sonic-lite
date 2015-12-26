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
import AlteraEthPhy::*;
import DE5Pins::*;

interface TestIndication;
   method Action done(Bit#(32) matchCount);
endinterface

interface TestRequest;
   method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
endinterface

interface Test;
   interface TestRequest request;
   interface `PinType pins;
endinterface

module mkTest#(TestIndication indication) (Test);
   let verbose = True;
   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

   Wire#(Bit#(1)) clk_644_wire <- mkDWire(0);
   Wire#(Bit#(1)) clk_50_wire <- mkDWire(0);
   De5Clocks clocks <- mkDe5Clocks(clk_50_wire, clk_644_wire);

   Clock txClock = clocks.clock_156_25;
   Clock phyClock = clocks.clock_644_53;
   Reset txReset <- mkSyncReset(2, defaultReset, txClock);
   Reset phyReset <- mkSyncReset(2, defaultReset, phyClock);

   Reg#(Bit#(32)) cycle <- mkReg(0, clocked_by txClock, reset_by txReset);

   Gearbox#(2, 1, PacketDataT#(64)) fifoTxData <- mkNto1Gearbox(txClock, txReset, txClock, txReset);

   PacketBuffer buff <- mkPacketBuffer();
   EthPhyIfc phys <- mkAlteraEthPhy(defaultClock, phyClock, txClock, defaultReset);
   Clock rxClock = phys.rx_clkout;
   Reset rxReset <- mkSyncReset(2, defaultReset, rxClock);

   Vector#(4, EthMacIfc) mac <- replicateM(mkEthMac(defaultClock, txClock, rxClock, txReset));

   SyncFIFOIfc#(EtherData) tx_fifo <- mkSyncFIFO(5, defaultClock, defaultReset, txClock);

   rule every1;
      cycle <= cycle + 1;
   endrule

   for (Integer i=0; i<4; i=i+1) begin
      rule connectMacToPhy;
         let v = mac[i].tx;
         phys.tx[i].put(v);
      endrule
      rule connectPhyToMac;
         let v <- phys.rx[i].get;
         mac[i].rx(v);
      endrule
   end

   rule readDataStart;
      let pktLen <- buff.readServer.readLen.get;
      if (verbose) $display(fshow(" read packt ") + fshow(pktLen));
      buff.readServer.readReq.put(EtherReq{len: truncate(pktLen)});
   endrule

   function Vector#(2, PacketDataT#(64)) split(EtherData in);
      Vector#(2, PacketDataT#(64)) v = defaultValue;
      Vector#(8, Bit#(8)) v0_data = unpack(in.data[63:0]);
      Vector#(8, Bit#(8)) v1_data = unpack(in.data[127:64]);
      v[0].sop = pack(in.sop);
      v[0].data = pack(reverse(v0_data));
      v[0].eop = (in.mask[15:8] == 0) ? pack(in.eop) : 0;
      v[0].mask = in.mask[7:0];
      v[1].sop = 0;
      v[1].data = pack(reverse(v1_data));
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
         mac[0].packet_tx.put(temp);
      end
   endrule

   rule rx_packet;
      let v <- mac[1].packet_rx.get();
      $display("rx data %h", v.data);
   endrule

   interface TestRequest request;
      method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
         EtherData beat = defaultValue;
         beat.data = pack(reverse(data));
         beat.mask = pack(reverse(mask));
         beat.sop = unpack(sop);
         beat.eop = unpack(eop);
         buff.writeServer.writeData.put(beat);
      endmethod
   endinterface
   interface `PinType pins;
      method Action osc_50(Bit#(1) b3d, Bit#(1) b4a, Bit#(1) b4d, Bit#(1) b7a, Bit#(1) b7d, Bit#(1) b8a, Bit#(1) b8d);
         clk_50_wire <= b4a;
      endmethod
      method serial_tx_data = phys.serial.tx;
      method serial_rx = phys.serial.rx;
      method Action sfp(Bit#(1) refclk);
         clk_644_wire <= refclk;
      endmethod
      interface i2c = clocks.i2c;
      interface deleteme_unused_clock = defaultClock;
      interface deleteme_unused_clock2 = clocks.clock_50;
      interface deleteme_unused_clock3 = defaultClock;
      interface deleteme_unused_reset = defaultReset;
   endinterface
endmodule

