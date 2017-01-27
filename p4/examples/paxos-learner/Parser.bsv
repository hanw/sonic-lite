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

import DbgDefs::*;
import Ethernet::*;
import FIFO::*;
import FIFOF::*;
import GetPut::*;
import StmtFSM::*;
import Vector::*;
import PaxosTypes::*;
import Utils::*;
import Stream::*;

typedef enum {
   StateParseStart,
   StateParseEthernet,
   StateParseArp,
   StateParseIpv4,
   StateParseIpv6,
   StateParseCpuHeader,
   StateParseUdp,
   StateParsePaxos
} ParserState deriving (Bits, Eq);

interface Parser;
   interface Put#(ByteStream#(16)) frameIn;
   interface Get#(MetadataT) meta;
   method ParserPerfRec read_perf_info;
   method Action set_verbosity(int verbosity);
endinterface

(* synthesize *)
module mkParser(Parser);
   // verbosity
   Reg#(int) cr_verbosity[2] <- mkCRegU(2);
   FIFOF#(int) cr_verbosity_ff <- mkFIFOF;

   rule rl_verbosity;
      let x = cr_verbosity_ff.first;
      cr_verbosity_ff.deq;
      cr_verbosity[1] <= x;
   endrule

   FIFOF#(ByteStream#(16)) data_in_ff <- mkFIFOF;
   FIFOF#(MetadataT) meta_out_ff <- mkFIFOF;
   Reg#(ParserState) rg_parse_state <- mkReg(StateParseStart);
   Reg#(Bit#(32)) rg_offset <- mkReg(0);
   Reg#(Bit#(144)) rg_tmp_ipv4 <- mkReg(0);
   Reg#(Bit#(144)) rg_tmp_arp <- mkReg(0);
   Reg#(Bit#(144)) rg_tmp_ipv6 <- mkReg(0);
   Reg#(Bit#(112)) rg_tmp_udp <- mkReg(0);
   Reg#(Bit#(304)) rg_tmp_paxos <- mkReg(0);

   function Tuple2 #(Bit#(112), Bit#(16)) extract_header (Bit#(128) d);
      Vector#(128, Bit#(1)) data_vec = unpack(d);
      Bit#(112) curr_data = pack(takeAt(0, data_vec));
      Bit#(16) next_data = pack(takeAt(16, data_vec));
      return tuple2 (curr_data, next_data);
   endfunction

   function Action report_parse_action (ParserState state, Bit#(32) offset, Bit#(128) din);
      action
         if (cr_verbosity[0] > 0)
            $display ("(%d) Parser State %h offset 0x%h data %h", $time, state, offset, din);
      endaction
   endfunction

   function Action succeed_and_next (Bit#(32) next_offset);
      action
         data_in_ff.deq;
         rg_offset <= next_offset;
      endaction
   endfunction

   function Action fail_and_trap (Bit#(32) next_offset);
      action
         data_in_ff.deq;
         rg_offset <= 0;
      endaction
   endfunction

   function Action push_phv ();
      action
         // let req = tagged
         // phv_reqs.enq();
      endaction
   endfunction

   let din = data_in_ff.first.data;

   rule start_state if (rg_parse_state == StateParseStart);
      let v = data_in_ff.first;
      if (v.sop) begin
         rg_parse_state <= StateParseEthernet;
      end
      else begin
         data_in_ff.deq;
      end
   endrule

   function ParserState compute_next_state_ethernet(Bit#(16) v);
      ParserState nextState = StateParseStart;
      case (byteSwap(v)) matches
         'h806: begin
             nextState=StateParseArp;
         end
         'h800: begin
             nextState=StateParseIpv4;
         end
         'h86dd: begin
             nextState=StateParseIpv6;
         end
         default: begin
            nextState = StateParseStart;
         end
      endcase
      return nextState;
   endfunction

   rule parse_ethernet ((rg_parse_state == StateParseEthernet) && (rg_offset == 0));
      report_parse_action(rg_parse_state, rg_offset, din);
      let tmp_ethernet = din[111:0];
      let ethernet = extract_ethernet(tmp_ethernet);
      let next_state = compute_next_state_ethernet(ethernet.etherType);
      rg_parse_state <= next_state;
      if (next_state == StateParseArp) begin
          rg_tmp_arp <= zeroExtend(din[127:112]);
      end
      else if (next_state == StateParseIpv4) begin
          rg_tmp_ipv4 <= zeroExtend(din[127:112]);
      end
      else if (next_state == StateParseIpv6) begin
          rg_tmp_ipv6 <= zeroExtend(din[127:112]);
      end
      else begin
         // push phv();
      end
      // output metadata
      succeed_and_next(rg_offset + 128);
   endrule

   function ParserState compute_next_state_ipv4(Bit#(8) protocol);
      ParserState nextState = StateParseStart;
      case (byteSwap(protocol)) matches
         'h11: begin
            nextState=StateParseUdp;
         end
         default: begin
            nextState=StateParseStart;
         end
      endcase
      return nextState;
   endfunction

   rule parse_ipv4_1 ((rg_parse_state == StateParseIpv4) && (rg_offset == 128));
      report_parse_action(rg_parse_state, rg_offset, din);
      rg_tmp_ipv4 <= zeroExtend( { din, rg_tmp_ipv4[15:0] } );
      succeed_and_next(rg_offset + 128);
   endrule

   rule parse_ipv4_2 ((rg_parse_state == StateParseIpv4) && (rg_offset == 256));
      report_parse_action(rg_parse_state, rg_offset, din);
      Bit#(272) data = {din, rg_tmp_ipv4};
      Vector#(272, Bit#(1)) dataVec = unpack(data);
      let ipv4 = extract_ipv4(pack(takeAt(0, dataVec)));
      $display("ipv4 protocol %h", ipv4.protocol);
      let next_state = compute_next_state_ipv4(ipv4.protocol);
      $display("next state", next_state);
      rg_parse_state <= next_state;
      if (next_state == StateParseUdp) begin
         rg_tmp_udp <= din[127:16];
      end
      else begin
         // fail_and_trap();
      end
      succeed_and_next(rg_offset + 128);
   endrule

   rule parse_arp_1 ((rg_parse_state == StateParseArp) && (rg_offset == 128));
      report_parse_action(rg_parse_state, rg_offset, din);
      Bit#(144) data = {din, rg_tmp_arp[15:0]};
      rg_tmp_arp <= zeroExtend(data);
      succeed_and_next(rg_offset + 128);
   endrule

   rule parse_arp_2 ((rg_parse_state == StateParseArp) && (rg_offset == 256));
      report_parse_action(rg_parse_state, rg_offset, din);
      Bit#(272) data = {din, rg_tmp_arp[143:0]};
      Vector#(272, Bit#(1)) dataVec = unpack(data);
      let arp = extract_arp(pack(takeAt(0, dataVec)));
      rg_parse_state <= StateParseStart;
      // push_phv();
      succeed_and_next(rg_offset + 128);
   endrule

   function ParserState compute_next_state_udp(Bit#(16) dstPort);
      ParserState nextState = StateParseStart;
      case (byteSwap(dstPort)) matches
         'h8888: begin
            nextState=StateParsePaxos;
         end
         default: begin
            nextState=StateParseStart;
         end
      endcase
      return nextState;
   endfunction

   rule parse_udp ((rg_parse_state == StateParseUdp) && (rg_offset == 384));
      report_parse_action(rg_parse_state, rg_offset, din);
      Bit#(240) data = {din, rg_tmp_udp};
      Vector#(240, Bit#(1)) dataVec = unpack(data);
      Vector#(176, Bit#(1)) unparsed = takeAt(64, dataVec);
      let udp = extract_udp(pack(takeAt(0, dataVec)));
      let next_state = compute_next_state_udp(udp.dstPort);
      rg_parse_state <= next_state;
      if (next_state == StateParsePaxos) begin
         rg_tmp_paxos <= zeroExtend(pack(unparsed));
      end
      else begin
         // fail_and_trap();
      end
      succeed_and_next(rg_offset + 128);
   endrule

   rule parse_paxos_1 ((rg_parse_state == StateParsePaxos) && (rg_offset == 512));
      report_parse_action(rg_parse_state, rg_offset, din);
      Bit#(304) data = zeroExtend({din, rg_tmp_paxos[175:0]});
      rg_tmp_paxos <= data;
      succeed_and_next(rg_offset + 128);
   endrule

   rule parse_paxos_2 ((rg_parse_state == StateParsePaxos) && (rg_offset == 640));
      report_parse_action(rg_parse_state, rg_offset, din);
      Bit#(432) data = {din, rg_tmp_paxos};
      Vector#(432, Bit#(1)) dataVec = unpack(data);
      let paxos = extract_paxos(pack(takeAt(0, dataVec)));
      $display("(%0d) extracted ", $time, fshow(paxos));
      rg_parse_state <= StateParseStart;
      // push_phv();
      succeed_and_next(0);
   endrule

   interface frameIn = toPut(data_in_ff);
   interface meta = toGet(meta_out_ff);
   method Action set_verbosity(int verbosity);
      cr_verbosity_ff.enq(verbosity);
   endmethod
endmodule

