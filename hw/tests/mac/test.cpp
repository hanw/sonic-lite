#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include <fstream>
#include <sstream>
#include <iostream>
#include <string>

#include "MemServerRequest.h"
#include "TestRequest.h"
#include "TestIndication.h"
#include "GeneratedTypes.h"
#include "utils.h"
#include "sonic_pcap_utils.h"

using namespace std;

#define ITERATION 100

sem_t test_sem;
static TestRequestProxy *device=0;

class TestIndication : public TestIndicationWrapper {
public:
  virtual void done(uint32_t v){
      sem_post(&test_sem);
  }
  TestIndication(int id) : TestIndicationWrapper(id){}
};

void mem_copy(const void *buff, int packet_size) {

    int i, sop, eop;
    uint64_t data[2];
    uint8_t mask[2];
    int numBeats;

    numBeats = packet_size / 8; // 16 bytes per beat for 128-bit datawidth;
    if (packet_size % 8) numBeats++;
    PRINT_INFO("nBeats=%d, packetSize=%d\n", numBeats, packet_size);
    for (i=0; i<numBeats; i++) {
        data[i%2] = *(static_cast<const uint64_t *>(buff) + i);
        if (packet_size > 8) {
            mask[i%2] = 0xff;
            packet_size -= 8; // 64-bit
        } else {
            mask[i%2] = ((1 << packet_size) - 1) & 0xff;
            packet_size = 0;
        }
        sop = (i/2 == 0);
        eop = (i/2 == (numBeats-1)/2);
        if (i%2) {
            device->writePacketData(data, mask, sop, eop);
            PRINT_INFO("%016lx %016lx %0x %0x %d %d\n", data[1], data[0], mask[1], mask[0], sop, eop);
        }

        // last beat, padding with zero
        if ((numBeats%2!=0) && (i==numBeats-1)) {
            sop = (i/2 == 0) ? 1 : 0;
            eop = 1;
            data[1] = 0;
            mask[1] = 0;
            device->writePacketData(data, mask, sop, eop);
            PRINT_INFO("%016lx %016lx %0x %0x %d %d\n", data[1], data[0], mask[1], mask[0], sop, eop);
        }
    }
}

void usage (const char *program_name) {
    printf("%s: p4fpga tester\n"
     "usage: %s [OPTIONS] \n",
     program_name, program_name);
    printf("\nOther options:\n"
    " -b, --shared-buffer              demo shared buffer\n");
}

int main(int argc, char **argv) {
    const char *program_name = get_exe_name(argv[0]);
    const char *pcap_file="";
    void *buffer;
    long length;
    int c, option_index;
    bool load_pcap = false;

    TestIndication deviceIndication(IfcNames_TestIndicationH2S);
    device = new TestRequestProxy(IfcNames_TestRequestS2H);

    static struct option long_options [] = {
        {"packet",  required_argument, 0, 'p'},
        {"help",                no_argument, 0, 'h'},
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
                break;
            case 'p':
                load_pcap = true;
                pcap_file = optarg;
                break;
         }
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

    sem_wait(&test_sem);
    return 0;
}
