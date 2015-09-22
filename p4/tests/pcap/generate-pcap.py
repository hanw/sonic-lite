#!/user/bin/python

import logging
import sys
import os
import argparse
import collections
logging.getLogger("scapy").setLevel(1)

from scapy.all import *

parser = argparse.ArgumentParser(description="Test packet generator")
parser.add_argument('--out-dir', help="Output path", type=str, action='store', default=os.getcwd())
args = parser.parse_args()

all_pkts = collections.OrderedDict()

def gen_udp_pkts():
    all_pkts['udp_vlan'] = Ether(src="01:02:03:04:05:06", dst="11:12:13:14:15:16") / \
                           Dot1Q(vlan=3393) / IP(src="10.0.0.1", dst="10.0.0.2") /   \
                           UDP(sport=6000, dport=20000)

    all_pkts['udp'] = Ether(src="01:02:03:04:05:06", dst="11:12:13:14:15:16") / \
                           Dot1Q(vlan=3393) / IP(src="10.0.0.1", dst="10.0.0.2") /   \
                           UDP(sport=6000, dport=20000)

def gen_tcp_pkts():
    pass

def main():
    gen_udp_pkts()
    gen_tcp_pkts()

    with open("%s/packet.mk" % args.out_dir, "w") as f:
        f.write("TEST_PACKET=")
        for packet in all_pkts.keys():
            f.write(" "+packet)

    for k, v in all_pkts.iteritems():
        wrpcap('%s/%s.pcap' % (args.out_dir, k), v)

if __name__ == '__main__':
    main()
