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

#include <assert.h>
#include <fcntl.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>
#include <stdio.h>
#include <sys/mman.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <sys/time.h>

#include "P4TopIndication.h"
#include "P4TopRequest.h"
#include "GeneratedTypes.h"
#include "utils.h"

#ifndef le32
#define le32    int32_t
#endif

#ifndef u32
#define u32     u_int32_t
#endif

#ifndef u16
#define u16     u_int16_t
#endif

#ifndef s32
#define s32     int32_t
#endif

#define DATA_WIDTH 128

struct pcap_file_header {
    u32 magic;
    u16 version_major;
    u16 version_minor;
    s32 thiszone; /* gmt to local correction */
    u32 sigfigs;  /* accuracy of timL1 cache bytes userspaceestamps */
    u32 snaplen;  /* max length saved portion of each pkt */
    u32 linktype; /* data link type (LINKTYPE_*) */
} __attribute__((packed));

struct pcap_pkthdr_ts {
    le32 hts_sec;
    le32 hts_usec;
}  __attribute__((packed));

struct pcap_pkthdr {
    struct  pcap_pkthdr_ts ts;  /* time stamp */
    le32 caplen;              /* length of portion present */
    le32 length;                  /* length this packet (off wire) */
}  __attribute__((packed));

void mem_copy(const void *buff, int length);

static P4TopRequestProxy *device = 0;

class P4TopIndication : public P4TopIndicationWrapper
{
public:
    virtual void sonic_read_version_resp(uint32_t a) {
        fprintf(stderr, "version %08x\n", a);
    }
    virtual void matchTableResponse(uint32_t key, uint32_t value) {
        fprintf(stderr, "\nkey = %u  value = %u\n", key, value);
    }
    P4TopIndication(unsigned int id) : P4TopIndicationWrapper(id) {}
};

void mem_copy(const void *buff, int packet_size) {

    int i, sop, eop;
    uint64_t data[2];
    int numBeats;

    numBeats = packet_size / 8; // 16 bytes per beat for 128-bit datawidth;
    if (packet_size % 8) numBeats++;
    PRINT_INFO("nBeats=%d, packetSize=%d\n", numBeats, packet_size);
    for (i=0; i<numBeats; i++) {
        data[i%2] = *(static_cast<const uint64_t *>(buff) + i);
        sop = (i/2 == 0);
        eop = (i/2 == (numBeats-1)/2);
        if (i%2) {
            device->writePacketData(data, sop, eop);
            PRINT_INFO("%016lx %016lx %d %d\n", data[1], data[0], sop, eop);
        }

        // last beat, padding with zero
        if ((numBeats%2!=0) && (i==numBeats-1)) {
            sop = (i/2 == 0) ? 1 : 0;
            eop = 1;
            data[1] = 0;
            device->writePacketData(data, sop, eop);
            PRINT_INFO("%016lx %016lx %d %d\n", data[1], data[0], sop, eop);
        }
    }
}

/**
 * Send packet on quick_tx device
 * @param qtx       pointer to a quick_tx structure
 * @param buffer   full packet data starting at the ETH frame
 * @param length  length of packet (must be over 0)
 * @return           length of packet if it was successfully queued, QTX_E_EXIT if a critical error occurred
 *                  and close needs to be called
 */
static inline int quick_tx_send_packet(const void* buffer, int length) {
    assert(buffer);
    assert(length > 0);

#ifdef EXTRA_DEBUG
    printf("[quick_tx] Copying data from %p buffer, length = %d\n",
                (buffer, length);
#endif
    mem_copy(buffer, length);

    return length;
}

bool read_pcap_file(char* filename, void** buffer, long *length) {
    FILE *infile;
    long length_read;

    infile = fopen(filename, "r");
    if(infile == NULL) {
            printf("File does not exist!\n");
            return false;
        }

    fseek(infile, 0L, SEEK_END);
    *length = ftell(infile);
    fseek(infile, 0L, SEEK_SET);
    *buffer = (char*)calloc(*length, sizeof(char));

    /* memory error */
    if(*buffer == NULL) {
            printf("Could not allocate %ld bytes of memory!\n", *length);
            return false;
        }

    length_read = fread(*buffer, sizeof(char), *length, infile);
    *length = length_read;
    fclose(infile);

    return true;
}

int main(int argc, char **argv)
{
    void *buffer;
    long length;
    struct pcap_pkthdr* pcap_hdr;
    int i;
    int loops = 1;

    P4TopIndication echoIndication(IfcNames_P4TopIndicationH2S);
    device = new P4TopRequestProxy(IfcNames_P4TopRequestS2H);

    device->sonic_read_version();

    device->matchTableRequest(10, 15, 1);
    device->matchTableRequest(10, 0, 0);
    while(1);
    fprintf(stderr, "Attempts to read pcap file %s\n", argv[1]);
    if (!read_pcap_file(argv[1], &buffer, &length)) {
        perror("Failed to read file!");
        exit(-1);
    }

    for (i = 0; i < loops; i++) {
        void* offset = static_cast<char *>(buffer) + sizeof(struct pcap_file_header);

        while(offset < static_cast<char *>(buffer) + length) {
            pcap_hdr = (struct pcap_pkthdr*) offset;
            offset = static_cast<char *>(offset) + sizeof(struct pcap_pkthdr);

            if ((quick_tx_send_packet((const void*)offset, pcap_hdr->caplen)) < 0) {
                printf("An error occurred while trying to send a packet\n");
                exit(-1);
            }

            offset = static_cast<char *>(offset) + pcap_hdr->caplen;
        }
    }

    while(1) sleep(1);

    return 0;
}
