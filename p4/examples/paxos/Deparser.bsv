// Copyright (c) 2016 Cornell University

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
import ClientServer::*;
import Connectable::*;
import DefaultValue::*;
import DbgDefs::*;
import FIFO::*;
import FIFOF::*;
import FShow::*;
import GetPut::*;
import List::*;
import StmtFSM::*;
import SpecialFIFOs::*;
import Vector::*;
import Pipe::*;
import Ethernet::*;
import PaxosTypes::*;
import PacketBuffer::*;
import P4Types::*;
import Utils::*;

typedef enum {
   StateDeparseIdle,
   StateDeparseEthernet,
   StateDeparseArp,
   StateDeparseIpv4,
   StateDeparseIpv6,
   StateDeparseUdp,
   StateDeparsePaxos
} DeparserState deriving (Bits, Eq, FShow);

function Tuple2#(EthernetT, EthernetT) toEthernet(MetadataT meta);
   EthernetT data = defaultValue;
   EthernetT mask = defaultMask;
   data.dstAddr = fromMaybe(?, meta.dstAddr);
   mask.dstAddr = 0;
   data.etherType = fromMaybe(?, meta.etherType);
   mask.etherType = 0;
   return tuple2(data, mask);
endfunction

function Tuple2#(Ipv4T, Ipv4T) toIpv4(MetadataT meta);
   Ipv4T ipv4 = defaultValue;
   Ipv4T mask = defaultMask;
   ipv4.protocol = fromMaybe(?, meta.protocol);
   mask.protocol = 0;
   return tuple2(ipv4, mask);
endfunction

function Tuple2#(UdpT, UdpT) toUdp(MetadataT meta);
   UdpT udp = defaultValue;
   UdpT mask = defaultMask;
   udp.dstPort = fromMaybe(?, meta.dstPort);
   mask.dstPort = 0;
   udp.checksum = 0;
   mask.checksum = 0;
   return tuple2(udp, mask);
endfunction

function Tuple2#(Ipv6T, Ipv6T) toIpv6(MetadataT meta);
   Ipv6T ipv6 = defaultValue;
   Ipv6T mask = defaultMask;
   return tuple2(ipv6, mask);
endfunction

//
function Tuple2#(PaxosT, PaxosT) toPaxos(MetadataT meta);
   PaxosT paxos = defaultValue;
   PaxosT mask = defaultMask;
   paxos.msgtype = fromMaybe(?, meta.paxos$msgtype);
   mask.msgtype = 0;
   paxos.inst = fromMaybe(?, meta.paxos$inst);
   mask.inst = 0;
   paxos.rnd = fromMaybe(?, meta.paxos$rnd);
   mask.rnd = 0;
   paxos.vrnd = fromMaybe(?, meta.paxos$vrnd);
   mask.vrnd = 0;
   paxos.acptid = fromMaybe(?, meta.paxos$acptid);
   mask.acptid = 0;
   paxos.paxosval = fromMaybe(?, meta.paxos$paxosval);
   mask.paxosval = 0;
   return tuple2(paxos, mask);
endfunction

module mkStateDeparseIdle#(Reg#(DeparserState) state, FIFOF#(EtherData) datain, FIFOF#(EtherData) dataout, Wire#(Bool) start_fsm)(Empty);

   rule load_packet if (state == StateDeparseIdle);
      let v = datain.first;
      if (v.sop) begin
         state <= StateDeparseEthernet;
         start_fsm <= True;
         $display("(%0d) Deparse Ethernet Start", $time);
      end
      else begin
         datain.deq;
         dataout.enq(v);
         $display("(%0d) payload ", $time, fshow(v));
         start_fsm <= False;
      end
   endrule
endmodule

interface DeparseEthernet;
   interface Get#(EtherData) deparse_arp;
   interface Get#(EtherData) deparse_ipv4;
   interface Get#(EtherData) deparse_ipv6;
   method Action start;
   method Action clear;
