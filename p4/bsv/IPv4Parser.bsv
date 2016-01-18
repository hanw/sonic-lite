// Copyright (c) 2015 Cornell University.

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
import Connectable::*;
import DefaultValue::*;
import FIFO::*;
import FIFOF::*;
import FShow::*;
import GetPut::*;
import List::*;
import Pipe::*;
import StmtFSM::*;
import SpecialFIFOs::*;
import Vector::*;

import Ethernet::*;
import P4Types::*;

interface Parser;
   interface PipeIn#(EtherData) frameIn;
   interface PipeOut#(Bit#(32)) parsedOut_ipv4_dstAddr;
endinterface

interface ParseEthernet;
   interface PipeOut#(Bit#(16)) unparsedOutIpv4;
   interface PipeOut#(Bit#(16)) unparsedOutVlan;
   method Action start;
   method Action clear;
endinterface

interface ParseVlan;
   interface PipeIn#(Bit#(16)) unparsedIn;
   interface PipeOut#(Bit#(112)) unparsedOutVlan0;
   method Action start;
   method Action clear;
endinterface

interface ParseIpv4;
   interface PipeIn#(Bit#(16)) unparsedIn;
   interface PipeIn#(Bit#(112)) unparsedInVlan0;
   interface PipeOut#(Bit#(112)) unparsedOut;
   interface PipeOut#(Bit#(32)) parsedOut_ipv4_dstAddr;
   method Action start;
   method Action clear;
endinterface

typedef enum {S0, S1, S2, S3, S4} ParserState deriving (Bits, Eq);
instance FShow#(ParserState);
   function Fmt fshow (ParserState state);
      return $format(" State %x", state);
   endfunction
endinstance

module mkInitialState#(Reg#(ParserState) state, FIFOF#(EtherData) datain, Wire#(Bool) start_fsm)(Empty);
   let verbose = True;
   Reg#(Cycle_t) cycle <- mkReg(defaultValue);
   rule every if (verbose);
      cycle.cnt <= cycle.cnt + 1;
   endrule

   rule load_packet_in if (state == S0);
      let v = datain.first;
      if (v.sop) begin
         state <= S1;
         if (verbose) $display("Parser:: ", fshow(cycle) + fshow("Done with") + fshow(state) + fshow(v));
         start_fsm <= True;
      end
      else begin
         datain.deq;
         if (verbose) $display("Parser:: ", fshow(cycle) + fshow("in") + fshow(state));
         start_fsm <= False;
      end
   endrule
endmodule

module mkParseEthernet#(Reg#(ParserState) state, FIFOF#(EtherData) datain)(ParseEthernet);
   FIFOF#(Bit#(16))  unparsed_out_parse_ipv4_fifo <- mkSizedFIFOF(1);
   FIFOF#(Bit#(16))  unparsed_out_parse_vlan_fifo <- mkSizedFIFOF(1);

   Wire#(Bit#(128)) packet_in_wire <- mkDWire(0);
   Vector#(1, Wire#(Maybe#(ParserState))) next_state_wire <- replicateM(mkDWire(tagged Invalid));

   let verbose = True;
   Reg#(Cycle_t) cycle <- mkReg(defaultValue);
   rule cycleRule if (verbose);
      cycle.cnt <= cycle.cnt + 1;
   endrule

   (* fire_when_enabled *)
   rule arbitrate_outgoing_state if (state == S1);
      Vector#(1, Bool) next_state_valid = replicate(False);
      Bool stateSet = False;
      for (Integer port=0; port<1; port=port+1) begin
         next_state_valid[port] = isValid(next_state_wire[port]);
         if (!stateSet && next_state_valid[port]) begin
            stateSet = True;
            ParserState next_state = fromMaybe(?, next_state_wire[port]);
            state <= next_state;
         end
      end
   endrule

   rule load_packet_in if (state == S1);
      let data_current <- toGet(datain).get;
      packet_in_wire <= data_current.data;
      $display("Parser::mkParseEthernet ", fshow(cycle) + fshow("loading packet") + fshow(data_current));
   endrule

   Stmt parse_ethernet =
   seq
   action // parse_ethernet
      let data = packet_in_wire;
      Vector#(128, Bit#(1)) dataVec = unpack(data);
      let ethernet = extrace_ethernet(pack(takeAt(0, dataVec)));
      Vector#(16, Bit#(1)) unparsed = takeAt(112, dataVec);
      if (verbose) $display("Parser:: ", fshow(cycle)
                            +fshow(" ether.dstAddr=")+fshow(ethernet.dstAddr)
                            +fshow(" ether.srcAddr=")+fshow(ethernet.srcAddr)
                            +fshow(" ether.etherType=")+fshow(ethernet.etherType));

      ParserState nextState = S0;
      case (byteSwap2B(ethernet.etherType)) matches
         'h_8100: begin
            unparsed_out_parse_vlan_fifo.enq(pack(unparsed));
            nextState = S2;
         end
         'h_9100: begin
            nextState = S2;
         end
         'h_0800: begin
            unparsed_out_parse_ipv4_fifo.enq(pack(unparsed));
            nextState = S3;
         end
         default: begin
            $display("null");
         end
      endcase
      next_state_wire[0] <= tagged Valid nextState;
   endaction
   endseq;

   FSM fsm_parse_ethernet <- mkFSM(parse_ethernet);

   method Action start();
      fsm_parse_ethernet.start;
   endmethod
   method Action clear();
      fsm_parse_ethernet.abort;
   endmethod
   interface unparsedOutIpv4 = toPipeOut(unparsed_out_parse_ipv4_fifo);
   interface unparsedOutVlan = toPipeOut(unparsed_out_parse_vlan_fifo);
