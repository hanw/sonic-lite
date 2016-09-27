import FIFO::*;
import Vector::*;
import DefaultValue::*;
import ClientServer::*;

import PktGen::*;
import Ethernet::*;
import PacketBuffer::*;
import GetPut::*;

interface DtpPktGenIndication;
   method Action read_version_resp(Bit#(32) version);
endinterface

interface DtpPktGenRequest;
   method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
   method Action start(Bit#(32) iter, Bit#(32) ipg);
   method Action stop();
endinterface

interface DtpPktGenAPI;
   interface DtpPktGenRequest request;
   interface Get#(Tuple2#(Bit#(32), Bit#(32))) pktGenStart;
   interface Get#(Bit#(1)) pktGenStop;
   interface Get#(ByteStream#(16)) pktGenWrite;
endinterface

module mkDtpPktGenAPI#(DtpPktGenIndication indication, PktGen pktgen)(DtpPktGenAPI);
   FIFO#(Tuple2#(Bit#(32), Bit#(32))) startReqFifo <- mkFIFO;
   FIFO#(Bit#(1)) stopReqFifo <- mkFIFO;
   FIFO#(ByteStream#(16)) etherDataFifo <- mkFIFO;

   interface DtpPktGenRequest request;
      method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
         ByteStream#(16) beat = defaultValue;
         beat.data = pack(reverse(data));
         beat.mask = pack(reverse(mask));
         beat.sop = unpack(sop);
         beat.eop = unpack(eop);
         etherDataFifo.enq(beat);
      endmethod
      method Action start(Bit#(32) pktCount, Bit#(32) ipg);
         startReqFifo.enq(tuple2(pktCount, ipg));
      endmethod
      method Action stop();
         stopReqFifo.enq(?);
      endmethod
   endinterface
   interface pktGenStart = toGet(startReqFifo);
   interface pktGenStop = toGet(stopReqFifo);
   interface pktGenWrite = toGet(etherDataFifo);

endmodule
