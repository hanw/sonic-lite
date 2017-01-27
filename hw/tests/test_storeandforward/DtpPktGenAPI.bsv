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
import PacketBuffer::*;
import StoreAndForward::*;
import GetPut::*;
import DbgTypes::*;

interface DtpPktGenIndication;
   method Action read_version_resp(Bit#(32) version);
   method Action read_pktbuf_debug_resp(Bit#(8) port_no, Bit#(64) sop_enq, Bit#(64) sop_deq, Bit#(64) eop_enq, Bit#(64) eop_deq);
   method Action read_ring2mac_debug_resp(Bit#(8) port_no, Bit#(64) bytes, Bit#(64) starts, Bit#(64) ends, Bit#(64) errorframes, Bit#(64) frames);
   method Action read_mac2ring_debug_resp(Bit#(8) port_no, Bit#(64) bytes, Bit#(64) starts, Bit#(64) ends, Bit#(64) errorframes, Bit#(64) frames);
endinterface

interface DtpPktGenRequest;
   method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
   method Action start(Bit#(32) iter, Bit#(32) ipg);
   method Action stop();
   method Action read_pktbuf_debug(Bit#(8) port_no);
   method Action read_ring2mac_debug(Bit#(8) port_no);
   method Action read_mac2ring_debug(Bit#(8) port_no);
endinterface

interface DtpPktGenAPI;
   interface DtpPktGenRequest request;
   interface Get#(Tuple2#(Bit#(32), Bit#(32))) pktGenStart;
   interface Get#(Bit#(1)) pktGenStop;
   interface Get#(ByteStream#(16)) pktGenWrite;
endinterface

module mkDtpPktGenAPI#(DtpPktGenIndication indication, PktGen pktgen, Vector#(3, PacketBuffer) pktbuf, Vector#(3, StoreAndFwdFromRingToMac) ringToMac, Vector#(3, StoreAndFwdFromMacToRing) macToRing, Clock txClock, Reset txReset)(DtpPktGenAPI);
   Clock defaultClock <- exposeCurrentClock();
   FIFO#(Tuple2#(Bit#(32), Bit#(32))) startReqFifo <- mkFIFO;
   FIFO#(Bit#(1)) stopReqFifo <- mkFIFO;
   FIFO#(ByteStream#(16)) etherDataFifo <- mkFIFO;

   Vector#(4, SyncFIFOIfc#(PktBuffDbgRec)) pktBuffDbgFifo <- replicateM(mkSyncFIFO(8, txClock, txReset, defaultClock));
   Vector#(4, Reg#(PktBuffDbgRec)) pktbufDbg <- replicateM(mkRegU);

   Vector#(4, SyncFIFOIfc#(ThruDbgRec)) ring2MacDbgFifo <- replicateM(mkSyncFIFO(8, txClock, txReset, defaultClock));
   Vector#(4, Reg#(ThruDbgRec)) ring2MacDbg <- replicateM(mkRegU);

   Vector#(4, SyncFIFOIfc#(ThruDbgRec)) mac2RingDbgFifo <- replicateM(mkSyncFIFO(8, txClock, txReset, defaultClock));
   Vector#(4, Reg#(ThruDbgRec)) mac2RingDbg <- replicateM(mkRegU);

   for (Integer i =0 ; i < 3 ; i = i+1) begin
      rule read_pktbuf_debug;
         let v = pktbuf[i].dbg();
         pktBuffDbgFifo[i].enq(v);
      endrule

      rule snapshot_pktbuf_debug;
         let v <- toGet(pktBuffDbgFifo[i]).get;
         pktbufDbg[i] <= v;
      endrule

      rule read_ring2Mac_debug;
         let v = ringToMac[i].sdbg();
         ring2MacDbgFifo[i].enq(v);
      endrule

      rule snapshot_ring2Mac_debug;
         let v <- toGet(ring2MacDbgFifo[i]).get;
         ring2MacDbg[i] <= v;
      endrule

      rule read_mac2Ring_debug;
         let v = macToRing[i].sdbg();
         mac2RingDbgFifo[i].enq(v);
      endrule

      rule snapshot_mac2Ring_debug;
         let v <- toGet(mac2RingDbgFifo[i]).get;
         mac2RingDbg[i] <= v;
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
         if (port_no < 3) begin
            indication.read_pktbuf_debug_resp(port_no, pktbufDbg[port_no].sopEnq, pktbufDbg[port_no].sopDeq, pktbufDbg[port_no].eopEnq, pktbufDbg[port_no].eopDeq);
         end
      endmethod
      method Action read_ring2mac_debug(Bit#(8) port_no);
         if (port_no < 3) begin
            indication.read_ring2mac_debug_resp(port_no, ring2MacDbg[port_no].data_bytes, ring2MacDbg[port_no].sops, ring2MacDbg[port_no].eops, ring2MacDbg[port_no].idle_cycles, ring2MacDbg[port_no].total_cycles);
         end
      endmethod
      method Action read_mac2ring_debug(Bit#(8) port_no);
         if (port_no < 3) begin
            indication.read_mac2ring_debug_resp(port_no, mac2RingDbg[port_no].data_bytes, mac2RingDbg[port_no].sops, mac2RingDbg[port_no].eops, mac2RingDbg[port_no].idle_cycles, mac2RingDbg[port_no].total_cycles);
         end
      endmethod
   endinterface
   interface pktGenStart = toGet(startReqFifo);
   interface pktGenStop = toGet(stopReqFifo);
   interface pktGenWrite = toGet(etherDataFifo);
endmodule
