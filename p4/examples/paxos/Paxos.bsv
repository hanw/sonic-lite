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
import P4Types::*;
import PaxosTypes::*;
import Utils::*;

typedef enum {
   StateStart,
   StateParseEthernet,
   StateParseArp,
   StateParseIpv4,
   StateParseIpv6,
   StateParseCpuHeader,
   StateParseUdp,
   StateParsePaxos
} ParserState deriving (Bits, Eq);
instance FShow#(ParserState);
    function Fmt fshow (ParserState state);
        return $format(" State %x", state);
    endfunction
endinstance

module mkStateStart#(Reg#(ParserState) state, FIFOF#(EtherData) datain, Wire#(Bool) start_fsm)(Empty);

    rule load_packet if (state==StateStart);
        let v = datain.first;
        if (v.sop) begin
            state <= StateParseEthernet;
            start_fsm <= True;
        end
        else begin
            datain.deq;
            start_fsm <= False;
        end
    endrule
endmodule
interface ParseEthernet;
    interface Get#(Bit#(16)) parse_arp;
    interface Get#(Bit#(16)) parse_ipv4;
    interface Get#(Bit#(16)) parse_ipv6;
    interface Get#(Bit#(48)) parsedOut_ethernet_dstAddr;
    interface Get#(Bit#(16)) parsedOut_ethernet_etherType;
    method Action start;
    method Action clear;
