import FIFO::*;
import FIFOF::*;
import Vector::*;
import Clocks::*;
import SpecialFIFOs::*;
import DefaultValue::*;
import ClientServer::*;
import BuildVector::*;

import PktGen::*;
import Ethernet::*;
import Stream::*;
import PacketBuffer::*;
import GetPut::*;
import DbgTypes::*;

interface DtpPktGenIndication;
   method Action read_version_resp(Bit#(32) version);
   method Action read_pktbuf_debug_resp(Bit#(8) port_no, Bit#(64) sop_enq, Bit#(64) sop_deq, Bit#(64) eop_enq, Bit#(64) eop_deq);
endinterface

interface DtpPktGenRequest;
   method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
   method Action start(Bit#(32) iter, Bit#(32) ipg);
   method Action stop();
   method Action read_pktbuf_debug(Bit#(8) port_no);
endinterface

interface DtpPktGenAPI;
   interface DtpPktGenRequest request;
   interface Get#(Tuple2#(Bit#(32), Bit#(32))) pktGenStart;
   interface Get#(Bit#(1)) pktGenStop;
   interface Get#(ByteStream#(16)) pktGenWrite;
endinterface

module mkDtpPktGenAPI#(DtpPktGenIndication indication, PktGen pktgen, Vector#(4, PacketBuffer) pktbuf, Clock txClock, Reset txReset)(DtpPktGenAPI);
   Clock defaultClock <- exposeCurrentClock();
   FIFO#(Tuple2#(Bit#(32), Bit#(32))) startReqFifo <- mkFIFO;
   FIFO#(Bit#(1)) stopReqFifo <- mkFIFO;
   FIFO#(ByteStream#(16)) etherDataFifo <- mkFIFO;

   Vector#(4, SyncFIFOIfc#(PktBuffDbgRec)) pktBuffDbgFifo <- replicateM(mkSyncFIFO(8, txClock, txReset, defaultClock));
   Vector#(4, Reg#(Bit#(64))) pktbuf_sop_enq <- replicateM(mkReg(0));
   Vector#(4, Reg#(Bit#(64))) pktbuf_sop_deq <- replicateM(mkReg(0));
   Vector#(4, Reg#(Bit#(64))) pktbuf_eop_enq <- replicateM(mkReg(0));
   Vector#(4, Reg#(Bit#(64))) pktbuf_eop_deq <- replicateM(mkReg(0));

   for (Integer i =0 ; i < 4 ; i = i+1) begin
      rule read_pktbuf_debug;
         let v = pktbuf[i].dbg();
         pktBuffDbgFifo[i].enq(v);
      endrule

      rule snapshot_pktbuf_debug;
         let v <- toGet(pktBuffDbgFifo[i]).get;
         pktbuf_sop_enq[i] <= v.sopEnq;
         pktbuf_sop_deq[i] <= v.sopDeq;
         pktbuf_eop_enq[i] <= v.eopEnq;
         pktbuf_eop_deq[i] <= v.eopDeq;
      endrule
   end

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
      method Action read_pktbuf_debug(Bit#(8) port_no);
         if (port_no < 4) begin
            indication.read_pktbuf_debug_resp(port_no, pktbuf_sop_enq[port_no], pktbuf_sop_deq[port_no], pktbuf_eop_enq[port_no], pktbuf_eop_deq[port_no]);
         end
      endmethod
   endinterface
   interface pktGenStart = toGet(startReqFifo);
   interface pktGenStop = toGet(stopReqFifo);
   interface pktGenWrite = toGet(etherDataFifo);
endmodule
