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
#ifdef SIMULATION
#include "MemMgmtIndication.h"
#endif
#include "MemoryTestIndication.h"
#include "MemoryTestRequest.h"
#include "GeneratedTypes.h"
#include "lutils.h"
#include "lpcap.h"
#include <cstdlib>
#include <stdio.h>
#include <stdlib.h>
#include <semaphore.h>

using namespace std;

#define DATA_WIDTH 128
#define LINK_SPEED 10

static MemoryTestRequestProxy *device = 0;
uint16_t flowid;
sem_t alloc_sem;
sem_t free_sem;
sem_t flow_sem;

void device_writePacketData(uint64_t* data, uint8_t* mask, int sop, int eop) {
    device->writePacketData(data, mask, sop, eop);
}

class MemoryTestIndication : public MemoryTestIndicationWrapper
{
public:
    virtual void read_version_resp(uint32_t a) {
        fprintf(stderr, "version %x\n", a);
    }
    virtual void addEntryResp(uint16_t a) {
        fprintf(stderr, "add flow id %x\n", a);
        sem_post(&flow_sem);
    }
    MemoryTestIndication(unsigned int id) : MemoryTestIndicationWrapper(id) {}
};

#ifdef SIMULATION
class MemMgmtIndication : public MemMgmtIndicationWrapper
{
public:
    virtual void memory_allocated(uint32_t a) {
        fprintf(stderr, "allocated id %x\n", a);
        sem_post(&alloc_sem);
    }
    virtual void packet_committed(uint32_t a) {
        fprintf(stderr, "committed tag %x\n", a);
        sem_post(&free_sem);
    }
    virtual void packet_freed(uint32_t a) {
        fprintf(stderr, "packet freed %x\n", a);
    }
    virtual void error(uint32_t errorType, uint32_t id) {
        fprintf(stderr, "error: %x %x\n", errorType, id);
    }
    MemMgmtIndication(unsigned int id) : MemMgmtIndicationWrapper(id) {}
};
#endif

void usage (const char *program_name) {
    printf("%s: p4fpga tester\n"
     "usage: %s [OPTIONS] \n",
     program_name, program_name);
    printf("\nOther options:\n"
    " -p, --parser=FILE                demo parsing pcap log\n"
    );
}

struct arg_info {
    double rate;
    int tracelen;
    bool tableadd;
    bool tabledel;
};

static void
parse_options(int argc, char *argv[], char **pcap_file, struct arg_info* info) {
    int c, option_index;

    static struct option long_options [] = {
        {"help",                no_argument, 0, 'h'},
        {"parser-test",         required_argument, 0, 'p'},
        {"pktgen-rate",         required_argument, 0, 'r'},
        {"pktgen-count",        required_argument, 0, 'n'},
        {"table-add",           required_argument, 0, 'a'},
        {"table-del",           required_argument, 0, 'd'},
        {"table-mod",           required_argument, 0, 'm'},
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
            case 'r':
                info->rate = strtod(optarg, NULL);
                break;
            case 'n':
                info->tracelen = strtol(optarg, NULL, 0);
                break;
            case 'a':
                info->tableadd = true;
                break;
            case 'd':
                info->tabledel = true;
                break;
            default:
                exit(EXIT_FAILURE);
        }
    }
}

/* compute idle character in bytes (round to closest 16) */
int
compute_idle (const struct pcap_trace_info *info, double rate, double link_speed) {

    double idle_count = (link_speed - rate) * info->byte_count / rate;
    int idle = idle_count / info->packet_count;
    int average_packet_len = info->byte_count / info->packet_count;
    fprintf(stderr, "idle = %d, link_speed=%f, rate=%f, average packet len = %d\n", idle, link_speed, rate, average_packet_len);
    return idle;
}

int main(int argc, char **argv)
{
    char *pcap_file=NULL;
    struct arg_info arguments = {0, 0};
    struct pcap_trace_info pcap_info = {0, 0};

    MemoryTestIndication echoIndication(IfcNames_MemoryTestIndicationH2S);
#ifdef SIMULATION
    MemMgmtIndication memMgmtIndication(IfcNames_MemMgmtIndicationH2S);
#endif

    device = new MemoryTestRequestProxy(IfcNames_MemoryTestRequestS2H);

    parse_options(argc, argv, &pcap_file, &arguments);

    device->read_version();

    if (pcap_file) {
        fprintf(stderr, "Attempts to read pcap file %s\n", pcap_file);
        load_pcap_file(pcap_file, &pcap_info);
    }

    if (arguments.tableadd) {
        MatchField fields = {dstip: 0x0200000a};
        device->addEntry(0, fields);
        sem_wait(&flow_sem);
    }

    if (arguments.tabledel) {
        device->deleteEntry(0, flowid);
    }

    if (arguments.rate && arguments.tracelen) {
        int idle = compute_idle(&pcap_info, arguments.rate, LINK_SPEED);
        device->start(arguments.tracelen, idle);
        sem_wait(&alloc_sem);
        device->free(0);
        sem_wait(&free_sem);
        //device->free(1);
    }

    while(1) sleep(1);
    return 0;
}
