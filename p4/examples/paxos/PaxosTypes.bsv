import ClientServer::*;
import Connectable::*;
import Ethernet::*;
import FIFO::*;
import FIFOF::*;
import GetPut::*;
import MatchTable::*;
import Pipe::*;
import RegFile::*;
import Vector::*;
import DefaultValue::*;
import ConnectalTypes::*;
import Utils::*;
`include "ConnectalProjectConfig.bsv"

import `MATCHTABLE::*;

typedef struct {
   PacketInstance pkt;
   MetadataT meta;
} MetadataRequest deriving (Bits, Eq, FShow);

typedef struct {
   PacketInstance pkt;
   MetadataT meta;
} MetadataResponse deriving (Bits, Eq, FShow);

typedef union tagged {
   struct {
      PacketInstance pkt;
      Bit#(9) port;
   } BBForwardRequest;
   struct {
      PacketInstance pkt;
   } BBIncreaseInstanceRequest;
   struct {
      PacketInstance pkt;
      Bit#(InstanceSize) inst;
      Bit#(RoundSize) rnd;
   } BBHandle1aRequest;
   struct {
      PacketInstance pkt;
      Bit#(InstanceSize) inst;
      Bit#(RoundSize) rnd;
      Bit#(32) valuelen;
      Bit#(ValueSize) paxosval;
   } BBHandle2aRequest;
   struct {
      PacketInstance pkt;
   } BBDropRequest;
   struct {
      PacketInstance pkt;
      Bit#(InstanceSize) paxos$inst;
   } BBRoundRequest;
   struct {
      PacketInstance pkt;
   } BBRoleRequest;
} BBRequest deriving (Bits, Eq, FShow);

typedef union tagged {
   struct {
      PacketInstance pkt;
      Bit#(9) egress;
   } BBForwardResponse;
   struct {
      PacketInstance pkt;
      Bit#(InstanceSize) inst;
   } BBIncreaseInstanceResponse;
   struct {
      PacketInstance pkt;
      Bit#(DatapathSize) datapath;
      Bit#(RoundSize) vround;
      Bit#(ValueSize) value;
   } BBHandle1aResponse;
   struct {
      PacketInstance pkt;
      Bit#(DatapathSize) datapath;
   } BBHandle2aResponse;
   struct {
      PacketInstance pkt;
   } BBDropResponse;
   struct {
      PacketInstance pkt;
      IngressMetadataT ingress_metadata;
   } BBRoundResponse;
   struct {
      PacketInstance pkt;
      Role role;
   } BBRoleResponse;
} BBResponse deriving (Bits, Eq, FShow);

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
defaultValue= unpack(0);
endinstance
instance DefaultMask#(Ipv6T);
defaultMask= unpack(maxBound);
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
defaultValue = unpack(0);
endinstance
instance DefaultMask#(UdpT);
defaultMask = unpack(maxBound);
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
    Bit#(16) msgtype;
    Bit#(32) inst;
    Bit#(16) rnd;
    Bit#(16) vrnd;
    Bit#(16) acptid;
    Bit#(32) valuelen;
    Bit#(256) paxosval;
} PaxosT deriving (Bits, Eq);

instance DefaultValue#(PaxosT);
defaultValue = unpack(0);
endinstance
instance DefaultMask#(PaxosT);
defaultMask = unpack(maxBound);
endinstance

instance FShow#(PaxosT);
    function Fmt fshow(PaxosT p);
        return $format("PaxosT: msgtype=%h, inst=%h, rnd=%h, vrnd=%h, acptid=%h, valuelen=%h, paxosval=%h" , p.msgtype, p.inst, p.rnd, p.vrnd, p.acptid, p.valuelen, p.paxosval);
    endfunction
endinstance

