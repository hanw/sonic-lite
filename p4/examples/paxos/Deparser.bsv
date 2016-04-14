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

typedef enum {
   StateDeparseIdle,
   StateDeparseEthernet,
   StateDeparseArp,
   StateDeparseIpv4,
   StateDeparseIpv6,
   StateDeparseUdp,
   StateDeparsePaxos
} DeparserState deriving (Bits, Eq);
instance FShow#(DeparserState);
   function Fmt fshow(DeparserState state);
      return $format("State %h", state);
   endfunction
endinstance

function Tuple2#(EthernetT, EthernetT) toEthernet(MetadataT meta);
   EthernetT data = defaultValue;
   EthernetT mask = defaultMask;
   data.dstAddr = fromMaybe(?, meta.dstAddr);
   mask.dstAddr = 0;
   return tuple2(data, mask);
endfunction

function Tuple2#(Ipv4T, Ipv4T) toIpv4(MetadataT meta);
   Ipv4T ipv4 = defaultValue;
   Ipv4T mask = defaultMask;
   return tuple2(ipv4, mask);
endfunction

function Tuple2#(UdpT, UdpT) toUdp(MetadataT meta);
   UdpT udp = defaultValue;
   UdpT mask = defaultMask;
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
   // copy meta -> paxos
   return tuple2(paxos, mask);
endfunction

module mkStateDeparseIdle#(Reg#(DeparserState) state, FIFOF#(EtherData) datain, Wire#(Bool) start_fsm)(Empty);

   rule load_packet if (state == StateDeparseIdle);
   let v = datain.first;
      if (v.sop) begin
         state <= StateDeparseEthernet;
         start_fsm <= True;
      end
      else begin
         datain.deq;
         start_fsm <= False;
      end
   endrule
endmodule

interface DeparseEthernet;
   interface Get#(Bit#(128)) deparse_arp;
   interface Get#(Bit#(128)) deparse_ipv4;
   interface Get#(Bit#(128)) deparse_ipv6;
   method Action start;
   method Action clear;
endinterface

module mkStateDeparseEthernet#(Reg#(DeparserState) state,
                               FIFOF#(EtherData) datain,
                               FIFOF#(EthernetT) ethernet_meta,
                               FIFOF#(EthernetT) ethernet_mask)
                               (DeparseEthernet);
   let verbose = True;

   Wire#(Bit#(128)) packet_in_wire <- mkDWire(0);
   FIFO#(Bit#(128)) packet_out_fifo <- mkFIFO;
   Wire#(EthernetT) metadata_wire <- mkDWire(defaultValue);
   Wire#(EthernetT) mask_wire <- mkDWire(defaultMask);

   FIFO#(Bit#(128)) parse_arp_fifo <- mkFIFO;
   FIFO#(Bit#(128)) parse_ipv4_fifo <- mkFIFO;
   FIFO#(Bit#(128)) parse_ipv6_fifo <- mkFIFO;

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
      packet_in_wire <= data_current.data;
   endrule

   rule load_metadata if (state == StateDeparseEthernet);
      metadata_wire <= ethernet_meta.first;
      mask_wire <= ethernet_mask.first;
   endrule

   Stmt deparse_ethernet =
   seq
   action
      let data_this_cycle = packet_in_wire;
      Vector#(128, Bit#(1)) dataVec = unpack(data_this_cycle);
      Vector#(112, Bit#(1)) unsent = takeAt(0, dataVec);
      Vector#(16, Bit#(1)) unchanged = takeAt(112, dataVec);
      EthernetT ethernet = unpack(pack(unsent));
      let nextState = compute_next_state(metadata_wire.etherType);
      if (verbose) $display("(%0d) Goto state %h", $time, nextState);
      if (nextState == StateDeparseArp) begin
         parse_arp_fifo.enq({pack(unsent), pack(unchanged)});
      end
      else if (nextState == StateDeparseIpv4) begin
         parse_ipv4_fifo.enq({pack(unsent), pack(unchanged)});
      end
      else if (nextState == StateDeparseIpv6) begin
         parse_ipv6_fifo.enq({pack(unsent), pack(unchanged)});
      end
      //next_state_wire[0] <= tagged Valid nextState;
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
   interface Put#(Bit#(128)) deparse_ethernet;
   interface Get#(Bit#(128)) deparse_udp;
   method Action start;
   method Action clear;
