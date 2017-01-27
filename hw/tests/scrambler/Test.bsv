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
import Scrambler::*;

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
   Reg#(Bit#(32)) cycle <- mkReg(0);
   FIFOF#(Bit#(66)) write_data <- mkFIFOF;
   PacketBuffer buff <- mkPacketBuffer();
   Scrambler sc <- mkScrambler;
   mkConnection(toPipeOut(write_data), sc.scramblerIn);

   rule every1;
      cycle <= cycle + 1;
      sc.tx_ready(True);
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
      let v = sc.scrambledOut.first();
      sc.scrambledOut.deq;
      if(verbose) $display("%d: scrambled out v=%h", cycle, v);
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

