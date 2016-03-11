#include <cstdlib>
#include <stdio.h>
#include <stdlib.h>
#include <semaphore.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include <fstream>
#include <sstream>
#include <iostream>

#include "MemServerRequest.h"
#include "TestRequest.h"
#include "TestIndication.h"
#include "GeneratedTypes.h"
#include "lutils.h"
#include "lpcap.h"

using namespace std;

#define ITERATION 100

static TestRequestProxy *device=0;
sem_t cmdCompleted;

void device_writePacketData(uint64_t* data, uint8_t* mask, int sop, int eop) {
    device->writePacketData(data, mask, sop, eop);
}

class TestIndication : public TestIndicationWrapper {
public:
    virtual void read_version_resp(uint32_t a) {
        fprintf(stderr, "version %x\n", a);
        sem_post(&cmdCompleted);
    }
    virtual void readRingBuffCntrsResp(uint64_t sopEnq, uint64_t eopEnq, uint64_t sopDeq, uint64_t eopDeq) {
        fprintf(stderr, "RingBufferStatus:\n Rx sop=%ld, eop=%ld \n Tx sop=%ld, eop=%ld \n", sopEnq, eopEnq, sopDeq, eopDeq);
        sem_post(&cmdCompleted);
    }
    virtual void readTxThruCntrsResp(uint64_t goodputCount, uint64_t idleCount) {
        double utilization = (double) goodputCount / (goodputCount + idleCount);
        fprintf(stderr, "TxThru: GoodputCount=%ld, IdleCount=%ld, utilization=%f\n", goodputCount, idleCount, utilization);
        sem_post(&cmdCompleted);
    }
    virtual void readRxCycleCntResp(uint64_t p0_cnt, uint64_t p1_cnt) {
        fprintf(stderr, "Cycle cnt=%ld, %ld\n", p0_cnt, p1_cnt);
        sem_post(&cmdCompleted);
    }

  TestIndication(int id) : TestIndicationWrapper(id){}
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
                exit(EXIT_FAILURE);
        }
    }
}

void read_status () {
    device->readRingBuffCntrs(0);
    sem_wait(&cmdCompleted);
    device->readTxThruCntrs();
    sem_wait(&cmdCompleted);
    device->readRxCycleCnt();
    sem_wait(&cmdCompleted);
}

int main(int argc, char **argv) {
    char *pcap_file= NULL;
    struct pcap_trace_info pcap_info = {0, 0};

    TestIndication deviceIndication(IfcNames_TestIndicationH2S);
    device = new TestRequestProxy(IfcNames_TestRequestS2H);

    parse_options(argc, argv, &pcap_file);

    device->read_version();
    sem_wait(&cmdCompleted);

    if (pcap_file) {
        fprintf(stderr, "Attempts to read pcap file %s\n", pcap_file);
        load_pcap_file(pcap_file, &pcap_info);
    }

    sleep(1);
    read_status();

    return 0;
}
