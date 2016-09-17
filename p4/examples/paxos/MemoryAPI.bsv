// Copyright (c) 2016 Cornell University.

// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import BuildVector::*;
import ClientServer::*;
import Connectable::*;
import ConnectalTypes::*;
import DbgDefs::*;
import DefaultValue::*;
import Deparser::*;
import Ethernet::*;
import GetPut::*;
import HostChannel::*;
import Ingress::*;
import PacketBuffer::*;
import PaxosTypes::*;
import TxChannel::*;
import RxChannel::*;
import PktGenChannel::*;
import PktCapChannel::*;
import Vector::*;
`include "ConnectalProjectConfig.bsv"

interface MemoryTestIndication;
   method Action read_version_resp(Bit#(32) version);
   method Action read_ingress_debug_info_resp(IngressDbgRec rec);
   method Action read_hostchan_debug_info_resp(HostChannelDbgRec rec);
   method Action read_txchan_debug_info_resp(TxChannelDbgRec rec);
   method Action read_rxchan_debug_info_resp(HostChannelDbgRec rec);
   method Action read_role_resp(Role role);
   method Action read_ingress_perf_info_resp(IngressPerfRec rec);
   method Action read_parser_perf_info_resp(ParserPerfRec rec);
   method Action read_pktcap_perf_info_resp(PktCapRec rec);
   method Action read_deparser_perf_info_resp(DeparserPerfRec rec);
   method Action writePacketData(Bit#(64) data, Bit#(8) mask, Bit#(1) sop, Bit#(1) eop);
endinterface

interface MemoryTestRequest;
   method Action read_version();
   method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
   method Action writePktGenData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
   method Action pktgen_start(Bit#(32) iteration, Bit#(32) ipg);
   method Action pktgen_stop();
   method Action pktcap_start(Bit#(32) iteration);
   method Action pktcap_stop();
   method Action role_reg_write(Role r);
   method Action role_reg_read();
   method Action datapath_id_reg_write(Bit#(DatapathSize) datapath);
   method Action instance_reg_write(Bit#(InstanceSize) instance_);
   method Action value_reg_write(Bit#(10) inst, Vector#(8, Bit#(32)) value);
   method Action round_reg_write(Bit#(10) inst, Bit#(RoundSize) round);
   method Action vround_reg_write(Bit#(10) inst, Bit#(RoundSize) round);
   method Action sequenceTable_add_entry(Bit#(16) msgtype, SequenceTblActionT action_);
   method Action acceptorTable_add_entry(Bit#(16) msgtype, AcceptorTblActionT action_);
   //method Action dmacTable_add_entry(Bit#(48) mac, DmacTblActionT action_, Bit#(9) port_);
   method Action dmacTable_add_entry(Bit#(48) mac, Bit#(9) port_);
   method Action read_ingress_debug_info();
   method Action read_hostchan_debug_info();
   method Action read_txchan_debug_info();
   method Action read_rxchan_debug_info();
   method Action read_ingress_perf_info();
   method Action read_parser_perf_info();
   method Action read_pktcap_perf_info();
   method Action read_deparser_perf_info();
   method Action set_verbosity(Bit#(32) v);
endinterface

interface MemoryAPI;
   interface MemoryTestRequest request;
endinterface

module mkMemoryAPI#(MemoryTestIndication indication, HostChannel hostchan, TxChannel txchan, RxChannel rxchan, Ingress ingress, PktGenChannel pktgen, PktCapChannel pktcap)(MemoryAPI);

   rule read_role;
      let v <- toGet(ingress.role_reg_read_resp).get;
      indication.read_role_resp(v);
   endrule

   interface MemoryTestRequest request;
      method Action read_version();
         let v= `NicVersion;
         indication.read_version_resp(v);
      endmethod
      method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
         EtherData beat = defaultValue;
         beat.data = pack(reverse(data));
         beat.mask = pack(reverse(mask));
         beat.sop = unpack(sop);
         beat.eop = unpack(eop);
         hostchan.writeServer.writeData.put(beat);
      endmethod
      method Action writePktGenData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
         EtherData beat = defaultValue;
         beat.data = pack(reverse(data));
         beat.mask = pack(reverse(mask));
         beat.sop = unpack(sop);
         beat.eop = unpack(eop);
         pktgen.writeData.put(beat);
      endmethod
      method pktgen_start = pktgen.start;
      method pktgen_stop = pktgen.stop;
      method pktcap_start = pktcap.start;
      method pktcap_stop = pktgen.stop;
      method value_reg_write = ingress.value_reg_write;
      method round_reg_write = ingress.round_reg_write;
      method role_reg_write = ingress.role_reg_write;
      method role_reg_read = ingress.role_reg_read;
      method datapath_id_reg_write = ingress.datapath_id_reg_write;
      method instance_reg_write = ingress.instance_reg_write;
      method vround_reg_write = ingress.vround_reg_write;
      method sequenceTable_add_entry = ingress.sequenceTable_add_entry;
      method acceptorTable_add_entry = ingress.acceptorTable_add_entry;
      method dmacTable_add_entry = ingress.dmacTable_add_entry;
      method Action read_ingress_debug_info();
         let v = ingress.read_debug_info;
         indication.read_ingress_debug_info_resp(v);
      endmethod
      method Action read_hostchan_debug_info();
         let v = hostchan.read_debug_info;
         indication.read_hostchan_debug_info_resp(v);
      endmethod
      method Action read_txchan_debug_info();
         let v = txchan.read_debug_info;
         indication.read_txchan_debug_info_resp(v);
      endmethod
      method Action read_rxchan_debug_info();
         let v = rxchan.read_debug_info;
         indication.read_rxchan_debug_info_resp(v);
      endmethod
      method Action read_ingress_perf_info();
         let v = ingress.read_perf_info;
         indication.read_ingress_perf_info_resp(v);
      endmethod
      method Action read_parser_perf_info();
         let v = rxchan.read_parser_perf_info;
         indication.read_parser_perf_info_resp(v);
      endmethod
      method Action read_pktcap_perf_info();
         let v = pktcap.read_perf_info;
         indication.read_pktcap_perf_info_resp(v);
      endmethod
      method Action read_deparser_perf_info();
         let v = txchan.read_deparser_perf_info;
         indication.read_deparser_perf_info_resp(v);
      endmethod
      method Action set_verbosity(Bit#(32) verbosity);
         hostchan.set_verbosity(unpack(verbosity));
      endmethod
   endinterface
endmodule
