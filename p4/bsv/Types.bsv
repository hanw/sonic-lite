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

import DefaultValue::*;

typedef struct {
   Bit#(48) dstAddr;
   Bit#(48) srcAddr;
   Bit#(16) etherType;
} HeaderType_ethernet deriving(Bits, Eq);
instance DefaultValue#(HeaderType_ethernet);
   defaultValue =
   HeaderType_ethernet {
     dstAddr : 0,
     srcAddr : 0,
     etherType : 0
   };
endinstance
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
} HeaderType_ipv4 deriving(Bits, Eq);
instance DefaultValue#(HeaderType_ipv4);
   defaultValue =
   HeaderType_ipv4 {
     version : 0,
     ihl : 0,
     diffserv : 0,
     totalLen : 0,
     identification : 0,
     flags : 0,
     fragOffset : 0,
     ttl : 0,
     protocol : 0,
     hdrChecksum : 0,
     srcAddr : 0,
     dstAddr : 0
   };
endinstance
typedef struct {
   Bit#(9) ingress_port;
   Bit#(32) packet_length;
   Bit#(9) egress_spec;
   Bit#(9) egress_port;
   Bit#(32) egress_instance;
   Bit#(32) instance_type;
   Bit#(32) clone_spec;
   Bit#(5) _padding;
} HeaderType_standard_metadata deriving(Bits, Eq);
instance DefaultValue#(HeaderType_standard_metadata);
   defaultValue =
   HeaderType_standard_metadata {
     ingress_port : 0,
     packet_length : 0,
     egress_spec : 0,
     egress_port : 0,
     egress_instance : 0,
     instance_type : 0,
     clone_spec : 0,
     _padding : 0
   };
endinstance
typedef struct {
   Bit#(12) vrf;
   Bit#(16) bd;
   Bit#(16) nexthop_index;
   Bit#(4) _padding;
} HeaderType_ingress_metadata deriving(Bits, Eq);
instance DefaultValue#(HeaderType_ingress_metadata);
   defaultValue =
   HeaderType_ingress_metadata {
     vrf : 0,
     bd : 0,
     nexthop_index : 0,
     _padding : 0
   };
endinstance


