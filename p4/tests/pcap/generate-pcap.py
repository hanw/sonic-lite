#!/user/bin/python

import argparse
import collections
import logging
import os
import random
import sys

logging.getLogger("scapy").setLevel(1)

from scapy.all import *

parser = argparse.ArgumentParser(description="Test packet generator")
parser.add_argument('--out-dir', help="Output path", type=str, action='store', default=os.getcwd())
args = parser.parse_args()

all_pkts = collections.OrderedDict()

def gen_udp_pkts():
    # ETH|VLAN|VLAN|IP|UDP
    all_pkts['vlan2-udp'] = Ether(src="01:02:03:04:05:06", dst="11:12:13:14:15:16") / \
                           Dot1Q(vlan=3393) / Dot1Q(vlan=2000) / IP(src="10.0.0.1", dst="10.0.0.2") /   \
                           UDP(sport=6000, dport=6639)

    # ETH|VLAN|IP|UDP
    all_pkts['vlan-udp'] = Ether(src="01:02:03:04:05:06", dst="11:12:13:14:15:16") / \
                           Dot1Q(vlan=3393) / IP(src="10.0.0.1", dst="10.0.0.2") /   \
                           UDP(sport=6000, dport=20000)

    # ETH|VLAN|IP|UDP
    all_pkts['udp-small'] = Ether(src="01:02:03:04:05:06", dst="11:12:13:14:15:16") / \
                           IP(src="10.0.0.1", dst="10.0.0.2") /   \
                           UDP(sport=6000, dport=20000)
    # ETH|VLAN|IP|UDP|PAYLOAD
    data = bytearray(os.urandom(1000))
    all_pkts['udp-large'] = Ether(src="01:02:03:04:05:06", dst="11:12:13:14:15:16") / \
                            IP(src="10.0.0.1", dst="10.0.0.2") /   \
                            UDP(sport=6000, dport=20000) / Raw(data)

    data = bytearray(os.urandom(500))
    all_pkts['udp-mid'] = Ether(src="01:02:03:04:05:06", dst="11:12:13:14:15:16") / \
                            IP(src="10.0.0.1", dst="10.0.0.2") /   \
                            UDP(sport=6000, dport=20000) / Raw(data)


    # ETH|IP|UDP|PAYLOAD X 10
    udp_10 = PacketList()
    for i in range(10):
        data = bytearray(os.urandom(random.randint(1,100)))
        udp_10.append(Ether(src="01:02:03:04:05:06", dst="11:12:13:14:15:16") / \
                 IP(src="10.0.0.1", dst="10.0.0.2") /   \
                 UDP(sport=6000, dport=20000) / Raw(data))
    all_pkts['udp-burst'] = udp_10

    vlan_10 = PacketList()
    for i in range(10):
        data = bytearray(os.urandom(random.randint(1,100)))
        vlan_10.append(Ether(src="01:02:03:04:05:06", dst="11:12:13:14:15:16") / \
                Dot1Q(vlan=3393) / IP(src="10.0.0.1", dst="10.0.0.2") /   \
                UDP(sport=6000, dport=20000) / Raw(data))
    all_pkts['vlan-burst'] = vlan_10

    # ETH|IP|UDP|PAYLOAD X 10
    udp_5 = PacketList()
    for i in range(5):
        data = bytearray(os.urandom(random.randint(1,100)))
        udp_5.append(Ether(src="01:02:03:04:05:06", dst="11:12:13:14:15:16") / \
                 IP(src="10.0.0.1", dst="10.0.0.2") /   \
                 UDP(sport=6000, dport=20000) / Raw(data))
    all_pkts['udp-burst-5'] = udp_5



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
