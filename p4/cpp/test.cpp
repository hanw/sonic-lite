/* Copyright (c) 2014 Quanta Research Cambridge, Inc
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

#include <errno.h>
#include <stdio.h>
#include <tins/tins.h>

#include "P4TopIndication.h"
#include "P4TopRequest.h"
#include "GeneratedTypes.h"

using namespace Tins;

static P4TopRequestProxy *device = 0;

class P4TopIndication : public P4TopIndicationWrapper
{
public:
    virtual void sonic_read_version_resp(uint32_t a) {
        fprintf(stderr, "version %08x\n", a);
    }
    P4TopIndication(unsigned int id) : P4TopIndicationWrapper(id) {}
};

#define SRC_MAC "77:22:33:11:ad:ad"
#define DST_MAC "11:22:33:44:55:66"
#define SRC_IP  "192.168.2.1"
#define DST_IP  "192.168.0.1"
#define SRC_TCP 15
#define DST_TCP 13
#define PAYLOAD "I'm a payload! Test sending one packet."

int main(int argc, const char **argv)
{
    P4TopIndication echoIndication(IfcNames_P4TopIndicationH2S);
    device = new P4TopRequestProxy(IfcNames_P4TopRequestS2H);

    int packet_size;
    int numBeats;
    EthernetII eth = EthernetII(DST_MAC, SRC_MAC) /
                     IP(DST_IP, SRC_IP) /
                     TCP(DST_TCP, SRC_TCP) /
                     RawPDU(PAYLOAD);
    PDU::serialization_type buff = eth.serialize();
    packet_size = buff.size();
    numBeats = packet_size / 8; // 16 bytes per beat for 128-bit datawidth;
    if (packet_size % 8 != 0) numBeats++;
    fprintf(stderr, "nBeats=%d\n", numBeats);
    fprintf(stderr, "src_mac=%s, dst_mac=%s\n", SRC_MAC, DST_MAC);
    fprintf(stderr, "src_ip=%s, dst_ip=%s\n", SRC_IP, DST_IP);

    // transfer packet to receive
    uint64_t data[2];
    int i, sop, eop;
    for (i=0; i<numBeats; i++) {
        data[i%2] = *((uint64_t *)(&buff[0]) + i);
        sop = (i/2 == 0) ? 1 : 0;
        eop = (i/2 == (numBeats-1)/2) ? 1 : 0;
        if (i%2) {
            device->writePacketData(data, sop, eop);
            fprintf(stderr, "%016lx %016lx %d %d\n", data[1], data[0], sop, eop);
        }
    }

    return 0;
}