endinterface
module mkStateDeparseIpv4#(Reg#(DeparserState) state,
                           FIFOF#(EtherData) datain,
                           FIFOF#(Ipv4T) ipv4_meta,
                           FIFOF#(Ipv4T) ipv4_mask)
                           (DeparseIpv4);

   Wire#(Bit#(128)) packet_in_wire <- mkDWire(0);
   FIFO#(Bit#(128)) packet_out_fifo <- mkFIFO;
   FIFO#(Bit#(128)) parse_udp_fifo <- mkFIFO;
   Wire#(Ipv4T) metadata_wire <- mkDWire(defaultValue);
   Wire#(Ipv4T) mask_wire <- mkDWire(defaultMask);
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

//   rule load_last_cycle if (state == StateDeparseIpv4 && !load_new);
//      let data_current <- toGet(lastcycle).get;
//      packet_in_wire <= data_current.data;
//   endrule

   rule load_packet if (state == StateDeparseIpv4);
       let data_current <- toGet(datain).get;
       packet_in_wire <= data_current.data;
   endrule

   rule load_metadata if (state == StateDeparseIpv4);
      //let data = toIpv4(ipv4_meta.first);
      metadata_wire <= ipv4_meta.first;
      mask_wire <= ipv4_mask.first;
   endrule

   Stmt deparse_ipv4 = 
   seq
   action
      let data_this_cycle = packet_in_wire;
      Vector#(112, Bit#(1)) last_data = takeAt(0, unpack(data_this_cycle));
      Vector#(16, Bit#(1)) data = takeAt(112, unpack(data_this_cycle));
      Vector#(16, Bit#(1)) curr_meta = takeAt(0, unpack(pack(ipv4_meta.first)));
      Vector#(16, Bit#(1)) curr_mask = takeAt(0, unpack(pack(ipv4_mask.first)));
      let masked_data = pack(data) & pack(curr_mask);
      let out_data = masked_data | pack(curr_meta);
      packet_out_fifo.enq({pack(last_data), out_data});
   endaction
   action
      let data_this_cycle = packet_in_wire;
      Vector#(128, Bit#(1)) curr_meta = takeAt(16, unpack(pack(ipv4_meta.first)));
      Vector#(128, Bit#(1)) curr_mask = takeAt(16, unpack(pack(ipv4_mask.first)));
      let masked_data = data_this_cycle & pack(curr_mask);
      let curr_data = masked_data | pack(curr_meta);
      packet_out_fifo.enq(curr_data);
   endaction
   action
      let data_this_cycle = packet_in_wire;
      Vector#(16, Bit#(1)) buff_data = takeAt(0, unpack(data_this_cycle));
      Vector#(112, Bit#(1)) unchanged = takeAt(16, unpack(data_this_cycle));
      Vector#(16, Bit#(1)) curr_mask = takeAt(144, unpack(pack(ipv4_mask.first)));
      Vector#(16, Bit#(1)) curr_meta = takeAt(144, unpack(pack(ipv4_meta.first)));
      let masked_data = pack(buff_data) & pack(curr_mask);
      let curr_data = masked_data | pack(curr_meta);
      let nextState = compute_next_state(metadata_wire.protocol);
      if (nextState == StateDeparseUdp) begin
         parse_udp_fifo.enq({pack(curr_data), pack(unchanged)});
      end
   endaction
   endseq;
endmodule

interface DeparseUdp;
   interface Put#(Bit#(128)) deparse_ipv4;
   interface Get#(Bit#(128)) deparse_paxos;
   method Action start;
   method Action clear;
endinterface
module mkStateDeparseUdp#(Reg#(DeparserState) state,
                          FIFOF#(EtherData) datain,
                          FIFOF#(UdpT) udp_meta,
                          FIFOF#(UdpT) udp_mask)
                          (DeparseUdp);

   Wire#(Bit#(128)) packet_in_wire <- mkDWire(0);
   FIFO#(Bit#(128)) packet_out_fifo <- mkFIFO;
   FIFO#(Bit#(128)) parse_paxos_fifo <- mkFIFO;
   Wire#(UdpT) metadata_wire <- mkDWire(defaultValue);
   Wire#(UdpT) mask_wire <- mkDWire(defaultMask);

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

