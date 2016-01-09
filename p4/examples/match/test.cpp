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
#include "lutils.h"
#include "lpcap.h"
#include "globals.h"

using namespace std;

#define DATA_WIDTH 128

MatchTestRequestProxy *device = 0;
static sem_t sem_ctrl;
uint16_t flowid;

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

void usage (const char *program_name) {
    printf("%s: p4fpga tester\n"
     "usage: %s [OPTIONS] \n",
     program_name, program_name);
    printf("\nOther options:\n"
    " -m, --match-table=FILE           demo match table\n"
    );
}

static void 
parse_options(int argc, char *argv[], char **pcap_file) {
    int c, option_index;

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
                usage(get_exe_name(argv[0]));
                break;
            case 'm':
                *pcap_file = optarg;
                break;
            default:
                break;
        }
    }
}

int main(int argc, char **argv)
{
    MatchTestIndication echoIndication(IfcNames_MatchTestIndicationH2S);
    device = new MatchTestRequestProxy(IfcNames_MatchTestRequestS2H);

    char *pcap_file=NULL;
    void *buffer=NULL;
    long length=0;

    parse_options(argc, argv, &pcap_file);

    device->read_version();

    if (pcap_file) {
        fprintf(stderr, "match table\n");
        // insert rule to match table
        MatchInput match_input = { key1: 4, key2: 4};
        device->add_entry(0, match_input);
        sem_wait(&sem_ctrl);
    }

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

    if (pcap_file) {
        device->delete_entry(0, flowid);
    }

    while (1) sleep(1);
    return 0;
}
