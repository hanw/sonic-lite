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
   method Action clear();
endinterface

module mkDtpPktGenAPI#(DtpPktGenIndication indication, PktGen pktgen)(DtpPktGenRequest);
   method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
      EtherData beat = defaultValue;
      beat.data = pack(reverse(data));
      beat.mask = pack(reverse(mask));
      beat.sop = unpack(sop);
      beat.eop = unpack(eop);
      pktgen.writeServer.writeData.put(beat);
   endmethod
   method start = pktgen.start;
   method stop = pktgen.stop;
   method clear = pktgen.clear;
endmodule

