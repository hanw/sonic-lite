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
#include "MatchTestIndication.h"
#include "MatchTestRequest.h"
#include "GeneratedTypes.h"
#include "lutils.h"
#include "lpcap.h"

using namespace std;

#define DATA_WIDTH 128

MatchTestRequestProxy *device = 0;
static sem_t cmdCompleted;
uint8_t flowid;

void device_writePacketData(uint64_t* data, uint8_t* mask, int sop, int eop) {
}

class MatchTestIndication : public MatchTestIndicationWrapper
{
public:
    virtual void read_version_resp(uint32_t a) {
        fprintf(stderr, "version %x\n", a);
    }
    virtual void add_entry_resp(uint8_t id) {
        fprintf(stderr, "flow id %d\n", id);
        flowid = id;
        sem_post(&cmdCompleted);
    }
    virtual void match_table_resp(uint32_t a) {
        fprintf(stderr, "match result %x\n", a);
        sem_post(&cmdCompleted);
    }
    virtual void readMatchTableCntrsResp(uint64_t matchRequestCount, uint64_t matchResponseCount, uint64_t matchValidCount, uint64_t lastMatchIdx, uint64_t lastMatchRequest) {
        fprintf(stderr, "MatchTable: matchRequestCount=%ld, matchResponseCount=%ld, matchValidCount=%ld\n lastMatchIdx=%lx lastMatchRequest=%lx\n", matchRequestCount, matchResponseCount, matchValidCount, lastMatchIdx, lastMatchRequest);
        sem_post(&cmdCompleted);
    }
    MatchTestIndication(unsigned int id) : MatchTestIndicationWrapper(id) {}
};

void usage (const char *program_name) {
    printf("%s: p4fpga tester\n"
     "usage: %s [OPTIONS] \n",
     program_name, program_name);
    printf("\nOther options:\n"
    " -a add_entry"
    " -d del_entry"
    " -s status"
    " -l lookup_entry"
    );
}

struct arg_info {
    bool tableadd;
    bool tabledel;
    bool status;
    bool lookup;
};

static void
parse_options(int argc, char *argv[], struct arg_info* info) {
    int c, option_index;

    static struct option long_options [] = {
        {"help",                no_argument, 0, 'h'},
        {"table-add",           no_argument, 0, 'a'},
        {"table-del",           no_argument, 0, 'd'},
        {"table-lookup",        no_argument, 0, 'l'},
        {"status",              no_argument, 0, 's'},
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
            case 'a':
                info->tableadd = true;
                break;
            case 'd':
                info->tabledel = true;
                break;
            case 's':
                info->status = true;
                break;
            case 'l':
                info->lookup = true;
                break;
            default:
                exit(EXIT_FAILURE);
        }
    }
}

void erase_table () {
    for (int i =0; i < 256; i++) {
        device->delete_entry(0, i);
        //sem_wait(&cmdCompleted);
    }
}

void add_entry (MatchField *field) {
    device->add_entry(0, *field);
    //sem_wait(&cmdCompleted);
}

int main(int argc, char **argv)
{
    struct arg_info arguments = {0, 0};
    MatchTestIndication echoIndication(IfcNames_MatchTestIndicationH2S);
    device = new MatchTestRequestProxy(IfcNames_MatchTestRequestS2H);

    parse_options(argc, argv, &arguments);

    device->read_version();

    if (arguments.tabledel) {
        erase_table();
    }

    MatchField fields = {dstip:0};

    if (arguments.tableadd) {
        fields.dstip = 0x0300000a;
        add_entry(&fields);
        fields.dstip = 0x0400000a;
        add_entry(&fields);
        fields.dstip = 0x0500000a;
        add_entry(&fields);
        fields.dstip = 0x0600000a;
        add_entry(&fields);
    }

    if (arguments.lookup) {
        fields.dstip = 0x0400000a;
        device->lookup_entry(fields);
        sem_wait(&cmdCompleted);
    }

    if (arguments.lookup) {
        fields.dstip = 0x0400000a;
        device->lookup_entry(fields);
        sem_wait(&cmdCompleted);
    }

    if (arguments.status) {
        device->readMatchTableCntrs();
        sem_wait(&cmdCompleted);
    }

    while(1) sleep(1);
    return 0;
}