endinterface
module mkStateParseEthernet#(Reg#(ParserState) state, FIFOF#(EtherData) datain)(ParseEthernet);
    FIFOF#(Bit#(16)) unparsed_parse_arp_fifo <- mkSizedFIFOF(1);
    FIFOF#(Bit#(16)) unparsed_parse_ipv4_fifo <- mkSizedFIFOF(1);
    FIFOF#(Bit#(16)) unparsed_parse_ipv6_fifo <- mkSizedFIFOF(1);

    FIFOF#(Bit#(48)) parsed_ethernet_fifo <- mkFIFOF;
    FIFOF#(Bit#(16)) parsed_etherType_fifo <- mkFIFOF;

    Wire#(Bit#(128)) packet_in_wire <- mkDWire(0);
    Vector#(4, Wire#(Maybe#(ParserState))) next_state_wire <- replicateM(mkDWire(tagged Invalid));
    PulseWire start_wire <- mkPulseWire();
    PulseWire clear_wire <- mkPulseWire();
    (* fire_when_enabled *)
    rule arbitrate_outgoing_state if (state == StateParseEthernet);
        Vector#(4, Bool) next_state_valid = replicate(False);
        Bool stateSet = False;
        for (Integer port=0; port<4; port=port+1) begin
            next_state_valid[port] = isValid(next_state_wire[port]);
            if (!stateSet && next_state_valid[port]) begin
                stateSet = True;
                ParserState next_state = fromMaybe(?, next_state_wire[port]);
                state <= next_state;
            end
        end
    endrule
    function ParserState compute_next_state(Bit#(16) etherType);
        ParserState nextState = StateStart;
        case (etherType) matches
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
                nextState=StateStart;
            end
        endcase
        return nextState;
    endfunction
    rule load_packet if (state == StateParseEthernet);
        let data_current <- toGet(datain).get;
        packet_in_wire <= data_current.data;
    endrule
    Stmt parse_ethernet =
    seq
    action
        let data_this_cycle = packet_in_wire;
        Vector#(128, Bit#(1)) dataVec = unpack(data_this_cycle);
        let ethernet = extract_ethernet(pack(takeAt(0, dataVec)));
        $display("(%0d) ", $time, fshow(ethernet));
        Vector#(16, Bit#(1)) unparsed = takeAt(112, dataVec);
        let nextState = compute_next_state(ethernet.etherType);
        $display("(%0d) Goto state %h", $time, nextState);
        if (nextState == StateParseArp) begin
            unparsed_parse_arp_fifo.enq(pack(unparsed));
        end
        if (nextState == StateParseIpv4) begin
            unparsed_parse_ipv4_fifo.enq(pack(unparsed));
        end
        if (nextState == StateParseIpv6) begin
            unparsed_parse_ipv6_fifo.enq(pack(unparsed));
        end
        parsed_ethernet_fifo.enq(ethernet.dstAddr);
        parsed_etherType_fifo.enq(ethernet.etherType);
        next_state_wire[0] <= tagged Valid nextState;
    endaction
    endseq;
    FSM fsm_parse_ethernet <- mkFSM(parse_ethernet);
    rule start_fsm if (start_wire);
        fsm_parse_ethernet.start;
    endrule
    rule clear_fsm if (clear_wire);
        fsm_parse_ethernet.abort;
    endrule
    method Action start();
        start_wire.send();
    endmethod
    method Action clear();
        clear_wire.send();
    endmethod
    interface parse_arp = toGet(unparsed_parse_arp_fifo);
    interface parse_ipv4 = toGet(unparsed_parse_ipv4_fifo);
    interface parse_ipv6 = toGet(unparsed_parse_ipv6_fifo);
    interface parsedOut_ethernet_dstAddr = toGet(parsed_ethernet_fifo);
    interface parsedOut_ethernet_etherType = toGet(parsed_etherType_fifo);
endmodule
interface ParseArp;
    interface Put#(Bit#(16)) parse_ethernet;
    method Action start;
    method Action clear;
endinterface
module mkStateParseArp#(Reg#(ParserState) state, FIFOF#(EtherData) datain)(ParseArp);
    FIFOF#(Bit#(144)) internal_fifo <- mkSizedFIFOF(1);
    FIFOF#(Bit#(16)) unparsed_parse_ethernet_fifo <- mkBypassFIFOF;
    Wire#(Bit#(128)) packet_in_wire <- mkDWire(0);
    Vector#(1, Wire#(Maybe#(ParserState))) next_state_wire <- replicateM(mkDWire(tagged Invalid));
    PulseWire start_wire <- mkPulseWire();
    PulseWire clear_wire <- mkPulseWire();
    (* fire_when_enabled *)
    rule arbitrate_outgoing_state if (state == StateParseArp);
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
    rule load_packet if (state == StateParseArp);
        let data_current <- toGet(datain).get;
        packet_in_wire <= data_current.data;
    endrule
    Stmt parse_arp =
    seq
    action
        let data_this_cycle = packet_in_wire;
        let data_last_cycle <- toGet(unparsed_parse_ethernet_fifo).get;
        Bit#(144) data = {data_this_cycle, data_last_cycle};
        Vector#(144, Bit#(1)) dataVec = unpack(data);
        internal_fifo.enq(data);
    endaction
    action
        let data_this_cycle = packet_in_wire;
        let data_last_cycle <- toGet(internal_fifo).get;
        Bit#(272) data = {data_this_cycle, data_last_cycle};
        Vector#(272, Bit#(1)) dataVec = unpack(data);
        let arp = extract_arp(pack(takeAt(0, dataVec)));
        $display("(%0d) ", $time, fshow(arp));
        next_state_wire[0] <= tagged Valid StateStart;
    endaction
    endseq;
    FSM fsm_parse_arp <- mkFSM(parse_arp);
    rule start_fsm if (start_wire);
        fsm_parse_arp.start;
    endrule
    rule clear_fsm if (clear_wire);
        fsm_parse_arp.abort;
    endrule
    method Action start();
        start_wire.send();
    endmethod
    method Action clear();
        clear_wire.send();
    endmethod
    interface parse_ethernet = toPut(unparsed_parse_ethernet_fifo);
endmodule
interface ParseIpv4;
    interface Put#(Bit#(16)) parse_ethernet;
    interface Get#(Bit#(112)) parse_udp;
    interface Get#(Bit#(8)) parsedOut_ipv4_protocol;
    method Action start;
    method Action clear;
endinterface
module mkStateParseIpv4#(Reg#(ParserState) state, FIFOF#(EtherData) datain)(ParseIpv4);
    FIFOF#(Bit#(16)) unparsed_parse_ethernet_fifo <- mkBypassFIFOF;
    FIFOF#(Bit#(112)) unparsed_parse_udp_fifo <- mkSizedFIFOF(1);
    FIFOF#(Bit#(8)) parsed_ipv4_protocol_fifo <- mkFIFOF;
    FIFOF#(Bit#(144)) internal_fifo <- mkSizedFIFOF(1);
    Wire#(Bit#(128)) packet_in_wire <- mkDWire(0);
    Vector#(2, Wire#(Maybe#(ParserState))) next_state_wire <- replicateM(mkDWire(tagged Invalid));
    PulseWire start_wire <- mkPulseWire();
    PulseWire clear_wire <- mkPulseWire();
    (* fire_when_enabled *)
    rule arbitrate_outgoing_state if (state == StateParseIpv4);
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
    function ParserState compute_next_state(Bit#(8) protocol);
        ParserState nextState = StateStart;
        case (protocol) matches
            'h11: begin
                nextState=StateParseUdp;
            end
            default: begin
                nextState=StateStart;
            end
        endcase
        return nextState;
    endfunction
    rule load_packet if (state == StateParseIpv4);
        let data_current <- toGet(datain).get;
        packet_in_wire <= data_current.data;
    endrule
    Stmt parse_ipv4 =
    seq
    action
        let data_this_cycle = packet_in_wire;
        let data_last_cycle <- toGet(unparsed_parse_ethernet_fifo).get;
        Bit#(144) data = {data_this_cycle, data_last_cycle};
        Vector#(144, Bit#(1)) dataVec = unpack(data);
        internal_fifo.enq(data);
    endaction
    action
        let data_this_cycle = packet_in_wire;
        let data_last_cycle <- toGet(internal_fifo).get;
        Bit#(272) data = {data_this_cycle, data_last_cycle};
        Vector#(272, Bit#(1)) dataVec = unpack(data);
        let ipv4 = extract_ipv4(pack(takeAt(0, dataVec)));
        $display("(%0d) ", $time, fshow(ipv4));
        Vector#(112, Bit#(1)) unparsed = takeAt(160, dataVec);
        let nextState = compute_next_state(ipv4.protocol);
        $display("(%0d) Goto state %h", $time, nextState);
        if (nextState == StateParseUdp) begin
            unparsed_parse_udp_fifo.enq(pack(unparsed));
        end
        parsed_ipv4_protocol_fifo.enq(ipv4.protocol);
        next_state_wire[0] <= tagged Valid nextState;
    endaction
    endseq;
    FSM fsm_parse_ipv4 <- mkFSM(parse_ipv4);
    rule start_fsm if (start_wire);
        fsm_parse_ipv4.start;
    endrule
    rule clear_fsm if (clear_wire);
        fsm_parse_ipv4.abort;
    endrule
    method Action start();
        start_wire.send();
    endmethod
    method Action clear();
        clear_wire.send();
    endmethod
    interface parse_ethernet = toPut(unparsed_parse_ethernet_fifo);
    interface parse_udp = toGet(unparsed_parse_udp_fifo);
    interface parsedOut_ipv4_protocol = toGet(parsed_ipv4_protocol_fifo);
endmodule
interface ParseIpv6;
    interface Put#(Bit#(16)) parse_ethernet;
    method Action start;
    method Action clear;
endinterface
module mkStateParseIpv6#(Reg#(ParserState) state, FIFOF#(EtherData) datain, FIFOF#(ParserState) parseStateFifo)(ParseIpv6);
    FIFOF#(Bit#(16)) unparsed_parse_ethernet_fifo <- mkBypassFIFOF;
    FIFOF#(Bit#(144)) internal_fifo <- mkSizedFIFOF(1);
    FIFOF#(Bit#(272)) internal_fifo2 <- mkSizedFIFOF(1);
    Wire#(Bit#(128)) packet_in_wire <- mkDWire(0);
    Vector#(1, Wire#(Maybe#(ParserState))) next_state_wire <- replicateM(mkDWire(tagged Invalid));
    PulseWire start_wire <- mkPulseWire();
    PulseWire clear_wire <- mkPulseWire();
    (* fire_when_enabled *)
    rule arbitrate_outgoing_state if (state == StateParseIpv6);
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

    rule load_packet if (state == StateParseIpv6);
        let data_current <- toGet(datain).get;
        packet_in_wire <= data_current.data;
    endrule
    Stmt parse_ipv6 =
    seq
    action
        let data_this_cycle = packet_in_wire;
        let data_last_cycle <- toGet(unparsed_parse_ethernet_fifo).get;
        Bit#(144) data = {data_this_cycle, data_last_cycle};
        internal_fifo.enq(data);
    endaction
    action
        let data_this_cycle = packet_in_wire;
        let data_last_cycle <- toGet(internal_fifo).get;
        Bit#(272) data = {data_this_cycle, data_last_cycle};
        internal_fifo2.enq(data);
    endaction
    action
        let data_this_cycle = packet_in_wire;
        let data_last_cycle <- toGet(internal_fifo2).get;
        Bit#(400) data = {data_this_cycle, data_last_cycle};
        Vector#(400, Bit#(1)) dataVec = unpack(data);
        let ipv6 = extract_ipv6(pack(takeAt(0, dataVec)));
        $display("(%0d) ", $time, fshow(ipv6));
        parseStateFifo.enq(StateParseIpv6);
        next_state_wire[0] <= tagged Valid StateStart;
    endaction
    endseq;
    FSM fsm_parse_ipv6 <- mkFSM(parse_ipv6);
    rule start_fsm if (start_wire);
        fsm_parse_ipv6.start;
    endrule
    rule clear_fsm if (clear_wire);
        fsm_parse_ipv6.abort;
    endrule
    method Action start();
        start_wire.send();
    endmethod
    method Action clear();
        clear_wire.send();
    endmethod
    interface parse_ethernet = toPut(unparsed_parse_ethernet_fifo);
endmodule
interface ParseUdp;
    interface Put#(Bit#(112)) parse_ipv4;
    interface Get#(Bit#(176)) parse_paxos;
    interface Get#(Bit#(16)) parsedOut_udp_dstPort;
    method Action start;
    method Action clear;
endinterface
module mkStateParseUdp#(Reg#(ParserState) state, FIFOF#(EtherData) datain, FIFOF#(ParserState) parseStateFifo)(ParseUdp);
    FIFOF#(Bit#(112)) unparsed_parse_ipv4_fifo <- mkBypassFIFOF;
    FIFOF#(Bit#(176)) unparsed_parse_paxos_fifo <- mkSizedFIFOF(1);
    FIFOF#(Bit#(16)) parsed_udp_dstPort_fifo <- mkFIFOF;
    Wire#(Bit#(128)) packet_in_wire <- mkDWire(0);
    Vector#(2, Wire#(Maybe#(ParserState))) next_state_wire <- replicateM(mkDWire(tagged Invalid));
    PulseWire start_wire <- mkPulseWire();
    PulseWire clear_wire <- mkPulseWire();
    (* fire_when_enabled *)
    rule arbitrate_outgoing_state if (state == StateParseUdp);
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
    function ParserState compute_next_state(Bit#(16) dstPort);
        ParserState nextState = StateStart;
        case (dstPort) matches
            'h8887: begin
                nextState=StateParsePaxos;
            end
            'h8888: begin
                nextState=StateParsePaxos;
            end
            'h8889: begin
                nextState=StateParsePaxos;
            end
            default: begin
                nextState=StateStart;
            end
        endcase
        return nextState;
    endfunction
    rule load_packet if (state == StateParseUdp);
        let data_current <- toGet(datain).get;
        packet_in_wire <= data_current.data;
    endrule
    Stmt parse_udp =
    seq
    action
        let data_this_cycle = packet_in_wire;
        let data_last_cycle <- toGet(unparsed_parse_ipv4_fifo).get;
        Bit#(240) data = {data_this_cycle, data_last_cycle};
        Vector#(240, Bit#(1)) dataVec = unpack(data);
        let udp = extract_udp(pack(takeAt(0, dataVec)));
        $display("(%0d) ", $time, fshow(udp));
        Vector#(176, Bit#(1)) unparsed = takeAt(64, dataVec);
        let nextState = compute_next_state(udp.dstPort);
        $display("(%0d) Goto state %h", $time, nextState);
        if (nextState == StateParsePaxos) begin
            unparsed_parse_paxos_fifo.enq(pack(unparsed));
        end
        else begin
            parseStateFifo.enq(StateParseUdp);
        end
        parsed_udp_dstPort_fifo.enq(udp.dstPort);
        next_state_wire[0] <= tagged Valid nextState;
    endaction
    endseq;
    FSM fsm_parse_udp <- mkFSM(parse_udp);
    rule start_fsm if (start_wire);
        fsm_parse_udp.start;
    endrule
    rule clear_fsm if (clear_wire);
        fsm_parse_udp.abort;
    endrule
    method Action start();
        start_wire.send();
    endmethod
    method Action clear();
        clear_wire.send();
    endmethod
    interface parse_ipv4 = toPut(unparsed_parse_ipv4_fifo);
    interface parse_paxos = toGet(unparsed_parse_paxos_fifo);
    interface parsedOut_udp_dstPort = toGet(parsed_udp_dstPort_fifo);
endmodule
interface ParsePaxos;
    interface Put#(Bit#(176)) parse_udp;
    interface Get#(PaxosT) parsedOut_paxos_msgtype;
    method Action start;
    method Action clear;
endinterface
module mkStateParsePaxos#(Reg#(ParserState) state, FIFOF#(EtherData) datain, FIFOF#(ParserState) parseStateFifo)(ParsePaxos);
    FIFOF#(Bit#(304)) internal_fifo <- mkSizedFIFOF(1);
    FIFOF#(Bit#(176)) unparsed_parse_udp_fifo <- mkBypassFIFOF;
    FIFOF#(PaxosT) parsed_paxos_fifo <- mkFIFOF;
    Wire#(Bit#(128)) packet_in_wire <- mkDWire(0);
    Vector#(1, Wire#(Maybe#(ParserState))) next_state_wire <- replicateM(mkDWire(tagged Invalid));
    PulseWire start_wire <- mkPulseWire();
    PulseWire clear_wire <- mkPulseWire();
    (* fire_when_enabled *)
    rule arbitrate_outgoing_state if (state == StateParsePaxos);
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
    
    rule load_packet if (state == StateParsePaxos);
        let data_current <- toGet(datain).get;
        packet_in_wire <= data_current.data;
    endrule
    Stmt parse_paxos =
    seq
    action
        let data_this_cycle = packet_in_wire;
        let data_last_cycle <- toGet(unparsed_parse_udp_fifo).get;
        Bit#(304) data = {data_this_cycle, data_last_cycle};
        internal_fifo.enq(data);
    endaction
    action
        let data_this_cycle= packet_in_wire;
        let data_last_cycle <- toGet(internal_fifo).get;
        Bit#(432) data = {data_this_cycle, data_last_cycle};
        Vector#(432, Bit#(1)) dataVec = unpack(data);
        let paxos = extract_paxos(pack(takeAt(0, dataVec)));
        $display("(%0d) ", $time, fshow(paxos));
        parsed_paxos_fifo.enq(paxos);
        parseStateFifo.enq(StateParsePaxos);
        next_state_wire[0] <= tagged Valid StateStart;
    endaction
    endseq;
    FSM fsm_parse_paxos <- mkFSM(parse_paxos);
    rule start_fsm if (start_wire);
        fsm_parse_paxos.start;
    endrule
    rule clear_fsm if (clear_wire);
        fsm_parse_paxos.abort;
    endrule
    method Action start();
        start_wire.send();
    endmethod
    method Action clear();
        clear_wire.send();
    endmethod
    interface parse_udp = toPut(unparsed_parse_udp_fifo);
    interface parsedOut_paxos_msgtype = toGet(parsed_paxos_fifo);
endmodule
interface Parser;
    interface Put#(EtherData) frameIn;
    //interface Get#(Bit#(48)) parsedOut_ethernet_dstAddr;
    //interface Get#(Bit#(16)) parsedOut_paxos_msgtype;
    //interface PipeOut#(ParserState) parserState;
    interface Get#(MetadataT) meta;
    method ParserPerfRec read_perf_info;
   method Action set_verbosity(int verbosity);
endinterface

typedef 4 PortMax;
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

    let verbose = True;
    Reg#(ParserState) curr_state <- mkReg(StateStart);
    Reg#(Bool) started <- mkReg(False);
    FIFOF#(EtherData) data_in_fifo <- mkFIFOF;
    Wire#(Bool) start_fsm <- mkDWire(False);

    Vector#(PortMax, FIFOF#(ParserState)) parse_state_in_fifo <- replicateM(mkGFIFOF(False, True)); // unguarded deq
    FIFOF#(ParserState) parse_state_out_fifo <- mkFIFOF;
    FIFOF#(MetadataT) metadata_out_fifo <- mkFIFOF;

    Reg#(Bit#(32)) clk_cnt <- mkReg(0);
    Reg#(Bit#(32)) parser_start_time <- mkReg(0);
    Reg#(Bit#(32)) parser_end_time <- mkReg(0);
    rule clockrule;
       clk_cnt <= clk_cnt + 1;
    endrule

    (* fire_when_enabled *)
    rule arbitrate_parse_state;
       Bool sentOne = False;
       for (Integer port = 0; port < valueOf(PortMax); port = port+1) begin
          if (!sentOne && parse_state_in_fifo[port].notEmpty()) begin
             ParserState state <- toGet(parse_state_in_fifo[port]).get();
             sentOne = True;
             $display("(%0d) xxx arbitrate %h", $time, port);
             parse_state_out_fifo.enq(state);
          end
       end
    endrule

    Empty init_state <- mkStateStart(curr_state, data_in_fifo, start_fsm);
    ParseEthernet parse_ethernet <- mkStateParseEthernet(curr_state, data_in_fifo);
    ParseArp parse_arp <- mkStateParseArp(curr_state, data_in_fifo);
    ParseIpv4 parse_ipv4 <- mkStateParseIpv4(curr_state, data_in_fifo);
    ParseIpv6 parse_ipv6 <- mkStateParseIpv6(curr_state, data_in_fifo, parse_state_in_fifo[0]);
    ParseUdp parse_udp <- mkStateParseUdp(curr_state, data_in_fifo, parse_state_in_fifo[1]);
    ParsePaxos parse_paxos <- mkStateParsePaxos(curr_state, data_in_fifo, parse_state_in_fifo[2]);
    mkConnection(parse_arp.parse_ethernet, parse_ethernet.parse_arp);
    mkConnection(parse_ipv4.parse_ethernet, parse_ethernet.parse_ipv4);
    mkConnection(parse_ipv6.parse_ethernet, parse_ethernet.parse_ipv6);
    mkConnection(parse_udp.parse_ipv4, parse_ipv4.parse_udp);
    mkConnection(parse_paxos.parse_udp, parse_udp.parse_paxos);
    rule start if (start_fsm);
        if (!started) begin
            parse_ethernet.start;
            parse_arp.start;
            parse_ipv4.start;
            parse_ipv6.start;
            parse_udp.start;
            parse_paxos.start;
            started <= True;
            parser_start_time <= clk_cnt;
        end
    endrule
    rule clear if (!start_fsm && curr_state == StateStart);
        if (started) begin
            parse_ethernet.clear;
            parse_arp.clear;
            parse_ipv4.clear;
            parse_ipv6.clear;
            parse_udp.clear;
            parse_paxos.clear;
            started <= False;
            parser_end_time <= clk_cnt;
        end
    endrule

    function Bit#(48) mac_from_ip(Bit#(32) ip_addr);
        Bit#(23) bits_ip = ip_addr[22:0];
        Bit#(24) lower_part = zeroExtend(bits_ip);
        Bit#(24) upper_part = 'h01005E;
        return {upper_part, lower_part};
    endfunction
   // new packet, issue metadata processing request to ingress pipeline
   // request issue after packet is committed to memory.
   rule handle_paxos_packet if (parse_state_out_fifo.first == StateParsePaxos);
      parse_state_out_fifo.deq;
      let dstAddr <- toGet(parse_ethernet.parsedOut_ethernet_dstAddr).get;
      let etherType <- toGet(parse_ethernet.parsedOut_ethernet_etherType).get;
      let protocol <- toGet(parse_ipv4.parsedOut_ipv4_protocol).get;
      let paxos <- toGet(parse_paxos.parsedOut_paxos_msgtype).get;
      let dstPort <- toGet(parse_udp.parsedOut_udp_dstPort).get;
        if (cr_verbosity[0] > 0)
            $display("(%0d) HostChannel: dstAddr=%h", $time, dstAddr);
        if (cr_verbosity[0] > 0)
            $display("(%0d) HostChannel: msgtype=%h", $time, paxos.msgtype);
      MetadataT meta = defaultValue;
      meta.etherType = tagged Valid etherType;
      meta.dstIP = tagged Valid 'hE0031D49;
      meta.dstAddr = tagged Valid mac_from_ip('hE0031D49);
      meta.dstPort = tagged Valid dstPort;
      meta.protocol = tagged Valid protocol;
      meta.paxos$msgtype = tagged Valid paxos.msgtype;
      meta.paxos$inst = tagged Valid paxos.inst;
      meta.paxos$rnd = tagged Valid paxos.rnd;
      meta.paxos$vrnd = tagged Valid paxos.vrnd;
      meta.paxos$acptid = tagged Valid paxos.acptid;
      meta.paxos$valuelen = tagged Valid paxos.valuelen;
      meta.paxos$paxosval = tagged Valid paxos.paxosval;
      meta.valid_paxos = tagged Valid True;
      meta.valid_ipv4 = tagged Valid True;
      meta.valid_ethernet = tagged Valid True;
      meta.valid_udp = tagged Valid True;
      metadata_out_fifo.enq(meta);
   endrule

   // redundant, remove!
   rule handle_unknown_ipv6_packet if (parse_state_out_fifo.first == StateParseIpv6);
      parse_state_out_fifo.deq;
      let dstAddr <- toGet(parse_ethernet.parsedOut_ethernet_dstAddr).get;
      // forward to drop table
      if (cr_verbosity[0] > 0)
        $display("(%0d) HostChannel unknown ipv6: dstAddr=%h, size=%d", $time, dstAddr);
      MetadataT meta = defaultValue;
      meta.dstAddr = tagged Valid dstAddr;
      meta.valid_ipv6 = tagged Valid True;
      meta.valid_ethernet = tagged Valid True;
      metadata_out_fifo.enq(meta);
   endrule

   rule handle_unknown_udp_packet if (parse_state_out_fifo.first == StateParseUdp);
      parse_state_out_fifo.deq;
      let dstAddr <- toGet(parse_ethernet.parsedOut_ethernet_dstAddr).get;
      if (cr_verbosity[0] > 0)
        $display("(%0d) HostChannel unknown udp: dstAddr=%h, size=%d", $time, dstAddr);
      MetadataT meta = defaultValue;
      meta.dstAddr = tagged Valid dstAddr;
      meta.valid_udp = tagged Valid True;
      meta.valid_ethernet = tagged Valid True;
      metadata_out_fifo.enq(meta);
   endrule

    interface frameIn = toPut(data_in_fifo);
    interface meta = toGet(metadata_out_fifo);
    method ParserPerfRec read_perf_info;
      return ParserPerfRec {
         parser_start_time: parser_start_time,
         parser_end_time: parser_end_time
      };
    endmethod
   method Action set_verbosity(int verbosity);
      cr_verbosity_ff.enq(verbosity);
   endmethod

endmodule