function PaxosT extract_paxos(Bit#(384) data);
    Vector#(384, Bit#(1)) dataVec=unpack(data);
    Vector#(16, Bit#(1)) msgtype = takeAt(0, dataVec);
    Vector#(32, Bit#(1)) inst = takeAt(16, dataVec);
    Vector#(16, Bit#(1)) rnd = takeAt(48, dataVec);
    Vector#(16, Bit#(1)) vrnd = takeAt(64, dataVec);
    Vector#(16, Bit#(1)) acptid = takeAt(80, dataVec);
    Vector#(32, Bit#(1)) valuelen = takeAt(96, dataVec);
    Vector#(256, Bit#(1)) paxosval = takeAt(128, dataVec);
    PaxosT paxos_t = defaultValue;
    paxos_t.msgtype = pack(msgtype);
    paxos_t.inst = pack(inst);
    paxos_t.rnd = pack(rnd);
    paxos_t.vrnd = pack(vrnd);
    paxos_t.acptid = pack(acptid);
    paxos_t.valuelen = pack(valuelen);
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
defaultValue = unpack(0);
endinstance
instance DefaultMask#(ArpT);
defaultMask = unpack(maxBound);
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
defaultValue = unpack(0);
endinstance
instance DefaultMask#(Ipv4T);
defaultMask = unpack(maxBound);
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
    Bit#(RoundSize) round;
} IngressMetadataT deriving (Bits, Eq);

instance DefaultValue#(IngressMetadataT);
defaultValue = unpack(0);
endinstance
instance DefaultMask#(IngressMetadataT);
defaultMask = unpack(maxBound);
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
defaultValue = unpack(0);
endinstance
instance DefaultMask#(EthernetT);
defaultMask = unpack(maxBound);
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
defaultValue = unpack(0);
endinstance
instance DefaultMask#(StandardMetadataT);
defaultMask = unpack(maxBound);
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
defaultValue = unpack(0);
endinstance
instance DefaultMask#(SwitchMetadataT);
defaultMask = unpack(maxBound);
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

typedef struct {
   Maybe#(Bit#(16)) msgtype; // ethernet$msgtype
   Maybe#(Bit#(48)) dstAddr; // ethernet$dstAddr
   Maybe#(Bit#(16)) etherType; // ethernet$etherType
   Maybe#(Bit#(8))  protocol; // ipv4$protocol
   Maybe#(Bit#(16)) dstPort; // ipv4$dstPort
   Maybe#(Bit#(16)) paxos$msgtype;
   Maybe#(Bit#(32)) paxos$inst; // paxos$inst
   Maybe#(Bit#(16)) paxos$rnd;
   Maybe#(Bit#(16)) paxos$vrnd;
   Maybe#(Bit#(16)) paxos$acptid;
   Maybe#(Bit#(32)) paxos$valuelen;
   Maybe#(Bit#(256)) paxos$paxosval;
   Maybe#(Bit#(16)) paxos_packet_meta$round;
   Maybe#(Role) switch_metadata$role;
   Maybe#(Bool) valid_ethernet;
   Maybe#(Bool) valid_arp;
   Maybe#(Bool) valid_ipv4;
   Maybe#(Bool) valid_ipv6;
   Maybe#(Bool) valid_udp;
   Maybe#(Bool) valid_paxos;
} MetadataT deriving (Bits, Eq);

instance DefaultValue#(MetadataT);
defaultValue =
MetadataT {
   msgtype: tagged Invalid,
   dstAddr: tagged Invalid,
   etherType: tagged Invalid,
   protocol: tagged Invalid,
   dstPort: tagged Invalid,
   paxos$inst: tagged Invalid,
   paxos$rnd: tagged Invalid,
   paxos$vrnd: tagged Invalid,
   paxos$paxosval: tagged Invalid,
   paxos$valuelen: tagged Invalid,
   paxos$acptid: tagged Invalid,
   paxos$msgtype: tagged Invalid,
   paxos_packet_meta$round: tagged Invalid,
   switch_metadata$role: tagged Invalid,
   valid_ethernet: tagged Invalid,
   valid_arp: tagged Invalid,
   valid_ipv4: tagged Invalid,
   valid_ipv6: tagged Invalid,
   valid_udp: tagged Invalid,
   valid_paxos: tagged Invalid
};
endinstance

