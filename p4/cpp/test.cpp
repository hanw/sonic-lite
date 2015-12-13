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
#include <string.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <getopt.h>
#include <string>

#include "MemServerIndication.h"
#include "P4TopIndication.h"
#include "P4TopRequest.h"
#include "GeneratedTypes.h"
#include "utils.h"
#include "sonic_pcap_utils.h"

using namespace std;

#define DATA_WIDTH 128

static P4TopRequestProxy *device = 0;

class P4TopIndication : public P4TopIndicationWrapper
{
public:
    virtual void sonic_read_version_resp(uint32_t a) {
        fprintf(stderr, "version %x\n", a);
    }
    virtual void cam_search_result(uint64_t a) {
        fprintf(stderr, "cam search %lx\n", a);
    }
    virtual void read_setram_result(uint64_t a) {
        fprintf(stderr, "setram %lx\n", a);
    }
    virtual void match_table_resp(uint32_t a) {
    	fprintf(stderr, "match table");
    }
    virtual void matchTableResponse(uint64_t key, uint32_t value) {
        fprintf(stderr, "GET : key = %lu  value = %u\n", key, value);
    }

    P4TopIndication(unsigned int id) : P4TopIndicationWrapper(id) {}
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

void test_setram(P4TopRequestProxy *device) {
    device->writeSetRam(0x11, 0xff);
    device->readSetRam(0x11);
}

void test_bcam(P4TopRequestProxy *device) {
    fprintf(stderr, "Insert CAM\n");
    device->camInsert(0x0, 0x0);
    device->camInsert(0x1, 0x1);
    device->camInsert(0x2, 0x2);
    device->camInsert(0x3, 0x3);
    device->camSearch(0x0);
    device->camSearch(0x1);
    device->camSearch(0x2);
    device->camSearch(0x3);
}

void test_mtable(P4TopRequestProxy *device) {
    device->matchTableRequest(10, 15, 1); //PUT(10,15)
    device->matchTableRequest(10, 0, 0);  //GET(10) should print k=10 v=15
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
    " -b, --shared-buffer              demo shared buffer\n"
    " -p, --parser=FILE                demo parsing pcap log\n"
    " -m, --match-table=FILE           demo match table\n"
    " -f, --full-pipeline=FILE         demo full pipeline\n");
}

int main(int argc, char **argv)
{
    const char *program_name = get_exe_name(argv[0]);
    const char *pcap_file="";
    int c, option_index;

    bool run_basic = true;
    bool load_pcap = false;
    bool shared_buff_test = false;
    bool parser_test = false;
    bool match_table_test = false;
    bool full_test = false;

    P4TopIndication echoIndication(IfcNames_P4TopIndicationH2S);
    MemServerIndication memServerIndication(IfcNames_MemServerIndicationH2S);
    device = new P4TopRequestProxy(IfcNames_P4TopRequestS2H);

    static struct option long_options [] = {
        {"shared-buffer-test",  no_argument, 0, 'b'},
        {"help",                no_argument, 0, 'h'},
        {"parser-test",         required_argument, 0, 'p'},
        {"match-table-test",    required_argument, 0, 'm'},
        {"full-test",           required_argument, 0, 'f'},
        {0, 0, 0, 0}
    };
    static string short_options
        (long_options_to_short_options(long_options));

    for (;;) {
        c = getopt_long(argc, argv, short_options.c_str(), long_options, &option_index);

        if (c == -1)
            break;

        switch (c) {
            case 'b':
                shared_buff_test = true;
                break;
            case 'h':
                usage(program_name);
                run_basic = false;
                break;
            case 'p':
                load_pcap = true;
                parser_test = true;
                pcap_file = optarg;
                break;
            case 'm':
                load_pcap = true;
                match_table_test = true;
                pcap_file = optarg;
                break;
            case 'f':
                load_pcap = true;
                full_test = true;
                pcap_file = optarg;
                break;
            default:
                run_basic = false;
                break;
        }
    }

    if (run_basic) {
        device->sonic_read_version();
    }

    if (load_pcap) {
        fprintf(stderr, "Attempts to read pcap file %s\n", pcap_file);
//        if (int err = load_pcap_file(pcap_file)) {
//            fprintf(stderr, "Error: %s\n", strerror(err));
//        }
    }

    if (shared_buff_test) {
        device->writePacketBuffer(0, 0xFACEBABE);
        device->readPacketBuffer(0);
    }

    if (parser_test) {
        // load packet
        // parse
        // print match result
    }

    if (match_table_test) {
        // insert rule to match table
        // load packet
        // parse
        // print match result
    }

    if (full_test) {
        // insert rules to match table
        // load packet
        // print action
        // deparse
    }

    if (run_basic) {
        printf("done!");
    }
    return 0;
}
