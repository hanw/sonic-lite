import FIFO::*;
import FIFOF::*;
import Vector::*;
import Clocks::*;
import SpecialFIFOs::*;
import DefaultValue::*;
import ClientServer::*;
import BuildVector::*;

import Ethernet::*;
import PacketBuffer::*;
import StoreAndForward::*;
import GetPut::*;
import DbgTypes::*;

interface TestIndication;
   method Action read_version_resp(Bit#(32) version);
   method Action read_txpktbuf_debug_resp(Bit#(8) port_no, Bit#(64) sop_enq, Bit#(64) sop_deq, Bit#(64) eop_enq, Bit#(64) eop_deq);
   method Action read_rxpktbuf_debug_resp(Bit#(8) port_no, Bit#(64) sop_enq, Bit#(64) sop_deq, Bit#(64) eop_enq, Bit#(64) eop_deq);
   method Action read_ring2mac_debug_resp(Bit#(8) port_no, Bit#(64) bytes, Bit#(64) starts, Bit#(64) ends, Bit#(64) errorframes, Bit#(64) frames);
   method Action read_mac2ring_debug_resp(Bit#(8) port_no, Bit#(64) bytes, Bit#(64) starts, Bit#(64) ends, Bit#(64) errorframes, Bit#(64) frames);
endinterface

interface TestRequest;
   method Action read_txpktbuf_debug(Bit#(8) port_no);
   method Action read_rxpktbuf_debug(Bit#(8) port_no);
   method Action read_ring2mac_debug(Bit#(8) port_no);
   method Action read_mac2ring_debug(Bit#(8) port_no);
endinterface

interface TestAPI;
   interface TestRequest request;
endinterface

module mkTestAPI#(TestIndication indication, Vector#(4, PacketBuffer) txPktbuf, Vector#(4, PacketBuffer) rxPktbuf, Vector#(4, StoreAndFwdFromRingToMac) ringToMac, Vector#(4, StoreAndFwdFromMacToRing) macToRing, Clock txClock, Reset txReset, Clock rxClock, Reset rxReset)(TestAPI);
   Clock defaultClock <- exposeCurrentClock();
   FIFO#(Tuple2#(Bit#(32), Bit#(32))) startReqFifo <- mkFIFO;
   FIFO#(Bit#(1)) stopReqFifo <- mkFIFO;
   FIFO#(ByteStream#(16)) etherDataFifo <- mkFIFO;

   Vector#(4, SyncFIFOIfc#(PktBuffDbgRec)) txPktBuffDbgFifo <- replicateM(mkSyncFIFO(8, txClock, txReset, defaultClock));
   Vector#(4, Reg#(PktBuffDbgRec)) txPktbufDbg <- replicateM(mkRegU);

   Vector#(4, SyncFIFOIfc#(PktBuffDbgRec)) rxPktBuffDbgFifo <- replicateM(mkSyncFIFO(8, txClock, txReset, defaultClock));
   Vector#(4, Reg#(PktBuffDbgRec)) rxPktbufDbg <- replicateM(mkRegU);

   Vector#(4, SyncFIFOIfc#(ThruDbgRec)) ring2MacDbgFifo <- replicateM(mkSyncFIFO(8, txClock, txReset, defaultClock));
   Vector#(4, Reg#(ThruDbgRec)) ring2MacDbg <- replicateM(mkRegU);

   Vector#(4, SyncFIFOIfc#(ThruDbgRec)) mac2RingDbgFifo <- replicateM(mkSyncFIFO(8, rxClock, rxReset, defaultClock));
   //Vector#(4, SyncFIFOIfc#(ThruDbgRec)) mac2RingDbgFifo <- replicateM(mkSyncFIFO(8, txClock, txReset, defaultClock));
   Vector#(4, Reg#(ThruDbgRec)) mac2RingDbg <- replicateM(mkRegU);

   for (Integer i =0 ; i < 4 ; i = i+1) begin
      rule read_txpktbuf_debug;
         let v = txPktbuf[i].dbg();
         txPktBuffDbgFifo[i].enq(v);
      endrule

      rule snapshot_txpktbuf_debug;
         let v <- toGet(txPktBuffDbgFifo[i]).get;
         txPktbufDbg[i] <= v;
      endrule

      rule read_rxpktbuf_debug;
         let v = rxPktbuf[i].dbg();
         rxPktBuffDbgFifo[i].enq(v);
      endrule

      rule snapshot_rxpktbuf_debug;
         let v <- toGet(rxPktBuffDbgFifo[i]).get;
         rxPktbufDbg[i] <= v;
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

   interface TestRequest request;
      method Action read_txpktbuf_debug(Bit#(8) port_no);
         if (port_no < 4) begin
            indication.read_txpktbuf_debug_resp(port_no, txPktbufDbg[port_no].sopEnq, txPktbufDbg[port_no].sopDeq, txPktbufDbg[port_no].eopEnq, txPktbufDbg[port_no].eopDeq);
         end
      endmethod
      method Action read_rxpktbuf_debug(Bit#(8) port_no);
         if (port_no < 4) begin
            indication.read_rxpktbuf_debug_resp(port_no, rxPktbufDbg[port_no].sopEnq, rxPktbufDbg[port_no].sopDeq, rxPktbufDbg[port_no].eopEnq, rxPktbufDbg[port_no].eopDeq);
         end
      endmethod
      method Action read_ring2mac_debug(Bit#(8) port_no);
         if (port_no < 4) begin
            indication.read_ring2mac_debug_resp(port_no, ring2MacDbg[port_no].data_bytes, ring2MacDbg[port_no].sops, ring2MacDbg[port_no].eops, ring2MacDbg[port_no].idle_cycles, ring2MacDbg[port_no].total_cycles);
         end
      endmethod
      method Action read_mac2ring_debug(Bit#(8) port_no);
         if (port_no < 4) begin
            indication.read_mac2ring_debug_resp(port_no, mac2RingDbg[port_no].data_bytes, mac2RingDbg[port_no].sops, mac2RingDbg[port_no].eops, mac2RingDbg[port_no].idle_cycles, mac2RingDbg[port_no].total_cycles);
         end
      endmethod
   endinterface
endmodule
