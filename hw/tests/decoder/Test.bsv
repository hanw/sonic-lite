import FIFO::*;
import FIFOF::*;
import DefaultValue::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;
import Connectable::*;

import Pipe::*;
import MemTypes::*;
import Ethernet::*;
import PacketBuffer::*;
import Decoder::*;

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
   Reg#(Bit#(32)) cycle <- mkReg(0);
   FIFOF#(Bit#(66)) write_data <- mkFIFOF;
   PacketBuffer buff <- mkPacketBuffer();
   Decoder sc <- mkDecoder;
   mkConnection(toPipeOut(write_data), sc.decoderIn);

   rule every1;
      cycle <= cycle + 1;
      sc.rx_ready(True);
   endrule

   rule readDataStart;
      let pktLen <- buff.readServer.readLen.get;
      if (verbose) $display(fshow(" read packt ") + fshow(pktLen));
      buff.readServer.readReq.put(EtherReq{len: truncate(pktLen)});
   endrule

   rule readDataInProgress;
      let v <- buff.readServer.readData.get;
      if(verbose) $display("%d: mkTest.write_data v=%h", cycle, v);
      write_data.enq(v.data[65:0]);
      if (v.eop) begin
         indication.done(0);
      end
   endrule

   rule out;
      Vector#(8, Bit#(8)) txd;
      Vector#(8, Bit#(1)) txc;
      Bit#(64) xgmii_txd;
      Bit#(8)  xgmii_txc;

      let v = sc.decoderOut.first();
      sc.decoderOut.deq;
      //if(verbose) $display("%d: decoder out v=%h", cycle, v);

      for (Integer i=0; i<8; i=i+1) begin
         txd[i] = v[9*i+7 : 9*i];
         txc[i] = v[9*i+8];
      end
      xgmii_txd = pack(txd);
      xgmii_txc = pack(txc);

      if(verbose) $display("%d: xgmii_txd=%h, txc=%h", cycle, xgmii_txd, xgmii_txc);
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

