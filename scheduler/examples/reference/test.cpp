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

#include "MemServerIndication.h"
#include "MallocIndication.h"
#include "MemoryTestIndication.h"
#include "MemoryTestRequest.h"
#include "GeneratedTypes.h"
#include "lutils.h"
#include "lpcap.h"

using namespace std;

#define DATA_WIDTH 128

static MemoryTestRequestProxy *device = 0;
uint16_t flowid;

void device_writePacketData(uint64_t* data, uint8_t* mask, int sop, int eop) {
    device->writePacketData(data, mask, sop, eop);
}

class MemoryTestIndication : public MemoryTestIndicationWrapper
{
public:
    virtual void read_version_resp(uint32_t a) {
        fprintf(stderr, "version %x\n", a);
    }
    MemoryTestIndication(unsigned int id) : MemoryTestIndicationWrapper(id) {}
};

class MallocIndication : public MallocIndicationWrapper
{
public:
    virtual void id_resp ( const uint32_t id ) {
        fprintf(stderr, "***CPP pktId=%x\n", id);
    }
    MallocIndication(unsigned int id) : MallocIndicationWrapper(id) {}
};

void usage (const char *program_name) {
    printf("%s: p4fpga tester\n"
     "usage: %s [OPTIONS] \n",
     program_name, program_name);
    printf("\nOther options:\n"
    " -p, --parser=FILE                demo parsing pcap log\n"
    );
}

static void 
parse_options(int argc, char *argv[], char **pcap_file) {
    int c, option_index;

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
                usage(get_exe_name(argv[0]));
                break;
            case 'p':
                *pcap_file = optarg;
                break;
            default:
                break;
        }
    }
}


int main(int argc, char **argv)
{
    char *pcap_file=NULL;
    void *buffer=NULL;
    long length=0;

    MemoryTestIndication echoIndication(IfcNames_MemoryTestIndicationH2S);
    device = new MemoryTestRequestProxy(IfcNames_MemoryTestRequestS2H);

    parse_options(argc, argv, &pcap_file);

    device->read_version();

    if (pcap_file) {
        fprintf(stderr, "Attempts to read pcap file %s\n", pcap_file);

        if (!read_pcap_file(pcap_file, &buffer, &length)) {
            perror("Failed to read file!");
            exit(-1);
        }

        if (int err = load_pcap_file(buffer, length)) {
            fprintf(stderr, "Error: %s\n", strerror(err));
        }
    }

    while (1) sleep(1);
    return 0;
}
