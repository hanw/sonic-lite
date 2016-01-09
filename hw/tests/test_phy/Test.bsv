import FIFO::*;
import FIFOF::*;
import DefaultValue::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;
import Connectable::*;

import Pipe::*;
import MemTypes::*;

import EthPhy ::*;
import Ethernet ::*;
import Encoder ::*;
import Decoder ::*;
import Scrambler ::*;
import Descrambler ::*;
import PacketBuffer ::*;

interface TestIndication;
   method Action done(Bit#(32) matchCount);
endinterface

interface TestRequest;
   method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
endinterface

interface Test;
   interface TestRequest request;
endinterface

typedef 5 Delay; //one-way delay
Integer delay = valueOf(Delay);

module mkTest#(TestIndication indication) (Test);

   let verbose = True;
   FIFOF#(Bit#(72)) write_data1 <- mkFIFOF;
   FIFOF#(Bit#(72)) write_data2 <- mkFIFOF;

   PacketBuffer buff1 <- mkPacketBuffer();
   PacketBuffer buff2 <- mkPacketBuffer();
   Vector#(Delay, FIFOF#(Bit#(66))) fifo_sc1_to_sc2 <- replicateM(mkFIFOF);
   Vector#(Delay, FIFOF#(Bit#(66))) fifo_sc2_to_sc1 <- replicateM(mkFIFOF);

   EthPhy sc1 <- mkEthPhy(toPipeOut(write_data1), toPipeOut(fifo_sc2_to_sc1[delay-1]), 0, 100);
   EthPhy sc2 <- mkEthPhy(toPipeOut(write_data2), toPipeOut(fifo_sc1_to_sc2[delay-1]), 1, 200);

   rule init;
      let sc1_out = sc1.scramblerOut.first;
      sc1.scramblerOut.deq;
      let sc2_out = sc2.scramblerOut.first;
      sc2.scramblerOut.deq;
      fifo_sc1_to_sc2[0].enq(sc1_out);
      fifo_sc2_to_sc1[0].enq(sc2_out);
   endrule

   Vector#(Delay, Reg#(Bit#(66))) sc1_wires <- replicateM(mkReg(0));
   Vector#(Delay, Reg#(Bit#(66))) sc2_wires <- replicateM(mkReg(0));
   for (Integer i=0; i<delay-1; i=i+1) begin
      rule connect;
            sc1_wires[i] <= fifo_sc1_to_sc2[i].first;
            sc2_wires[i] <= fifo_sc2_to_sc1[i].first;
            fifo_sc1_to_sc2[i].deq;
            fifo_sc2_to_sc1[i].deq;
            fifo_sc1_to_sc2[i+1].enq(sc1_wires[i]);
            fifo_sc2_to_sc1[i+1].enq(sc2_wires[i]);
      endrule
   end

   rule cyc;
      cycle <= cycle + 1;
   endrule

   rule readDataStart;
      let pktLen <- buff.readServer.readLen.get;
      if (verbose) $display(fshow(" read packt ") + fshow(pktLen));
      buff.readServer.readReq.put(EtherReq{len: truncate(pktLen)});
   endrule

   rule readDataInProgress;
      let v <- buff.readServer.readData.get;
      if(verbose) $display("%d: mkTest.write_data v=%h", cycle, v);
      write_data1.enq(v.data[35:0]);
      write_data2.enq(v.data[35:0]);
      if (v.eop) begin
         indication.done(0);
      end
   endrule

//   rule data;
//      Bit#(72) xgmii;
//      xgmii = {v[227:192], v[163:128]};
//      write_data1.enq(xgmii);
//      write_data2.enq(xgmii);
//      if(verbose) $display("%d: xgmiiIn v=%h", cycle, xgmii);
//   endrule

   rule rxout;
      let v1 = sc1.decoderOut.first();
      sc1.decoderOut.deq;
      let v2 = sc2.decoderOut.first();
      sc2.decoderOut.deq;
      if(verbose) $display("%d: decoderOut v=%h", cycle, v1);
      if(verbose) $display("%d: decoderOut v=%h", cycle, v2);
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
endmodule

