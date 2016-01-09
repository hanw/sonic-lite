/* Copyright (c) 2015 Cornell University
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

#include "lpcap.h"
#include "lutils.h"

#include "MemServerIndication.h"
#include "MallocIndication.h"
#include "TbIndication.h"
#include "TbRequest.h"
#include "GeneratedTypes.h"

using namespace std;

#define DATA_WIDTH 128

static TbRequestProxy *device = 0;
uint16_t flowid;

void mem_copy(const void *buff, int length);

class TbIndication : public TbIndicationWrapper
{
public:
    virtual void read_version_resp(uint32_t a) {
        fprintf(stderr, "version %x\n", a);
    }
    virtual void malloc_resp(uint32_t addr) {
        fprintf(stderr, "malloc result %x\n", addr);
    }
    TbIndication(unsigned int id) : TbIndicationWrapper(id) {}
};

class MemServerIndication : public MemServerIndicationWrapper
{
public:
    virtual void error(uint32_t code, uint32_t sglId, uint64_t offset, uint64_t extra) {
        fprintf(stderr, "memServer Indication.error=%d\n", code);
    }
    virtual void addrResponse ( const uint64_t physAddr ) {
        fprintf(stderr, "phyaddr=%lx\n", physAddr);
    }
    virtual void reportStateDbg ( const DmaDbgRec rec ) {
        fprintf(stderr, "rec\n");
    }
    virtual void reportMemoryTraffic ( const uint64_t words ) {
        fprintf(stderr, "words %lx\n", words);
    }
    MemServerIndication(unsigned int id) : MemServerIndicationWrapper(id) {}
};

class MallocIndication : public MallocIndicationWrapper
{
public:
    virtual void id_resp ( const uint32_t id ) {
        fprintf(stderr, "***CPP pktId=%x\n", id);
    }
    MallocIndication(unsigned int id) : MallocIndicationWrapper(id) {}
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
//            device->writePacketData(data, mask, sop, eop);
            PRINT_INFO("%016lx %016lx %d %d\n", data[1], data[0], sop, eop);
        }

        // last beat, padding with zero
        if ((numBeats%2!=0) && (i==numBeats-1)) {
            sop = (i/2 == 0) ? 1 : 0;
            eop = 1;
            data[1] = 0;
//            device->writePacketData(data, mask, sop, eop);
            PRINT_INFO("%016lx %016lx %d %d\n", data[1], data[0], sop, eop);
        }
    }
}

void usage (const char *program_name) {
    printf("%s: p4fpga tester\n"
     "usage: %s [OPTIONS] \n",
     program_name, program_name);
    printf("\nOther options:\n"
    " -p, --parser=FILE                demo parsing pcap log\n"
    );
}

int main(int argc, char **argv)
{
    const char *program_name = get_exe_name(argv[0]);
    const char *pcap_file="";
    void *buffer;
    long length;
    //struct pcap_pkthdr* pcap_hdr;
    int c, option_index;

    TbIndication echoIndication(IfcNames_TbIndicationH2S);
    MemServerIndication memServerIndication(IfcNames_MemServerIndicationH2S);
    MallocIndication mallocIndication(IfcNames_MallocIndicationH2S);
    device = new TbRequestProxy(IfcNames_TbRequestS2H);

    bool run_basic = true;
    bool load_pcap = false;
    bool parser_test = false;

    static struct option long_options [] = {
        {"help",                no_argument, 0, 'h'},
        {"parser-test",         required_argument, 0, 'p'},
        {0, 0, 0, 0}
    };

    static string short_options
        (long_options_to_short_options(long_options));

    for (;;) {
        c = getopt_long(argc, argv, short_options.c_str(), long_options, &option_index);

        if (c == -1)
            break;

        switch (c) {
            case 'h':
                usage(program_name);
                run_basic = false;
                break;
            case 'p':
                load_pcap = true;
                parser_test = true;
                pcap_file = optarg;
                break;
            default:
                run_basic = false;
                break;
        }
    }

    if (run_basic) {
        fprintf(stderr, "read version from cpp\n");
        device->read_version();
    }

    if (load_pcap) {
        fprintf(stderr, "Attempts to read pcap file %s\n", pcap_file);

        if (!read_pcap_file(pcap_file, &buffer, &length)) {
            perror("Failed to read file!");
            exit(-1);
        }

        if (int err = load_pcap_file(buffer, length)) {
            fprintf(stderr, "Error: %s\n", strerror(err));
        }
    }

    if (parser_test) {
        // load packet
        // parse
        // print match result
    }

    if (run_basic) {
        printf("done!");
        while (1) sleep(1);
    }
    return 0;
}
