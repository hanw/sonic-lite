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

#include "NicTopIndication.h"
#include "NicTopRequest.h"
#include "GeneratedTypes.h"

using namespace Tins;

static NicTopRequestProxy *device = 0;

class NicTopIndication : public NicTopIndicationWrapper
{
public:
    virtual void sonic_read_version_resp(uint32_t a) {
        fprintf(stderr, "version %08x\n", a);
    }
    NicTopIndication(unsigned int id) : NicTopIndicationWrapper(id) {}
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
    NicTopIndication echoIndication(IfcNames_NicTopIndicationH2S);
    device = new NicTopRequestProxy(IfcNames_NicTopRequestS2H);

    int packet_size;
    int numBeats;
    EthernetII eth = EthernetII(DST_MAC, SRC_MAC) /
                     IP(DST_IP, SRC_IP) /
                     TCP(DST_TCP, SRC_TCP) /
                     RawPDU(PAYLOAD);
    PDU::serialization_type buff = eth.serialize();
    packet_size = buff.size();
    numBeats = packet_size / 16; // 16 bytes per beat for 128-bit datawidth;
    if (packet_size % 16 != 0) numBeats++;
    fprintf(stderr, "nBeats=%d\n", numBeats);

    // transfer packet to receive
    uint64_t *data_hi, *data_lo;
    int i;
    for (i=0; i<numBeats; i++) {
        data_hi = 0;
        data_lo = 0;

        data_hi = (uint64_t *)(&buff[0]) + i;
        data_lo = (uint64_t *)(&buff[0]) + i + 1;

        if (i==0) {
            device->writePacketData(*data_hi, *data_lo, 1, 0);
        } else if (i==(numBeats-1)*2) {
            device->writePacketData(*data_hi, *data_lo, 0, 1);
        } else {
            device->writePacketData(*data_hi, *data_lo, 0, 0);
        }

        fprintf(stderr, "%p %016lx %p %016lx \n", data_hi, *data_hi, data_lo, *data_lo);
    }

    return 0;
}