endinterface

module mkStateDeparseEthernet#(Reg#(DeparserState) state,
                               FIFOF#(EtherData) datain,
                               FIFOF#(EtherData) dataout,
                               FIFOF#(EthernetT) ethernet_meta,
                               FIFOF#(EthernetT) ethernet_mask)
                               (DeparseEthernet);
   let verbose = False;
   Wire#(EtherData) packet_in_wire <- mkDWire(defaultValue);
   FIFO#(EtherData) parse_arp_fifo <- mkFIFO;
   FIFO#(EtherData) parse_ipv4_fifo <- mkFIFO;
   FIFO#(EtherData) parse_ipv6_fifo <- mkFIFO;

   PulseWire start_wire <- mkPulseWire;
   PulseWire clear_wire <- mkPulseWire;

   function DeparserState compute_next_state(Bit#(16) etherType);
       DeparserState nextState = StateDeparseIdle;
       case (byteSwap(etherType)) matches
           'h806: begin
               nextState=StateDeparseArp;
           end
           'h800: begin
               nextState=StateDeparseIpv4;
           end
           'h86dd: begin
               nextState=StateDeparseIpv6;
           end
           default: begin
               nextState=StateDeparseIdle;
           end
       endcase
       return nextState;
   endfunction

   rule load_packet if (state == StateDeparseEthernet);
      let data_current <- toGet(datain).get;
      packet_in_wire <= data_current;
      $display("(%0d) Ether: ", $time, fshow(data_current));
   endrule

   Stmt deparse_ethernet =
   seq
   action
      let data_this_cycle = packet_in_wire;
      let metadata = ethernet_meta.first;
      let mask = ethernet_mask.first;
      Vector#(128, Bit#(1)) dataVec = unpack(data_this_cycle.data);
      Vector#(112, Bit#(1)) hdr = takeAt(0, dataVec);
      Vector#(16, Bit#(1)) unchanged = takeAt(112, dataVec);
      EthernetT ethernet = unpack(pack(hdr));
      let nextState = compute_next_state(metadata.etherType);
      if (verbose) $display("(%0d) Eth: %h", $time, metadata.etherType);
      if (verbose) $display("(%0d) Goto ", $time, fshow(nextState));
      data_this_cycle.data = {pack(unchanged), pack(hdr)};
      if (nextState == StateDeparseArp) begin
         parse_arp_fifo.enq(data_this_cycle);
      end
      else if (nextState == StateDeparseIpv4) begin
         parse_ipv4_fifo.enq(data_this_cycle);
      end
      else if (nextState == StateDeparseIpv6) begin
         parse_ipv6_fifo.enq(data_this_cycle);
      end
      state <= nextState;
      ethernet_meta.deq;
      ethernet_mask.deq;
   endaction
   endseq;

   FSM fsm_deparse_ethernet <- mkFSM(deparse_ethernet);
   rule start_fsm if (start_wire);
      fsm_deparse_ethernet.start;
   endrule
   rule clear_fsm if (clear_wire);
      fsm_deparse_ethernet.abort;
   endrule
   method Action start();
      start_wire.send();
   endmethod
   method Action clear();
      clear_wire.send();
   endmethod
   interface deparse_arp = toGet(parse_arp_fifo);
   interface deparse_ipv4 = toGet(parse_ipv4_fifo);
   interface deparse_ipv6 = toGet(parse_ipv6_fifo);
endmodule

interface DeparseIpv4;
   interface Put#(EtherData) deparse_ethernet;
   interface Get#(EtherData) deparse_udp;
   method Action start;
   method Action clear;
endinterface
module mkStateDeparseIpv4#(Reg#(DeparserState) state,
                           FIFOF#(EtherData) datain,
                           FIFOF#(EtherData) dataout,
                           FIFOF#(Ipv4T) ipv4_meta,
                           FIFOF#(Ipv4T) ipv4_mask)
                           (DeparseIpv4);

   Wire#(EtherData) packet_in_wire <- mkDWire(defaultValue);
   FIFOF#(EtherData) deparse_ethernet_fifo <- mkBypassFIFOF;
   FIFO#(EtherData) deparse_udp_fifo <- mkFIFO;
   PulseWire start_wire <- mkPulseWire();
   PulseWire clear_wire <- mkPulseWire();

   function DeparserState compute_next_state(Bit#(8) protocol);
       DeparserState nextState = StateDeparseIdle;
       case (byteSwap(protocol)) matches
           'h11: begin
               nextState=StateDeparseUdp;
           end
           default: begin
               nextState=StateDeparseIdle;
           end
       endcase
       return nextState;
   endfunction

   rule load_packet if (state == StateDeparseIpv4 && !deparse_ethernet_fifo.notEmpty());
       let data_current <- toGet(datain).get;
       packet_in_wire <= data_current;
       $display("(%0d) IPv4: ", $time, fshow(data_current));
   endrule

   Stmt deparse_ipv4 = 
   seq
   action
      let data_this_cycle <- toGet(deparse_ethernet_fifo).get;
      Vector#(112, Bit#(1)) last_data = takeAt(0, unpack(data_this_cycle.data));
      Vector#(16, Bit#(1)) data = takeAt(112, unpack(data_this_cycle.data));
      Vector#(16, Bit#(1)) curr_meta = takeAt(0, unpack(byteSwap(pack(ipv4_meta.first))));
      Vector#(16, Bit#(1)) curr_mask = takeAt(0, unpack(byteSwap(pack(ipv4_mask.first))));
      let masked_data = pack(data) & pack(curr_mask);
      let out_data = masked_data | pack(curr_meta);
      $display("(%0d) IPv4: [1] ", $time, fshow(data_this_cycle), " meta=%h, mask=%h", curr_mask, curr_meta);
      data_this_cycle.data = {out_data, pack(last_data)};
      dataout.enq(data_this_cycle);
   endaction
   action
      let data_this_cycle = packet_in_wire;
      Vector#(128, Bit#(1)) curr_meta = takeAt(16, unpack(byteSwap(pack(ipv4_meta.first))));
      Vector#(128, Bit#(1)) curr_mask = takeAt(16, unpack(byteSwap(pack(ipv4_mask.first))));
      let masked_data = data_this_cycle.data & pack(curr_mask);
      let curr_data = masked_data | pack(curr_meta);
      data_this_cycle.data = curr_data;
      dataout.enq(data_this_cycle);
      $display("(%0d) IPv4: [2] ", $time, fshow(data_this_cycle));
   endaction
   action
      let data_this_cycle = packet_in_wire;
      Vector#(16, Bit#(1)) buff_data = takeAt(0, unpack(data_this_cycle.data));
      Vector#(112, Bit#(1)) unchanged = takeAt(16, unpack(data_this_cycle.data));
      Vector#(16, Bit#(1)) curr_mask = takeAt(144, unpack(byteSwap(pack(ipv4_mask.first))));
      Vector#(16, Bit#(1)) curr_meta = takeAt(144, unpack(byteSwap(pack(ipv4_meta.first))));
      let masked_data = pack(buff_data) & pack(curr_mask);
      let curr_data = masked_data | pack(curr_meta);
      let nextState = compute_next_state(ipv4_meta.first.protocol);
      $display("(%0d) compute_next_state ", $time, fshow(ipv4_meta.first.protocol));
      $display("(%0d) Goto ", $time, fshow(nextState));
      if (nextState == StateDeparseUdp) begin
         data_this_cycle.data = {pack(unchanged), pack(curr_data)};
         deparse_udp_fifo.enq(data_this_cycle);
      end
      ipv4_meta.deq;
      ipv4_mask.deq;
      state <= nextState;
   endaction
   endseq;

   FSM fsm_deparse_ipv4 <- mkFSM(deparse_ipv4);
   rule start_fsm if (start_wire);
      fsm_deparse_ipv4.start;
   endrule
   rule clear_fsm if (clear_wire);
      fsm_deparse_ipv4.abort;
   endrule
   method Action start();
      start_wire.send();
   endmethod
   method Action clear();
      clear_wire.send();
   endmethod
   interface deparse_ethernet = toPut(deparse_ethernet_fifo);
   interface deparse_udp = toGet(deparse_udp_fifo);
endmodule

interface DeparseUdp;
   interface Put#(EtherData) deparse_ipv4;
   interface Get#(EtherData) deparse_paxos;
   method Action start;
   method Action clear;
endinterface
module mkStateDeparseUdp#(Reg#(DeparserState) state,
                          FIFOF#(EtherData) datain,
                          FIFOF#(EtherData) dataout,
                          FIFOF#(UdpT) udp_meta,
                          FIFOF#(UdpT) udp_mask)
                          (DeparseUdp);

   let verbose = False;
   Wire#(EtherData) packet_in_wire <- mkDWire(defaultValue);
   FIFOF#(EtherData) deparse_ipv4_fifo <- mkBypassFIFOF;
   FIFO#(EtherData) deparse_paxos_fifo <- mkFIFO;

   PulseWire start_wire <- mkPulseWire();
   PulseWire clear_wire <- mkPulseWire();

   function DeparserState compute_next_state(Bit#(16) dstPort);
       DeparserState nextState = StateDeparseIdle;
       case (byteSwap(dstPort)) matches
           'h8888: begin
               nextState=StateDeparsePaxos;
           end
           default: begin
               nextState=StateDeparseIdle;
           end
       endcase
       return nextState;
   endfunction

   Stmt deparse_udp =
   seq
   action
      let data_this_cycle <- toGet(deparse_ipv4_fifo).get;
      Vector#(16, Bit#(1)) prev_data = takeAt(0, unpack(data_this_cycle.data));
      Vector#(64, Bit#(1)) udp_data = takeAt(16, unpack(data_this_cycle.data));
      Vector#(48, Bit#(1)) unchanged = takeAt(80, unpack(data_this_cycle.data));
      Vector#(64, Bit#(1)) curr_meta = takeAt(0, unpack(byteSwap(pack(udp_meta.first))));
      Vector#(64, Bit#(1)) curr_mask = takeAt(0, unpack(byteSwap(pack(udp_mask.first))));
      let masked_data = pack(udp_data) & pack(curr_mask);
      let curr_data = masked_data | pack(curr_meta);
      let nextState = compute_next_state(udp_meta.first.dstPort);
      if (verbose) $display("(%0d) udp_meta.dstport=", $time, fshow(udp_meta.first.dstPort));
      if (verbose) $display("(%0d) Goto ", $time, fshow(nextState));
      if (nextState == StateDeparsePaxos) begin
         data_this_cycle.data = {pack(unchanged), pack(curr_data), pack(prev_data)};
         deparse_paxos_fifo.enq(data_this_cycle);
      end
      udp_meta.deq;
      udp_mask.deq;
      state <= nextState;
   endaction
   endseq;

   FSM fsm_deparse_udp <- mkFSM(deparse_udp);
   rule start_fsm if (start_wire);
      fsm_deparse_udp.start();
   endrule
   rule clear_fsm if (clear_wire);
      fsm_deparse_udp.abort();
   endrule
   method Action start();
      start_wire.send();
   endmethod
   method Action clear();
      clear_wire.send();
   endmethod
   interface deparse_ipv4 = toPut(deparse_ipv4_fifo);
   interface deparse_paxos = toGet(deparse_paxos_fifo);
endmodule

interface DeparsePaxos;
   interface Put#(EtherData) deparse_udp;
   method Action start;
   method Action clear;
endinterface
module mkStateDeparsePaxos#(Reg#(DeparserState) state,
                            FIFOF#(EtherData) datain,
                            FIFOF#(EtherData) dataout,
                            FIFOF#(PaxosT) paxos_meta,
                            FIFOF#(PaxosT) paxos_mask)
                            (DeparsePaxos);

   Wire#(EtherData) packet_in_wire <- mkDWire(defaultValue);
   FIFOF#(EtherData) deparse_udp_fifo <- mkBypassFIFOF;

   PulseWire start_wire <- mkPulseWire();
   PulseWire clear_wire <- mkPulseWire();

   function Bit#(128) apply_metadata(Integer offset, Bit#(128) field, PaxosT data, PaxosT mask);
      Vector#(128, Bit#(1)) curr_meta = takeAt(offset, unpack(byteSwap(pack(data))));
      Vector#(128, Bit#(1)) curr_mask = takeAt(offset, unpack(byteSwap(pack(mask))));
      return (field & pack(curr_mask)) | pack(curr_meta);
   endfunction

   rule load_packet if (state == StateDeparsePaxos && !deparse_udp_fifo.notEmpty());
       let data_current <- toGet(datain).get;
       packet_in_wire <= data_current;
       $display("(%0d) Paxos: ", $time, fshow(data_current));
   endrule

   Stmt deparse_paxos =
   seq
   action
      let data_this_cycle <- toGet(deparse_udp_fifo).get;
      Vector#(80, Bit#(1)) prev_data = takeAt(0, unpack(pack(data_this_cycle.data)));
      Vector#(48, Bit#(1)) last_data = takeAt(80, unpack(pack(data_this_cycle.data)));
      Vector#(48, Bit#(1)) curr_meta = takeAt(0, unpack(byteSwap(pack(paxos_meta.first))));
      Vector#(48, Bit#(1)) curr_mask = takeAt(0, unpack(byteSwap(pack(paxos_mask.first))));
      let masked_data = pack(last_data) & pack(curr_mask);
      let curr_data = masked_data | pack(curr_meta);
      data_this_cycle.data = {curr_data, pack(prev_data)};
      $display("(%0d) dataout ", $time, fshow(data_this_cycle));
      dataout.enq(data_this_cycle);
   endaction
   action
      let data_this_cycle = packet_in_wire;
      let out = apply_metadata(48, data_this_cycle.data, paxos_meta.first, paxos_mask.first);
      data_this_cycle.data = out;
      $display("(%0d) dataout ", $time, fshow(data_this_cycle));
      dataout.enq(data_this_cycle);
   endaction
   action
      let data_this_cycle = packet_in_wire;
      let out = apply_metadata(176, data_this_cycle.data, paxos_meta.first, paxos_mask.first);
      data_this_cycle.data = out;
      $display("(%0d) dataout ", $time, fshow(data_this_cycle));
      dataout.enq(data_this_cycle);
   endaction
   action
      let data_this_cycle = packet_in_wire;
      //let out = apply_metadata(304, data_this_cycle, paxos_meta.first, paxos_mask.first);
      Vector#(48, Bit#(1)) curr_meta = takeAt(304, unpack(byteSwap(pack(paxos_meta.first))));
      Vector#(48, Bit#(1)) curr_mask = takeAt(304, unpack(byteSwap(pack(paxos_mask.first))));
      Vector#(48, Bit#(1)) data = takeAt(0, unpack(pack(data_this_cycle.data)));
      Vector#(80, Bit#(1)) payload = takeAt(48, unpack(pack(data_this_cycle.data)));
      let out = (pack(data) & pack(curr_mask)) | pack(curr_meta);
      data_this_cycle.data = { pack(payload), out };
      $display("(%0d) dataout ", $time, fshow(data_this_cycle));
      dataout.enq(data_this_cycle);
      paxos_meta.deq;
      paxos_mask.deq;
      state <= StateDeparseIdle;
   endaction
   endseq;
   FSM fsm_deparse_paxos <- mkFSM(deparse_paxos);
   rule start_fsm if (start_wire);
       fsm_deparse_paxos.start;
   endrule
   rule clear_fsm if (clear_wire);
       fsm_deparse_paxos.abort;
   endrule
   method Action start();
       start_wire.send();
   endmethod
   method Action clear();
       clear_wire.send();
   endmethod

   interface deparse_udp = toPut(deparse_udp_fifo);
endmodule

interface DeparseIpv6;
   interface Put#(EtherData) deparse_ethernet;
   method Action start;
   method Action clear;
endinterface
module mkStateDeparseIpv6#(Reg#(DeparserState) state,
                           FIFOF#(EtherData) datain,
                           FIFOF#(EtherData) dataout,
                           FIFOF#(Ipv6T) ipv6_meta,
                           FIFOF#(Ipv6T) ipv6_mask)
                           (DeparseIpv6);
   Wire#(EtherData) packet_in_wire <- mkDWire(defaultValue);
   FIFOF#(EtherData) deparse_ethernet_fifo <- mkBypassFIFOF;
   PulseWire start_wire <- mkPulseWire;
   PulseWire clear_wire <- mkPulseWire;

   function Bit#(128) apply_metadata(Integer offset, Bit#(128) field, Ipv6T data, Ipv6T mask);
      Vector#(128, Bit#(1)) curr_meta = takeAt(offset, unpack(byteSwap(pack(data))));
      Vector#(128, Bit#(1)) curr_mask = takeAt(offset, unpack(byteSwap(pack(mask))));
      return (field & pack(curr_mask)) | pack(curr_meta);
   endfunction

   rule load_packet if (state == StateDeparseIpv6 && !deparse_ethernet_fifo.notEmpty());
      let data_current <- toGet(datain).get;
      packet_in_wire <= data_current;
      $display("(%0d) IPv6: ", $time, fshow(data_current));
   endrule

   Stmt deparse_ipv6 =
   seq
   action
      let data_this_cycle <- toGet(deparse_ethernet_fifo).get;
      Vector#(112, Bit#(1)) last_data = takeAt(0, unpack(data_this_cycle.data));
      Vector#(16, Bit#(1)) data = takeAt(112, unpack(data_this_cycle.data));
      Vector#(16, Bit#(1)) curr_meta = takeAt(0, unpack(byteSwap(pack(ipv6_meta.first))));
      Vector#(16, Bit#(1)) curr_mask = takeAt(0, unpack(byteSwap(pack(ipv6_meta.first))));
      let masked_data = pack(data) & pack(curr_mask);
      let out_data = masked_data | pack(curr_meta);
      $display("(%0d) IPv6: ", $time, fshow(data_this_cycle));
      data_this_cycle.data = {out_data, pack(last_data)};
      dataout.enq(data_this_cycle);
   endaction
   action
      let data_this_cycle = packet_in_wire;
      let out = apply_metadata(16, data_this_cycle.data, ipv6_meta.first, ipv6_mask.first);
      data_this_cycle.data = out;
      $display("(%0d) dataout ", $time, fshow(data_this_cycle));
      dataout.enq(data_this_cycle);
   endaction
   action
      let data_this_cycle = packet_in_wire;
      let out = apply_metadata(144, data_this_cycle.data, ipv6_meta.first, ipv6_mask.first);
      data_this_cycle.data = out;
      $display("(%0d) dataout ", $time, fshow(data_this_cycle));
      dataout.enq(data_this_cycle);
   endaction
   action
      let data_this_cycle = packet_in_wire;
      Vector#(48, Bit#(1)) curr_meta = takeAt(272, unpack(byteSwap(pack(ipv6_meta.first))));
      Vector#(48, Bit#(1)) curr_mask = takeAt(272, unpack(byteSwap(pack(ipv6_mask.first))));
      Vector#(48, Bit#(1)) data = takeAt(0, unpack(pack(data_this_cycle.data)));
      Vector#(80, Bit#(1)) payload = takeAt(48, unpack(pack(data_this_cycle.data)));
      let out = (pack(data) & pack(curr_mask)) | pack(curr_meta);
      data_this_cycle.data = { pack(payload), out };
      dataout.enq(data_this_cycle);
      $display("(%0d) dataout ", $time, fshow(data_this_cycle));
      ipv6_meta.deq;
      ipv6_mask.deq;
      state <= StateDeparseIdle;
   endaction
   endseq;
   FSM fsm_deparse_ipv6 <- mkFSM(deparse_ipv6);
   rule start_fsm if (start_wire);
       fsm_deparse_ipv6.start;
   endrule
   rule clear_fsm if (clear_wire);
       fsm_deparse_ipv6.abort;
   endrule
   method Action start();
       start_wire.send();
   endmethod
   method Action clear();
       clear_wire.send();
   endmethod
   interface deparse_ethernet = toPut(deparse_ethernet_fifo);
endmodule

interface Deparser;
   interface PipeIn#(MetadataT) metadata;
   interface PktWriteServer writeServer;
   interface PktWriteClient writeClient;
   method DeparserPerfRec read_perf_info;
endinterface

typedef 4 PortMax;
(* synthesize *)
module mkDeparser(Deparser);
   let verbose = False;
   FIFOF#(EtherData) data_in_fifo <- mkSizedFIFOF(4);
   FIFOF#(EtherData) data_out_fifo <- mkFIFOF;
   FIFOF#(MetadataT) metadata_in_fifo <- mkFIFOF;

   Reg#(Bool) started <- mkReg(False);
   Wire#(Bool) start_fsm <- mkDWire(False);
   Reg#(DeparserState) curr_state <- mkReg(StateDeparseIdle);

   Vector#(PortMax, FIFOF#(DeparserState)) deparse_state_in_fifo <- replicateM(mkGFIFOF(False, True));
   FIFOF#(DeparserState) deparse_state_out_fifo <- mkFIFOF;

   FIFOF#(EthernetT) ethernet_meta_fifo <- mkFIFOF;
   FIFOF#(Ipv4T) ipv4_meta_fifo <- mkFIFOF;
   FIFOF#(UdpT) udp_meta_fifo <- mkFIFOF;
   FIFOF#(PaxosT) paxos_meta_fifo <- mkFIFOF;
   FIFOF#(Ipv6T) ipv6_meta_fifo <- mkFIFOF;

   FIFOF#(EthernetT) ethernet_mask_fifo <- mkFIFOF;
   FIFOF#(Ipv4T) ipv4_mask_fifo <- mkFIFOF;
   FIFOF#(UdpT) udp_mask_fifo <- mkFIFOF;
   FIFOF#(PaxosT) paxos_mask_fifo <- mkFIFOF;
   FIFOF#(Ipv6T) ipv6_mask_fifo <- mkFIFOF;

   Reg#(Bit#(32)) clk_cnt <- mkReg(0);
   Reg#(Bit#(32)) deparser_start_time <- mkReg(0);
   Reg#(Bit#(32)) deparser_end_time <- mkReg(0);
   rule clockrule;
      clk_cnt <= clk_cnt + 1;
   endrule

   (* fire_when_enabled *)
   rule arbitrate_deparse_state;
      Bool sentOne = False;
      for (Integer port = 0; port < valueOf(PortMax); port = port+1) begin
         if (!sentOne && deparse_state_in_fifo[port].notEmpty()) begin
            DeparserState state <- toGet(deparse_state_in_fifo[port]).get();
            sentOne = True;
            $display("(%0d) xxx arbitrate %h", $time, port);
            deparse_state_out_fifo.enq(state);
         end
      end
   endrule

   rule get_metadata;
      let v <- toGet(metadata_in_fifo).get;
      let ethernet = toEthernet(v);
      match {.data, .mask} = ethernet;
      ethernet_meta_fifo.enq(data);
      ethernet_mask_fifo.enq(mask);

      let ipv4 = toIpv4(v);
      match {.ipv4_data, .ipv4_mask} = ipv4;
      if (verbose) $display("(%0d) ipv4 meta", $time, fshow(ipv4));
      ipv4_meta_fifo.enq(ipv4_data);
      ipv4_mask_fifo.enq(ipv4_mask);

      let udp = toUdp(v);
      match {.udp_data, .udp_mask} = udp;
      udp_meta_fifo.enq(udp_data);
      udp_mask_fifo.enq(udp_mask);

      //let ipv6 = toIpv6(v);
      //if (ipv6 matches tagged Valid {.data, .mask}) begin
      //   ipv6_meta_fifo.enq(data);
      //   ipv6_mask_fifo.enq(mask);
      //end

      let paxos = toPaxos(v);
      match {.paxos_data, .paxos_mask} = paxos;
      paxos_meta_fifo.enq(paxos_data);
      paxos_mask_fifo.enq(paxos_mask);
   endrule

   Empty init_state <- mkStateDeparseIdle(curr_state, data_in_fifo, data_out_fifo, start_fsm);
   DeparseEthernet deparse_ethernet <- mkStateDeparseEthernet(curr_state, data_in_fifo, data_out_fifo, ethernet_meta_fifo, ethernet_mask_fifo);
   //DeparseArp deparse_arp <- mkStateDeparseArp(curr_state, data_in_fifo);
   DeparseIpv4 deparse_ipv4 <- mkStateDeparseIpv4(curr_state, data_in_fifo, data_out_fifo, ipv4_meta_fifo, ipv4_mask_fifo);
   DeparseIpv6 deparse_ipv6 <- mkStateDeparseIpv6(curr_state, data_in_fifo, data_out_fifo, ipv6_meta_fifo, ipv6_mask_fifo);
   DeparseUdp deparse_udp <- mkStateDeparseUdp(curr_state, data_in_fifo, data_out_fifo, udp_meta_fifo, udp_mask_fifo);
   DeparsePaxos deparse_paxos <- mkStateDeparsePaxos(curr_state, data_in_fifo, data_out_fifo, paxos_meta_fifo, paxos_mask_fifo);

   //mkConnection(deparse_arp.deparse_ethernet, deparse_ethernet.deparse_arp);
   mkConnection(deparse_ipv4.deparse_ethernet, deparse_ethernet.deparse_ipv4);
   mkConnection(deparse_ipv6.deparse_ethernet, deparse_ethernet.deparse_ipv6);
   mkConnection(deparse_udp.deparse_ipv4, deparse_ipv4.deparse_udp);
   mkConnection(deparse_paxos.deparse_udp, deparse_udp.deparse_paxos);

   rule start if (start_fsm);
      if (!started) begin
         deparse_ethernet.start;
         //deparse_arp.start;
         deparse_ipv4.start;
         //deparse_ipv6.start;
         deparse_udp.start;
         deparse_paxos.start;
         started <= True;
         deparser_start_time <= clk_cnt;
      end
   endrule

   rule clear if (!start_fsm && curr_state == StateDeparseIdle);
      if (started) begin
         deparse_ethernet.clear;
         //deparse_arp.clear;
         deparse_ipv4.clear;
         //deparse_ipv6.clear;
         deparse_udp.clear;
         deparse_paxos.clear;
         started <= False;
         deparser_end_time <= clk_cnt;
      end
   endrule

   interface PktWriteServer writeServer;
      interface writeData = toPut(data_in_fifo);
   endinterface
   interface PktWriteClient writeClient;
      interface writeData = toGet(data_out_fifo);
   endinterface
   interface metadata = toPipeIn(metadata_in_fifo);
   method DeparserPerfRec read_perf_info;
      return DeparserPerfRec {
         deparser_start_time: deparser_start_time,
         deparser_end_time: deparser_end_time
      };
   endmethod
endmodule