endmodule

// Parse second VLAN
module mkParseVlan#(Reg#(ParserState) state, FIFOF#(EtherData) datain)(ParseVlan);
   FIFOF#(Bit#(16)) unparsed_in_fifo <- mkBypassFIFOF;
   FIFOF#(Bit#(16)) unparsed_in_fifo_vlan0 <- mkBypassFIFOF;
   FIFOF#(Bit#(112)) unparsed_out_parse_vlan0_fifo <- mkSizedFIFOF(1);
   FIFOF#(Bit#(80)) unparsed_out_parse_vlan1_fifo <- mkSizedFIFOF(1);

   Wire#(Bit#(128)) packet_in_wire <- mkDWire(0);
   Vector#(2, Wire#(Maybe#(ParserState))) next_state_wire <- replicateM(mkDWire(tagged Invalid));

   let verbose = True;
   Reg#(Cycle_t) cycle <- mkReg(defaultValue);
   rule every if (verbose);
      cycle.cnt <= cycle.cnt + 1;
   endrule

   (* fire_when_enabled *)
   rule arbitrate_outgoing_state if (state == S2);
      Vector#(2, Bool) next_state_valid = replicate(False);
      Bool stateSet = False;
      for (Integer port=0; port<2; port=port+1) begin
         next_state_valid[port] = isValid(next_state_wire[port]);
         if (!stateSet && next_state_valid[port]) begin
            stateSet = True;
            ParserState next_state = fromMaybe(?, next_state_wire[port]);
            state <= next_state;
         end
      end
   endrule

   function ParserState compute_next_state(Bit#(16) etherType);
      ParserState nextState = S0;
      case (byteSwap2B(etherType)) matches
         'h_8100: begin
            nextState = S2;
         end
         'h_9100: begin
            nextState = S2;
         end
         'h_0800: begin
            nextState = S3;
         end
      endcase
      return nextState;
   endfunction

   rule load_packet_in if (state == S2);
      let data_current <- toGet(datain).get;
      packet_in_wire <= data_current.data;
      $display("Parser::mkParseVlan ", fshow(cycle) + fshow("loading packet ") + fshow(data_current));
   endrule

   rule load_unparsed_in if (state == S2);
      let data_delayed <- toGet(unparsed_in_fifo).get;
      unparsed_in_fifo_vlan0.enq(data_delayed);
      if (verbose) $display("Parser:: ", fshow(cycle) + fshow("load unparsed in"));
   endrule

   Stmt parse_vlan_0 =
   // VLAN
   seq
   action
      let data_delayed <- toGet(unparsed_in_fifo_vlan0).get;
      let data_current = packet_in_wire;
      $display("VLAN %x", data_current);
      Bit#(144) data = {data_current, data_delayed};
      Vector#(144, Bit#(1)) dataVec = unpack(data);
      let vlan0 = extract_vlan(pack(takeAt(0, dataVec)));
      let nextState0 = compute_next_state(vlan0.etherType);
      let residue0 = takeAt(32, dataVec);
      if (nextState0 == S3) begin
         if (verbose) $display("Parser:: ", fshow(cycle) + fshow("Vlan etherType=") + fshow(vlan0.etherType));
         unparsed_out_parse_vlan0_fifo.enq(pack(residue0));
         next_state_wire[0] <= tagged Valid nextState0;
      end
   endaction
   endseq;

   FSM fsm_parse_vlan_0 <- mkFSM(parse_vlan_0);

   method Action start;
      fsm_parse_vlan_0.start;
   endmethod
   method Action clear;
      fsm_parse_vlan_0.abort;
   endmethod

   interface unparsedIn = toPipeIn(unparsed_in_fifo);
   interface unparsedOutVlan0 = toPipeOut(unparsed_out_parse_vlan0_fifo);
endmodule

module mkParseIpv4#(Reg#(ParserState) state, FIFOF#(EtherData) datain)(ParseIpv4);

   FIFOF#(Bit#(16)) unparsed_in_fifo <- mkBypassFIFOF;
   FIFOF#(Bit#(112)) unparsed_in_vlan0_fifo <- mkBypassFIFOF;
   FIFOF#(Bit#(112)) unparsed_out_fifo <- mkSizedFIFOF(1);
   FIFOF#(Bit#(144)) internal_fifo <- mkSizedFIFOF(1);

   FIFOF#(Bit#(32)) parsed_ipv4_fifo <- mkFIFOF;

   Wire#(Bit#(128)) packet_in_wire <- mkDWire(0);
   Vector#(3, Wire#(Maybe#(ParserState))) next_state_wire <- replicateM(mkDWire(tagged Invalid));

   let verbose = True;
   Reg#(Cycle_t) cycle <- mkReg(defaultValue);
   rule every if (verbose);
      cycle.cnt <= cycle.cnt + 1;
   endrule

   // Parse State
   (* fire_when_enabled *)
   rule arbitrate_outgoing_state if (state == S3);
      Vector#(3, Bool) next_state_valid = replicate(False);
      Bool stateSet = False;
      for (Integer port=0; port<3; port=port+1) begin
         next_state_valid[port] = isValid(next_state_wire[port]);
         if (!stateSet && next_state_valid[port]) begin
            stateSet = True;
            ParserState next_state = fromMaybe(?, next_state_wire[port]);
            state <= next_state;
         end
      end
   endrule

   // Parse Data In
   rule load_packet_in if (state == S3);
      let data_current <- toGet(datain).get;
      packet_in_wire <= data_current.data;
      $display("Parser::mkParserIpv4 ", fshow(cycle) + fshow("loading packet ") + fshow(data_current));
   endrule

   // Parse State Machine
   Stmt parse_ipv4_0 =
   // IP
   seq
   action // parse_ipv4
      let residue_last <- toGet(unparsed_in_fifo).get; // 16-bit
      let data_current = packet_in_wire;
      Bit#(144) data = {data_current, residue_last};
      Vector#(144, Bit#(1)) dataVec = unpack(data);
      internal_fifo.enq(data);
      if (verbose) $display("Parser:: ", fshow(cycle) + fshow("wait one cycle!"));
   endaction
   action // parse_ipv4 0
      let data_delayed <- toGet(internal_fifo).get;
      let data_current = packet_in_wire;
      Bit#(272) data = {data_current, data_delayed};
      Vector#(272, Bit#(1)) dataVec = unpack(data);
      Vector#(112, Bit#(1)) residue = takeAt(160, dataVec);
      let ipv4 = extract_ipv4(data[159:0]);
      if (verbose) $display("Parser:: ", fshow(cycle)+
                            $format(" ipv4.srcAddr=%x", ipv4.srcAddr)+
                            $format(" ipv4.dstAddr=%x", ipv4.dstAddr));
      parsed_ipv4_fifo.enq(ipv4.dstAddr);
      next_state_wire[0] <= tagged Valid S0;
   endaction
   endseq;

   FSM fsm_parse_ipv4_0 <- mkFSM(parse_ipv4_0);

   method Action start();
      fsm_parse_ipv4_0.start;
   endmethod
   method Action clear();
      fsm_parse_ipv4_0.abort;
   endmethod
   interface unparsedIn = toPipeIn(unparsed_in_fifo);
   interface unparsedOut = toPipeOut(unparsed_out_fifo);
   interface parsedOut_ipv4_dstAddr = toPipeOut(parsed_ipv4_fifo);
endmodule

(* synthesize *)
module mkParser(Parser);
   Reg#(ParserState) curr_state <- mkReg(S0);
   Reg#(Bool) started <- mkReg(False);
   FIFOF#(EtherData) data_in_fifo <- mkFIFOF;
   Wire#(Bool) start_fsm <- mkDWire(False);

   Empty init_state <- mkInitialState(curr_state, data_in_fifo, start_fsm);
   ParseEthernet parse_ethernet <- mkParseEthernet(curr_state, data_in_fifo);
   ParseVlan parse_vlan <- mkParseVlan(curr_state, data_in_fifo);
   ParseIpv4 parse_ipv4 <- mkParseIpv4(curr_state, data_in_fifo);


   List#(Reg#(Vlan_tag_t)) vlan_tag_stack <- List::replicateM(2, mkReg(defaultValue));

   mkConnection(parse_ethernet.unparsedOutIpv4, parse_ipv4.unparsedIn);
   mkConnection(parse_ethernet.unparsedOutVlan, parse_vlan.unparsedIn);
   mkConnection(parse_vlan.unparsedOutVlan0, parse_ipv4.unparsedInVlan0);

   let verbose = True;
   Reg#(Cycle_t) cycle <- mkReg(defaultValue);
   rule every if (verbose);
      cycle.cnt <= cycle.cnt + 1;
   endrule

   rule start_parser_fsm if (start_fsm);
      if (!started) begin
         parse_ethernet.start;
         parse_vlan.start;
         parse_ipv4.start;
         started <= True;
         $display("Parser:: start fsm", fshow(cycle));
      end
   endrule

   rule reset_parser_fsm if (!start_fsm && curr_state==S0);
      if (started) begin
         parse_ethernet.clear;
         parse_ipv4.clear;
         parse_vlan.clear;
         started <= False;
         $display("Parser:: reset fsm", fshow(cycle));
      end
   endrule

   // derive parse done from state machine
   interface frameIn = toPipeIn(data_in_fifo);
   interface parsedOut_ipv4_dstAddr = parse_ipv4.parsedOut_ipv4_dstAddr;
endmodule