instance FShow#(MetadataT);
   function Fmt fshow(MetadataT p);
      return $format("msgtype=", fshow(p.msgtype), ",")+
             $format("dstAddr=", fshow(p.dstAddr), ",")+
             $format("etherType=", fshow(p.etherType), ",")+
             $format("protocol=", fshow(p.protocol), ",")+
             $format("dstPort=", fshow(p.dstPort), ",")+
             $format("role=", fshow(p.switch_metadata$role), ",")+
             $format("round=", fshow(p.paxos_packet_meta$round), ",")+
             $format("paxos$msgtype=", fshow(p.paxos$msgtype))+
             $format("paxos$inst=", fshow(p.paxos$inst), ",")+
             $format("paxos$rnd=", fshow(p.paxos$rnd), ",")+
             $format("paxos$vrnd=", fshow(p.paxos$vrnd), ",")+
             $format("paxos$acpt=", fshow(p.paxos$acptid), ",")+
             $format("paxos$valuelen=", fshow(p.paxos$valuelen), ",")+
             $format("paxos$val=", fshow(p.paxos$paxosval), ",");
   endfunction
endinstance

typedef Client#(MetadataRequest, MetadataResponse) MetadataClient;
typedef Server#(MetadataRequest, MetadataResponse) MetadataServer;

typedef Client#(BBRequest, BBResponse) BBClient;
typedef Server#(BBRequest, BBResponse) BBServer;

/* generate tables */
typedef struct {
    Bit#(6) padding;
    Bit#(48) dstAddr;
} DmacTblReqT deriving (Bits, Eq, FShow);

//typedef union tagged {
//    struct {
//        Bit#(9) port;
//    } Forward;
//
//    struct {
//        Bit#(4) group;
//    } Broadcast;
//} DmacTblRespT deriving (Bits, Eq, FShow);

typedef struct {
   Bit#(9) port;
} DmacTblParamT deriving (Bits, Eq, FShow);

typedef struct {
   DmacTblActionT act;
   DmacTblParamT param;
} DmacTblRespT deriving (Bits, Eq, FShow);

typedef struct {
    Bit#(2) padding;
    Bit#(16) msgtype;
} SequenceTblReqT deriving (Bits, Eq, FShow);

typedef struct {
   SequenceTblActionT act;
} SequenceTblRespT deriving (Bits, Eq, FShow);

typedef struct {
    Bit#(2) padding;
    Bit#(16) msgtype;
} AcceptorTblReqT deriving (Bits, Eq, FShow);

typedef struct {
   AcceptorTblActionT act;
} AcceptorTblRespT deriving (Bits, Eq, FShow);

(* synthesize *)
module mkMatchTable_256_dmacTable(MatchTable#(0, 256, SizeOf#(DmacTblReqT), SizeOf#(DmacTblRespT)));
   (* hide *)
   MatchTable#(0, 256, SizeOf#(DmacTblReqT), SizeOf#(DmacTblRespT)) ifc <- mkMatchTable("dmac_tbl");
   return ifc;
endmodule

(* synthesize *)
module mkMatchTable_256_acceptorTable(MatchTable#(0, 256, SizeOf#(AcceptorTblReqT), SizeOf#(AcceptorTblRespT)));
   MatchTable#(0, 256, SizeOf#(AcceptorTblReqT), SizeOf#(AcceptorTblRespT)) ifc <- mkMatchTable("acceptor_tbl");
   return ifc;
endmodule

(* synthesize *)
module mkMatchTable_256_sequenceTable(MatchTable#(0, 256, SizeOf#(SequenceTblReqT), SizeOf#(SequenceTblRespT)));
   MatchTable#(0, 256, SizeOf#(SequenceTblReqT), SizeOf#(SequenceTblRespT)) ifc <- mkMatchTable("sequence_tbl");
   return ifc;
endmodule