//   rule load_last_cycle if (state == StateDeparseUdp && !load);
//      let data_current <- toGet(lastcycle).get;
//      packet_in_wire <= data_current.data;
//   endrule

   rule load_packet if (state == StateDeparseUdp);
       let data_current <- toGet(datain).get;
       packet_in_wire <= data_current.data;
   endrule

   rule load_metadata if (state == StateDeparseUdp);
      metadata_wire <= udp_meta.first;
      mask_wire <= udp_mask.first;
   endrule

   Stmt deparse_udp =
   seq
   action
      let data_this_cycle = packet_in_wire;
      Vector#(80, Bit#(1)) unsent = takeAt(0, unpack(data_this_cycle));
      Vector#(48, Bit#(1)) unchanged = takeAt(80, unpack(data_this_cycle));
      let nextState = compute_next_state(metadata_wire.dstPort);
      if (nextState == StateDeparsePaxos) begin
         parse_paxos_fifo.enq({pack(unsent), pack(unchanged)});
      end
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
endmodule

interface DeparsePaxos;
   interface Put#(Bit#(128)) deparse_udp;
   method Action start;
   method Action clear;
endinterface
module mkStateDeparsePaxos#(Reg#(DeparserState) state,
                            FIFOF#(EtherData) datain,
                            FIFOF#(PaxosT) paxos_meta,
                            FIFOF#(PaxosT) paxos_mask)
                            (DeparsePaxos);

   Wire#(Bit#(128)) packet_in_wire <- mkDWire(0);
   FIFO#(Bit#(128)) packet_out_fifo <- mkFIFO;

   PulseWire start_wire <- mkPulseWire();
   PulseWire clear_wire <- mkPulseWire();

   function Bit#(128) apply_metadata(Integer offset, Bit#(128) field, PaxosT data, PaxosT mask);
      Vector#(128, Bit#(1)) curr_meta = takeAt(offset, unpack(pack(data)));
      Vector#(128, Bit#(1)) curr_mask = takeAt(offset, unpack(pack(mask)));
      return (field & pack(curr_mask)) | pack(curr_meta);
   endfunction

   rule load_packet if (state == StateDeparsePaxos);
       let data_current <- toGet(datain).get;
       packet_in_wire <= data_current.data;
   endrule

   Stmt deparse_paxos =
   seq
   action
      let data_this_cycle = packet_in_wire;
      Vector#(80, Bit#(1)) prev_data = takeAt(0, unpack(pack(data_this_cycle)));
      Vector#(48, Bit#(1)) last_data = takeAt(80, unpack(pack(data_this_cycle)));
      Vector#(48, Bit#(1)) curr_meta = takeAt(0, unpack(pack(paxos_meta.first)));
      Vector#(48, Bit#(1)) curr_mask = takeAt(0, unpack(pack(paxos_mask.first)));
      let masked_data = pack(last_data) & pack(curr_mask);
      let curr_data = masked_data | pack(curr_meta);
      packet_out_fifo.enq({pack(prev_data), pack(last_data)});
   endaction
   action
      let data_this_cycle = packet_in_wire;
      let out = apply_metadata(48, data_this_cycle, paxos_meta.first, paxos_mask.first);
      //Vector#(128, Bit#(1)) curr_meta = takeAt(48, unpack(pack(paxos_meta.first)));
      //Vector#(128, Bit#(1)) curr_mask = takeAt(48, unpack(pack(paxos_mask.first)));
      //let masked_data = data_this_cycle & pack(curr_mask);
      //let curr_data = masked_data | pack(curr_meta);
      packet_out_fifo.enq(out);
   endaction
   action
      let data_this_cycle = packet_in_wire;
      // out = apply_metadata(176, data_this_cycle, paxos_meta, paxos_mask);
      //Vector#(128, Bit#(1)) curr_meta = takeAt(176, unpack(pack(paxos_meta.first)));
      //Vector#(128, Bit#(1)) curr_mask = takeAt(176, unpack(pack(paxos_mask.first)));
      //let masked_data = data_this_cycle & pack(curr_mask);
      //let curr_data = masked_data | pack(curr_meta);
      //packet_out_fifo.enq(curr_data);
   endaction
   action
      let data_this_cycle = packet_in_wire;
      // out = apply_metadata(304, data_this_cycle, paxos_meta, paxos_mask);
      //Vector#(128, Bit#(1)) curr_meta = takeAt(304, unpack(pack(paxos_meta.first)));
      //Vector#(128, Bit#(1)) curr_mask = takeAt(304, unpack(pack(paxos_mask.first)));
      //let masked_data = data_this_cycle & pack(curr_mask);
      //let curr_data = masked_data | pack(curr_meta);
      //packet_out_fifo.enq(curr_data);
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
endmodule

