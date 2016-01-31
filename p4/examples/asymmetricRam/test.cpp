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

#include "MemoryTestIndication.h"
#include "MemoryTestRequest.h"
#include "GeneratedTypes.h"
#include "lutils.h"
#include "lpcap.h"
#include <cstdlib>
#include <stdio.h>
#include <stdlib.h>

using namespace std;

#define READ 1
#define WRITE 2

static MemoryTestRequestProxy *device = 0;
sem_t cmdCompleted;

void device_writePacketData(uint64_t* data, uint8_t* mask, int sop, int eop) {
    device->writePacketData(data, mask, sop, eop);
}

class MemoryTestIndication : public MemoryTestIndicationWrapper
{
public:
    virtual void read_version_resp(uint32_t a) {
        fprintf(stderr, "version %x\n", a);
        sem_post(&cmdCompleted);
    }
    virtual void readMemResp(uint32_t a) {
        fprintf(stderr, "data %x\n", a);
        sem_post(&cmdCompleted);
    }
    MemoryTestIndication(unsigned int id) : MemoryTestIndicationWrapper(id) {}
};

void usage (const char *program_name) {
    printf("%s: p4fpga tester\n"
     "usage: %s [OPTIONS] \n",
     program_name, program_name);
    printf("\nOther options:\n"
    " -p, --parser=FILE                demo parsing pcap log\n"
    );
}


struct arg_info {
    long mode;
    long data;
    long address;
};

static void 
parse_options(int argc, char *argv[], struct arg_info* info) {
    int c, option_index;

    static struct option long_options [] = {
        {"help",                no_argument, 0, 'h'},
        {"read",                no_argument, 0, 'r'},
        {"write",               no_argument, 0, 'w'},
        {"address",             required_argument, 0, 'a'},
        {"data",                required_argument, 0, 'd'},
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
            case 'r':
                info->mode = READ;
                break;
            case 'w':
                info->mode = WRITE;
                break;
            case 'd':
                info->data = strtol(optarg, NULL, 0);
                break;
            case 'a':
                info->address = strtol(optarg, NULL, 0);
                break;
            default:
                exit(EXIT_FAILURE);
        }
    }
}

int main(int argc, char **argv)
{
    struct arg_info arguments = {0, 0, 0};

    MemoryTestIndication echoIndication(IfcNames_MemoryTestIndicationH2S);
    device = new MemoryTestRequestProxy(IfcNames_MemoryTestRequestS2H);

    parse_options(argc, argv, &arguments);

    device->read_version();

    if (arguments.mode == READ) {
        device->memRead(arguments.address);
        sem_wait(&cmdCompleted);
    }

    if (arguments.mode == WRITE) {
        device->memWrite(arguments.address, arguments.data);
        sem_wait(&cmdCompleted);
    }

    return 0;
}
