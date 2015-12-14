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

   Reg#(Bit#(32)) cycle <- mkReg(0);

   FIFOF#(Bit#(72)) write_data <- mkFIFOF;
   PacketBuffer buff <- mkPacketBuffer();

   EthMacIfc macs <- mkEthMac(defaultClock, txClock, replicate(rxClock), txReset);

   rule every1;
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
      Bit#(72) xgmii = {v.data[99:64], v.data[35:0]};
      write_data.enq(xgmii);
      if (v.eop) begin
         indication.done(0);
      end
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

