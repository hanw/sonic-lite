#!/usr/bin/env python

from scapy.all import *
import sys
import argparse


class PaxosValue(Packet):
    name ="PaxosValue "
    fields_desc =[  
                    XIntField("vlen", 0x04),
                    XBitField("value", 0x11223344, 256)
                ]

class Paxos(Packet):
    name ="PaxosPacket "
    fields_desc =[  
                    XShortField("msgtype", 0x3),
                    XIntField("inst", 0x1),
                    XShortField("rnd", 0x0),
                    XShortField("vrnd", 0x0),
                    XShortField("acpt", 0x0),
                ]


def paxos_packet(inst, rnd, vrnd, acpt, typ, value):
    eth = Ether(dst="08:00:27:10:a8:80")
    ip = IP(src="192.168.4.95", dst="224.3.29.73")
    udp = UDP(sport=34949, dport=34952)
    paxos_value = PaxosValue(vlen=32, value=value)
    paxos =  Paxos(msgtype=typ, inst=inst, rnd=rnd, vrnd=vrnd, acpt=acpt)
    print "paxos len", len(paxos)
    hexdump(paxos)
    pkt = eth / ip / udp / paxos / paxos_value
    return pkt

def store_pkts_in_pcap(args):
    pkts = []
    for i in range(args.count):
        pkt = paxos_packet(args.inst, i, args.vrnd, args.acpt, args.type, args.value)
        pkts.append(pkt)
    wrpcap("%s" % args.output, pkts)



if __name__=='__main__':
    parser = argparse.ArgumentParser(description='P4Paxos demo')
    parser.add_argument('-I', '--interface', type=str, default='eth1', help='Network interface')
    parser.add_argument('-i', '--inst', help='Paxos instance', type=int, default=1)
    parser.add_argument('-t', '--type', help='Paxos instance', type=int, default=2)
    parser.add_argument('-r', '--rnd', help='Paxos round', type=int, default=1)
    parser.add_argument('-v', '--vrnd', help='Paxos value round', type=int, default=1)
    parser.add_argument('-a', '--acpt', help='Paxos acceptor id', type=int, default=0)
    parser.add_argument('-c', '--count', help='number of packets', type=int, default=1)
    parser.add_argument('-s', '--store', help='store in pcap file', default=False, action='store_true')
    parser.add_argument('-V', '--value', help='Paxos value', type=int, default=0x48656c6c6f)
    parser.add_argument('-o', '--output', help='output pcap file', type=str, default="paxos.pcap")
    args = parser.parse_args()

    if args.store:
        store_pkts_in_pcap(args)
        sys.exit(0)

    pkt = paxos_packet(args.inst, args.rnd, args.vrnd, args.acpt, args.type, args.value)
    pkt.show()
    sendp(pkt, iface=args.interface, count=args.count)
