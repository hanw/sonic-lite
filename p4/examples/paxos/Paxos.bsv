typedef struct {
    Bit#(4) version;
    Bit#(8) trafficClass;
    Bit#(20) flowLabel;
    Bit#(16) payloadLen;
    Bit#(8) nextHdr;
    Bit#(8) hopLimit;
    Bit#(128) srcAddr;
    Bit#(128) dstAddr;
} Ipv6T deriving (Bits, Eq);

instance DefaultValue#(Ipv6T);
defaultValue=
Ipv6T {
    version: 0,
    trafficClass: 0,
    flowLabel: 0,
    payloadLen: 0,
    nextHdr: 0,
    hopLimit: 0,
    srcAddr: 0,
    dstAddr: 0};
endinstance

instance FShow#(Ipv6T);
    function Fmt fshow(Ipv6T p);
        return $format("Ipv6T: version=%h, trafficClass=%h, flowLabel=%h, payloadLen=%h, nextHdr=%h, hopLimit=%h, srcAddr=%h, dstAddr=%h" , p.version, p.trafficClass, p.flowLabel, p.payloadLen, p.nextHdr, p.hopLimit, p.srcAddr, p.dstAddr);
    endfunction
endinstance

function Ipv6T extract_ipv6(Bit#(320) data);
    Vector#(320, Bit#(1)) dataVec=unpack(data);
    Vector#(4, Bit#(1)) version = takeAt(0, dataVec);
    Vector#(8, Bit#(1)) trafficClass = takeAt(4, dataVec);
    Vector#(20, Bit#(1)) flowLabel = takeAt(12, dataVec);
    Vector#(16, Bit#(1)) payloadLen = takeAt(32, dataVec);
    Vector#(8, Bit#(1)) nextHdr = takeAt(48, dataVec);
    Vector#(8, Bit#(1)) hopLimit = takeAt(56, dataVec);
    Vector#(128, Bit#(1)) srcAddr = takeAt(64, dataVec);
    Vector#(128, Bit#(1)) dstAddr = takeAt(192, dataVec);
    Ipv6T ipv6_t = defaultValue;
    ipv6_t.version = pack(version);
    ipv6_t.trafficClass = pack(trafficClass);
    ipv6_t.flowLabel = pack(flowLabel);
    ipv6_t.payloadLen = pack(payloadLen);
    ipv6_t.nextHdr = pack(nextHdr);
    ipv6_t.hopLimit = pack(hopLimit);
    ipv6_t.srcAddr = pack(srcAddr);
    ipv6_t.dstAddr = pack(dstAddr);
    return ipv6_t;
endfunction

typedef struct {
    Bit#(16) srcPort;
    Bit#(16) dstPort;
    Bit#(16) length_;
    Bit#(16) checksum;
} UdpT deriving (Bits, Eq);

instance DefaultValue#(UdpT);
defaultValue=
UdpT {
    srcPort: 0,
    dstPort: 0,
    length_: 0,
    checksum: 0
};
endinstance

instance FShow#(UdpT);
    function Fmt fshow(UdpT p);
        return $format("UdpT: srcPort=%h, dstPort=%h, length_=%h, checksum=%h" , p.srcPort, p.dstPort, p.length_, p.checksum);
    endfunction
endinstance

function UdpT extract_udp(Bit#(64) data);
    Vector#(64, Bit#(1)) dataVec=unpack(data);
    Vector#(16, Bit#(1)) srcPort = takeAt(0, dataVec);
    Vector#(16, Bit#(1)) dstPort = takeAt(16, dataVec);
    Vector#(16, Bit#(1)) length_ = takeAt(32, dataVec);
    Vector#(16, Bit#(1)) checksum = takeAt(48, dataVec);
    UdpT udp_t = defaultValue;
    udp_t.srcPort = pack(srcPort);
    udp_t.dstPort = pack(dstPort);
    udp_t.length_ = pack(length_);
    udp_t.checksum = pack(checksum);
    return udp_t;
endfunction

typedef struct {
    Bit#(32) inst;
    Bit#(16) rnd;
    Bit#(16) vrnd;
    Bit#(16) acptid;
    Bit#(16) msgtype;
    Bit#(256) paxosval;
} PaxosT deriving (Bits, Eq);

instance DefaultValue#(PaxosT);
defaultValue=
PaxosT {
    inst: 0,
    rnd: 0,
    vrnd: 0,
    acptid: 0,
    msgtype: 0,
    paxosval: 0
};
endinstance

instance FShow#(PaxosT);
    function Fmt fshow(PaxosT p);
        return $format("PaxosT: inst=%h, rnd=%h, vrnd=%h, acptid=%h, msgtype=%h, paxosval=%h" , p.inst, p.rnd, p.vrnd, p.acptid, p.msgtype, p.paxosval);
    endfunction
endinstance

function PaxosT extract_paxos(Bit#(352) data);
    Vector#(352, Bit#(1)) dataVec=unpack(data);
    Vector#(32, Bit#(1)) inst = takeAt(0, dataVec);
    Vector#(16, Bit#(1)) rnd = takeAt(32, dataVec);
    Vector#(16, Bit#(1)) vrnd = takeAt(48, dataVec);
    Vector#(16, Bit#(1)) acptid = takeAt(64, dataVec);
    Vector#(16, Bit#(1)) msgtype = takeAt(80, dataVec);
    Vector#(256, Bit#(1)) paxosval = takeAt(96, dataVec);
    PaxosT paxos_t = defaultValue;
    paxos_t.inst = pack(inst);
    paxos_t.rnd = pack(rnd);
    paxos_t.vrnd = pack(vrnd);
    paxos_t.acptid = pack(acptid);
    paxos_t.msgtype = pack(msgtype);
    paxos_t.paxosval = pack(paxosval);
    return paxos_t;
endfunction

typedef struct {
    Bit#(16) hrd;
    Bit#(16) pro;
    Bit#(8) hln;
    Bit#(8) pln;
    Bit#(16) op;
    Bit#(48) sha;
    Bit#(32) spa;
    Bit#(48) tha;
    Bit#(32) tpa;
} ArpT deriving (Bits, Eq);

instance DefaultValue#(ArpT);
defaultValue=
ArpT {
    hrd: 0,
    pro: 0,
    hln: 0,
    pln: 0,
    op: 0,
    sha: 0,
    spa: 0,
    tha: 0,
    tpa: 0
};
endinstance

instance FShow#(ArpT);
    function Fmt fshow(ArpT p);
        return $format("ArpT: hrd=%h, pro=%h, hln=%h, pln=%h, op=%h, sha=%h, spa=%h, tha=%h, tpa=%h" , p.hrd, p.pro, p.hln, p.pln, p.op, p.sha, p.spa, p.tha, p.tpa);
    endfunction
endinstance

function ArpT extract_arp(Bit#(224) data);
    Vector#(224, Bit#(1)) dataVec=unpack(data);
    Vector#(16, Bit#(1)) hrd = takeAt(0, dataVec);
    Vector#(16, Bit#(1)) pro = takeAt(16, dataVec);
    Vector#(8, Bit#(1)) hln = takeAt(32, dataVec);
    Vector#(8, Bit#(1)) pln = takeAt(40, dataVec);
    Vector#(16, Bit#(1)) op = takeAt(48, dataVec);
    Vector#(48, Bit#(1)) sha = takeAt(64, dataVec);
    Vector#(32, Bit#(1)) spa = takeAt(112, dataVec);
    Vector#(48, Bit#(1)) tha = takeAt(144, dataVec);
    Vector#(32, Bit#(1)) tpa = takeAt(192, dataVec);
    ArpT arp_t = defaultValue;
    arp_t.hrd = pack(hrd);
    arp_t.pro = pack(pro);
    arp_t.hln = pack(hln);
    arp_t.pln = pack(pln);
    arp_t.op = pack(op);
    arp_t.sha = pack(sha);
    arp_t.spa = pack(spa);
    arp_t.tha = pack(tha);
    arp_t.tpa = pack(tpa);
    return arp_t;
endfunction

typedef struct {
    Bit#(4) version;
    Bit#(4) ihl;
    Bit#(8) diffserv;
    Bit#(16) totalLen;
    Bit#(16) identification;
    Bit#(3) flags;
    Bit#(13) fragOffset;
    Bit#(8) ttl;
    Bit#(8) protocol;
    Bit#(16) hdrChecksum;
    Bit#(32) srcAddr;
    Bit#(32) dstAddr;
} Ipv4T deriving (Bits, Eq);

instance DefaultValue#(Ipv4T);
defaultValue=
Ipv4T {
    version: 0,
    ihl: 0,
    diffserv: 0,
    totalLen: 0,
    identification: 0,
    flags: 0,
    fragOffset: 0,
    ttl: 0,
    protocol: 0,
    hdrChecksum: 0,
    srcAddr: 0,
    dstAddr: 0
};
endinstance

instance FShow#(Ipv4T);
    function Fmt fshow(Ipv4T p);
        return $format("Ipv4T: version=%h, ihl=%h, diffserv=%h, totalLen=%h, identification=%h, flags=%h, fragOffset=%h, ttl=%h, protocol=%h, hdrChecksum=%h, srcAddr=%h, dstAddr=%h" , p.version, p.ihl, p.diffserv, p.totalLen, p.identification, p.flags, p.fragOffset, p.ttl, p.protocol, p.hdrChecksum, p.srcAddr, p.dstAddr);
    endfunction
endinstance

function Ipv4T extract_ipv4(Bit#(160) data);
    Vector#(160, Bit#(1)) dataVec=unpack(data);
    Vector#(4, Bit#(1)) version = takeAt(0, dataVec);
    Vector#(4, Bit#(1)) ihl = takeAt(4, dataVec);
    Vector#(8, Bit#(1)) diffserv = takeAt(8, dataVec);
    Vector#(16, Bit#(1)) totalLen = takeAt(16, dataVec);
    Vector#(16, Bit#(1)) identification = takeAt(32, dataVec);
    Vector#(3, Bit#(1)) flags = takeAt(48, dataVec);
    Vector#(13, Bit#(1)) fragOffset = takeAt(51, dataVec);
    Vector#(8, Bit#(1)) ttl = takeAt(64, dataVec);
    Vector#(8, Bit#(1)) protocol = takeAt(72, dataVec);
    Vector#(16, Bit#(1)) hdrChecksum = takeAt(80, dataVec);
    Vector#(32, Bit#(1)) srcAddr = takeAt(96, dataVec);
    Vector#(32, Bit#(1)) dstAddr = takeAt(128, dataVec);
    Ipv4T ipv4_t = defaultValue;
    ipv4_t.version = pack(version);
    ipv4_t.ihl = pack(ihl);
    ipv4_t.diffserv = pack(diffserv);
    ipv4_t.totalLen = pack(totalLen);
    ipv4_t.identification = pack(identification);
    ipv4_t.flags = pack(flags);
    ipv4_t.fragOffset = pack(fragOffset);
    ipv4_t.ttl = pack(ttl);
    ipv4_t.protocol = pack(protocol);
    ipv4_t.hdrChecksum = pack(hdrChecksum);
    ipv4_t.srcAddr = pack(srcAddr);
    ipv4_t.dstAddr = pack(dstAddr);
    return ipv4_t;
endfunction

typedef struct {
    Bit#(16) round;
} IngressMetadataT deriving (Bits, Eq);

instance DefaultValue#(IngressMetadataT);
defaultValue=
IngressMetadataT {
    round: 0
};
endinstance

instance FShow#(IngressMetadataT);
    function Fmt fshow(IngressMetadataT p);
        return $format("IngressMetadataT: round=%h" , p.round);
    endfunction
endinstance

function IngressMetadataT extract_ingress_metadata(Bit#(16) data);
    Vector#(16, Bit#(1)) dataVec=unpack(data);
    Vector#(16, Bit#(1)) round = takeAt(0, dataVec);
    IngressMetadataT ingress_metadata_t = defaultValue;
    ingress_metadata_t.round = pack(round);
    return ingress_metadata_t;
endfunction

typedef struct {
    Bit#(48) dstAddr;
    Bit#(48) srcAddr;
    Bit#(16) etherType;
} EthernetT deriving (Bits, Eq);

instance DefaultValue#(EthernetT);
defaultValue=
EthernetT {
    dstAddr: 0,
    srcAddr: 0,
    etherType: 0
};
endinstance

instance FShow#(EthernetT);
    function Fmt fshow(EthernetT p);
        return $format("EthernetT: dstAddr=%h, srcAddr=%h, etherType=%h" , p.dstAddr, p.srcAddr, p.etherType);
    endfunction
endinstance

function EthernetT extract_ethernet(Bit#(112) data);
    Vector#(112, Bit#(1)) dataVec=unpack(data);
    Vector#(48, Bit#(1)) dstAddr = takeAt(0, dataVec);
    Vector#(48, Bit#(1)) srcAddr = takeAt(48, dataVec);
    Vector#(16, Bit#(1)) etherType = takeAt(96, dataVec);
    EthernetT ethernet_t = defaultValue;
    ethernet_t.dstAddr = pack(dstAddr);
    ethernet_t.srcAddr = pack(srcAddr);
    ethernet_t.etherType = pack(etherType);
    return ethernet_t;
endfunction

typedef struct {
    Bit#(9) ingress_port;
    Bit#(32) packet_length;
    Bit#(9) egress_spec;
    Bit#(9) egress_port;
    Bit#(32) egress_instance;
    Bit#(32) instance_type;
    Bit#(32) clone_spec;
    Bit#(5) _padding;
} StandardMetadataT deriving (Bits, Eq);

instance DefaultValue#(StandardMetadataT);
defaultValue=
StandardMetadataT {
    ingress_port: 0,
    packet_length: 0,
    egress_spec: 0,
    egress_port: 0,
    egress_instance: 0,
    instance_type: 0,
    clone_spec: 0,
    _padding: 0
};
endinstance

instance FShow#(StandardMetadataT);
    function Fmt fshow(StandardMetadataT p);
        return $format("StandardMetadataT: ingress_port=%h, packet_length=%h, egress_spec=%h, egress_port=%h, egress_instance=%h, instance_type=%h, clone_spec=%h, _padding=%h" , p.ingress_port, p.packet_length, p.egress_spec, p.egress_port, p.egress_instance, p.instance_type, p.clone_spec, p._padding);
    endfunction
endinstance

function StandardMetadataT extract_standard_metadata(Bit#(160) data);
    Vector#(160, Bit#(1)) dataVec=unpack(data);
    Vector#(9, Bit#(1)) ingress_port = takeAt(0, dataVec);
    Vector#(32, Bit#(1)) packet_length = takeAt(9, dataVec);
    Vector#(9, Bit#(1)) egress_spec = takeAt(41, dataVec);
    Vector#(9, Bit#(1)) egress_port = takeAt(50, dataVec);
    Vector#(32, Bit#(1)) egress_instance = takeAt(59, dataVec);
    Vector#(32, Bit#(1)) instance_type = takeAt(91, dataVec);
    Vector#(32, Bit#(1)) clone_spec = takeAt(123, dataVec);
    Vector#(5, Bit#(1)) _padding = takeAt(155, dataVec);
    StandardMetadataT standard_metadata_t = defaultValue;
    standard_metadata_t.ingress_port = pack(ingress_port);
    standard_metadata_t.packet_length = pack(packet_length);
    standard_metadata_t.egress_spec = pack(egress_spec);
    standard_metadata_t.egress_port = pack(egress_port);
    standard_metadata_t.egress_instance = pack(egress_instance);
    standard_metadata_t.instance_type = pack(instance_type);
    standard_metadata_t.clone_spec = pack(clone_spec);
    standard_metadata_t._padding = pack(_padding);
    return standard_metadata_t;
endfunction

typedef struct {
    Bit#(8) role;
} SwitchMetadataT deriving (Bits, Eq);

instance DefaultValue#(SwitchMetadataT);
defaultValue=
SwitchMetadataT {
    role: 0
};
endinstance

instance FShow#(SwitchMetadataT);
    function Fmt fshow(SwitchMetadataT p);
        return $format("SwitchMetadataT: role=%h" , p.role);
    endfunction
endinstance

function SwitchMetadataT extract_switch_metadata(Bit#(8) data);
    Vector#(8, Bit#(1)) dataVec=unpack(data);
    Vector#(8, Bit#(1)) role = takeAt(0, dataVec);
    SwitchMetadataT switch_metadata_t = defaultValue;
    switch_metadata_t.role = pack(role);
    return switch_metadata_t;
endfunction

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
import P4Types::*;
typedef enum {StateStart,StateParseEthernet,StateParseArp,StateParseIpv4,StateParseIpv6,StateParseCpuHeader,StateParseUdp,StateParsePaxos} ParserState deriving (Bits, Eq);
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
    method Action start;
    method Action clear;
endinterface
module mkStateParseEthernet#(Reg#(ParserState) state, FIFOF#(EtherData) datain)(ParseEthernet);
    FIFOF#(Bit#(16)) unparsed_parse_arp_fifo <- mkSizedFIFOF(1);
    FIFOF#(Bit#(16)) unparsed_parse_ipv4_fifo <- mkSizedFIFOF(1);
    FIFOF#(Bit#(16)) unparsed_parse_ipv6_fifo <- mkSizedFIFOF(1);

    FIFOF#(Bit#(48)) parsed_ethernet_fifo <- mkFIFOF;

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
        case (byteSwap(etherType)) matches
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
        $display(fshow(ethernet));
        Vector#(16, Bit#(1)) unparsed = takeAt(112, dataVec);
        let nextState = compute_next_state(ethernet.etherType);
        $display("Goto state %h", nextState);
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
        $display(fshow(arp));
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
    method Action start;
    method Action clear;
endinterface
module mkStateParseIpv4#(Reg#(ParserState) state, FIFOF#(EtherData) datain)(ParseIpv4);
    FIFOF#(Bit#(16)) unparsed_parse_ethernet_fifo <- mkBypassFIFOF;
    FIFOF#(Bit#(112)) unparsed_parse_udp_fifo <- mkSizedFIFOF(1);
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
        case (byteSwap(protocol)) matches
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
        $display(fshow(ipv4));
        Vector#(112, Bit#(1)) unparsed = takeAt(160, dataVec);
        let nextState = compute_next_state(ipv4.protocol);
        $display("Goto state %h", nextState);
        if (nextState == StateParseUdp) begin
            unparsed_parse_udp_fifo.enq(pack(unparsed));
        end
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
        $display(fshow(ipv6));
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
    method Action start;
    method Action clear;
endinterface
module mkStateParseUdp#(Reg#(ParserState) state, FIFOF#(EtherData) datain, FIFOF#(ParserState) parseStateFifo)(ParseUdp);
    FIFOF#(Bit#(112)) unparsed_parse_ipv4_fifo <- mkBypassFIFOF;
    FIFOF#(Bit#(176)) unparsed_parse_paxos_fifo <- mkSizedFIFOF(1);
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
        case (byteSwap(dstPort)) matches
            'h8888: begin
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
        $display(fshow(udp));
        Vector#(176, Bit#(1)) unparsed = takeAt(64, dataVec);
        let nextState = compute_next_state(udp.dstPort);
        $display("Goto state %h", nextState);
        if (nextState == StateParsePaxos) begin
            unparsed_parse_paxos_fifo.enq(pack(unparsed));
        end
        else begin
            parseStateFifo.enq(StateParseUdp);
        end
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
endmodule
interface ParsePaxos;
    interface Put#(Bit#(176)) parse_udp;
    interface Get#(Bit#(16)) parsedOut_paxos_msgtype;
    method Action start;
    method Action clear;
endinterface
module mkStateParsePaxos#(Reg#(ParserState) state, FIFOF#(EtherData) datain, FIFOF#(ParserState) parseStateFifo)(ParsePaxos);
    FIFOF#(Bit#(304)) internal_fifo <- mkSizedFIFOF(1);
    FIFOF#(Bit#(176)) unparsed_parse_udp_fifo <- mkBypassFIFOF;
    FIFOF#(Bit#(16)) parsed_paxos_fifo <- mkFIFOF;
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
        $display(fshow(paxos));
        parsed_paxos_fifo.enq(paxos.msgtype);
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
    interface Get#(Bit#(48)) parsedOut_ethernet_dstAddr;
    interface Get#(Bit#(16)) parsedOut_paxos_msgtype;
    interface PipeOut#(ParserState) parserState;
endinterface

typedef 4 PortMax;
(* synthesize *)
module mkParser(Parser);
    Reg#(ParserState) curr_state <- mkReg(StateStart);
    Reg#(Bool) started <- mkReg(False);
    FIFOF#(EtherData) data_in_fifo <- mkFIFOF;
    Wire#(Bool) start_fsm <- mkDWire(False);

    Vector#(PortMax, FIFOF#(ParserState)) parse_state_in_fifo <- replicateM(mkGFIFOF(False, True)); // unguarded deq
    FIFOF#(ParserState) parse_state_out_fifo <- mkFIFOF;

    (* fire_when_enabled *)
    rule arbitrate_parse_state;
       Bool sentOne = False;
       for (Integer port = 0; port < valueOf(PortMax); port = port+1) begin
          if (!sentOne && parse_state_in_fifo[port].notEmpty()) begin
             ParserState state <- toGet(parse_state_in_fifo[port]).get();
             sentOne = True;
             $display("xxx arbitrate %h", port);
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
        end
    endrule

    interface frameIn = toPut(data_in_fifo);
    interface parsedOut_ethernet_dstAddr = parse_ethernet.parsedOut_ethernet_dstAddr;
    interface parsedOut_paxos_msgtype = parse_paxos.parsedOut_paxos_msgtype;
    interface parserState = toPipeOut(parse_state_out_fifo);
endmodule

