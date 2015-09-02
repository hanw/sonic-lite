/*
Copyright 2013-present Barefoot Networks, Inc. 

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

#include "includes/headers.p4"
#include "includes/parser.p4"

#define PORT_VLAN_TABLE_SIZE                   32768
#define BD_TABLE_SIZE                          65536
#define IPV4_LPM_TABLE_SIZE                    16384
#define IPV4_HOST_TABLE_SIZE                   131072
#define NEXTHOP_TABLE_SIZE                     32768
#define REWRITE_IPV4_TABLE_SIZE                32768

#define VRF_BIT_WIDTH                          12
#define BD_BIT_WIDTH                           16
#define IFINDEX_BIT_WIDTH                      10

/* METADATA */
header_type ingress_metadata_t {
    fields {
        vrf : VRF_BIT_WIDTH;                   /* VRF */
        bd : BD_BIT_WIDTH;                     /* ingress BD */
        nexthop_index : 16;                    /* final next hop index */
    }
}

metadata ingress_metadata_t ingress_metadata;

action on_miss() {
}

action fib_hit_nexthop(nexthop_index) {
    modify_field(ingress_metadata.nexthop_index, nexthop_index);
    subtract_from_field(ipv4.ttl, 1);
}

table ipv4_fib {
    reads {
        ingress_metadata.vrf : exact;
        ipv4.dstAddr : exact;
    }
    actions {
        on_miss;
        fib_hit_nexthop;
    }
    size : IPV4_HOST_TABLE_SIZE;
}

table ipv4_fib_lpm {
    reads {
        ingress_metadata.vrf : exact;
        ipv4.dstAddr : lpm;
    }
    actions {
        on_miss;
        fib_hit_nexthop;
    }
    size : IPV4_LPM_TABLE_SIZE;
}

action set_egress_details(egress_spec) {
    modify_field(standard_metadata.egress_spec, egress_spec);
}

table nexthop {
    reads {
        ingress_metadata.nexthop_index : exact;
    }
    actions {
        on_miss;
        set_egress_details;
    }
    size : NEXTHOP_TABLE_SIZE;
}

control ingress {
    if (valid(ipv4)) {

        /* fib lookup, set ingress_metadata.nexthop_index */
        apply(ipv4_fib) {
            on_miss {
                apply(ipv4_fib_lpm);
            }
        }

        /* derive standard_metadata.egress_spec from ingress_metadata.nexthop_index */
        apply(nexthop);
    }
}

action f_insert_ipv4_header(proto) {
    add_header(ipv4);
    modify_field(ipv4.protocol, proto);
    modify_field(ipv4.ttl, 64);
    modify_field(ipv4.version, 0x4);
    modify_field(ipv4.ihl, 0x5);
}

action ipv4_ipv4_rewrite() {
    f_insert_ipv4_header(IP_PROTOCOLS_IPV4);
    modify_field(ethernet.etherType, ETHERTYPE_IPV4);
}

action ipv4_ipv6_rewrite() {
    f_insert_ipv4_header(IP_PROTOCOLS_IPV6);
    modify_field(ethernet.etherType, ETHERTYPE_IPV4);
}

table rewrite_ipv4 {
    reads {
        ipv4.dstAddr : exact;
    }
    actions {
        ipv4_ipv4_rewrite;
        ipv4_ipv6_rewrite;
    }
    size : REWRITE_IPV4_TABLE_SIZE;
}

control egress {
    /* set smac and dmac from ingress_metadata.nexthop_index */
    apply(rewrite_ipv4);
}
