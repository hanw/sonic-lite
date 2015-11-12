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
#include <errno.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <getopt.h>
#include <string>

#include "MemServerIndication.h"
#include "MatchTestIndication.h"
#include "MatchTestRequest.h"
#include "GeneratedTypes.h"
#include "utils.h"
#include "sonic_pcap_utils.h"

using namespace std;

#define DATA_WIDTH 128

static MatchTestRequestProxy *device = 0;
static sem_t sem_ctrl;
uint16_t flowid;

void mem_copy(const void *buff, int length);

class MatchTestIndication : public MatchTestIndicationWrapper
{
public:
    virtual void read_version_resp(uint32_t a) {
        fprintf(stderr, "version %x\n", a);
    }
    virtual void add_entry_resp(uint16_t id) {
        fprintf(stderr, "flow id %d\n", id);
        flowid = id;
        sem_post(&sem_ctrl);
    }
    MatchTestIndication(unsigned int id) : MatchTestIndicationWrapper(id) {}
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

const char* get_exe_name(const char* argv0) {
    if (const char *last_slash = strrchr(argv0, '/')) {
        return last_slash + 1;
    }
    return argv0;
}

void usage (const char *program_name) {
    printf("%s: p4fpga tester\n"
     "usage: %s [OPTIONS] \n",
     program_name, program_name);
    printf("\nOther options:\n"
    " -m, --match-table=FILE           demo match table\n"
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

    MatchTestIndication echoIndication(IfcNames_MatchTestIndicationH2S);
    //MemServerIndication memServerIndication(IfcNames_MemServerIndicationH2S);
    device = new MatchTestRequestProxy(IfcNames_MatchTestRequestS2H);

    bool run_basic = true;
    bool load_pcap = false;
    bool match_table_test = false;

    static struct option long_options [] = {
        {"help",                no_argument, 0, 'h'},
        {"match-table-test",    required_argument, 0, 'm'},
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
            case 'm':
                fprintf(stderr, "got m\n");
                load_pcap = true;
                match_table_test = true;
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

    if (match_table_test) {
        fprintf(stderr, "match table\n");
        // insert rule to match table
        MatchInput match_input = { key1: 4, key2: 4};
        device->add_entry(0, match_input);
        sem_wait(&sem_ctrl);
        device->delete_entry(0, flowid);
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