interface Deparser;
   interface Get#(MetadataT) metadata;
   interface PktWriteServer writeServer;
   interface PktWriteClient writeClient;
endinterface

typedef 4 PortMax;
(* synthesize *)
module mkDeparser(Deparser);
   let verbose = True;
   Reg#(DeparserState) curr_state <- mkReg(StateDeparseIdle);
   Reg#(Bool) started <- mkReg(False);
   FIFOF#(EtherData) data_in_fifo <- mkFIFOF;
   FIFOF#(EtherData) writeDataFifo <- mkFIFOF;
   Wire#(Bool) start_fsm <- mkDWire(False);

   Vector#(PortMax, FIFOF#(DeparserState)) deparse_state_in_fifo <- replicateM(mkGFIFOF(False, True));
   FIFOF#(DeparserState) deparse_state_out_fifo <- mkFIFOF;
   FIFOF#(MetadataT) metadata_in_fifo <- mkFIFOF;

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
      //if (ethernet matches tagged Valid {.data, .mask}) begin
      //   ethernet_meta_fifo.enq(data);
      //   ethernet_mask_fifo.enq(mask);
      //end

      //let ipv4 = toIpv4(v);
      //if (ipv4 matches tagged Valid {.data, .mask}) begin
      //   ipv4_meta_fifo.enq(data);
      //   ipv4_mask_fifo.enq(mask);
      //end

      //let udp = toUdp(v);
      //if (udp matches tagged Valid {.data, .mask}) begin
      //   udp_meta_fifo.enq(data);
      //   udp_mask_fifo.enq(mask);
      //end

      //let ipv6 = toIpv6(v);
      //if (ipv6 matches tagged Valid {.data, .mask}) begin
      //   ipv6_meta_fifo.enq(data);
      //   ipv6_mask_fifo.enq(mask);
      //end

      //let paxos = toPaxos(v);
      //if (paxos matches tagged Valid {.data, .mask}) begin
      //   paxos_meta_fifo.enq(data);
      //   paxos_mask_fifo.enq(mask);
      //end
   endrule

   Empty init_state <- mkStateDeparseIdle(curr_state, data_in_fifo, start_fsm);
   DeparseEthernet deparse_ethernet <- mkStateDeparseEthernet(curr_state, data_in_fifo, ethernet_meta_fifo, ethernet_mask_fifo);
   //DeparseArp deparse_arp <- mkStateDeparseArp(curr_state, data_in_fifo);
   DeparseIpv4 deparse_ipv4 <- mkStateDeparseIpv4(curr_state, data_in_fifo, ipv4_meta_fifo, ipv4_mask_fifo);
   //DeparseIpv6 deparse_ipv6 <- mkStateDeparseIpv6(curr_state, data_in_fifo);
   DeparseUdp deparse_udp <- mkStateDeparseUdp(curr_state, data_in_fifo, udp_meta_fifo, udp_mask_fifo);
   DeparsePaxos deparse_paxos <- mkStateDeparsePaxos(curr_state, data_in_fifo, paxos_meta_fifo, paxos_mask_fifo);

   //mkConnection(deparse_arp.deparse_ethernet, deparse_ethernet.deparse_arp);
   mkConnection(deparse_ipv4.deparse_ethernet, deparse_ethernet.deparse_ipv4);
   //mkConnection(deparse_ipv6.deparse_ethernet, deparse_ethernet.deparse_ipv6);
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
      end
   endrule

   interface PktWriteServer writeServer;
      interface Put writeData;
         method Action put(EtherData d);
            // start of packet
            if (d.sop) begin
               started <= True;
            end
            else if (d.eop) begin
               started <= False;
            end
            // data from memory
         endmethod
      endinterface
   endinterface
   interface PktWriteClient writeClient;
      interface writeData = toGet(writeDataFifo);
   endinterface
   interface metadata = toGet(metadata_in_fifo);
endmodule
