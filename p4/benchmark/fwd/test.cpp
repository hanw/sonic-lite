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
#include "FwdTestIndication.h"
#include "FwdTestRequest.h"
#include "GeneratedTypes.h"
#include "lutils.h"
#include "lpcap.h"

using namespace std;

#define DATA_WIDTH 128

static FwdTestRequestProxy *device = 0;
uint16_t flowid;
sem_t cmdCompleted;

void device_writePacketData(uint64_t* data, uint8_t* mask, int sop, int eop) {
    device->writePacketData(data, mask, sop, eop);
}

class FwdTestIndication : public FwdTestIndicationWrapper
{
public:
    virtual void read_version_resp(uint32_t a) {
        fprintf(stderr, "version %x\n", a);
        sem_post(&cmdCompleted);
    }
    virtual void readRxRingBuffCntrsResp(uint64_t sopEnq, uint64_t eopEnq, uint64_t sopDeq, uint64_t eopDeq) {
        fprintf(stderr, "RxRingBufferStatus:\n Rx sop=%ld, eop=%ld \n Tx sop=%ld, eop=%ld \n", sopEnq, eopEnq, sopDeq, eopDeq);
        sem_post(&cmdCompleted);
    }
    virtual void readTxRingBuffCntrsResp(uint64_t sopEnq, uint64_t eopEnq, uint64_t sopDeq, uint64_t eopDeq) {
        fprintf(stderr, "TxRingBufferStatus:\n Rx sop=%ld, eop=%ld \n Tx sop=%ld, eop=%ld \n", sopEnq, eopEnq, sopDeq, eopDeq);
        sem_post(&cmdCompleted);
    }
    virtual void readMemMgmtCntrsResp(uint64_t allocCnt, uint64_t freeCnt, uint64_t allocCompleted, uint64_t freeCompleted, uint64_t errorCode, uint64_t lastIdFreed, uint64_t lastIdAllocated, uint64_t freeStarted, uint64_t firstSegment, uint64_t lastSegment, uint64_t currSegment, uint64_t invalidSegment) {
        fprintf(stderr, "MemMgmt: alloc=%ld, free=%ld, allocCompleted=%ld, freeCompleted=%ld, error=%ld\n", allocCnt, freeCnt, allocCompleted, freeCompleted, errorCode);
        fprintf(stderr, "MemMgmt: lastIdFreed=0x%lx, lastIdAllocated=0x%lx, freeStarted=%ld, firstSegment=0x%lx, lastSegment=0x%lx, currSegment=0x%lx, invalidSegment=%ld\n", lastIdFreed, lastIdAllocated, freeStarted, firstSegment, lastSegment, currSegment, invalidSegment);
        sem_post(&cmdCompleted);
    }
    virtual void readIngressCntrsResp(uint64_t fwdCnt) {
        fprintf(stderr, "Ingress: fwdCnt=%ld \n", fwdCnt);
        sem_post(&cmdCompleted);
    }
    virtual void readHostChanCntrsResp(uint64_t paxosCnt, uint64_t ipv6Cnt, uint64_t udpCnt) {
        fprintf(stderr, "HostChan: paxosCnt=%ld, ipv6Cnt=%ld, udpCnt=%ld \n", paxosCnt, ipv6Cnt, udpCnt);
        sem_post(&cmdCompleted);
    }
    virtual void readRxChanCntrsResp(uint64_t paxosCnt, uint64_t ipv6Cnt, uint64_t udpCnt) {
        fprintf(stderr, "RxChan: paxosCnt=%ld, ipv6Cnt=%ld, udpCnt=%ld \n", paxosCnt, ipv6Cnt, udpCnt);
        sem_post(&cmdCompleted);
    }
    FwdTestIndication(unsigned int id) : FwdTestIndicationWrapper(id) {}
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
parse_options(int argc, char *argv[], char **pcap_file, struct arg_info* info) {
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

struct arg_info {
    double rate;
    int tracelen;
};

void read_status () {
    device->readRxRingBuffCntrs();
    sem_wait(&cmdCompleted);
    device->readTxRingBuffCntrs();
    sem_wait(&cmdCompleted);
    device->readMemMgmtCntrs();
    sem_wait(&cmdCompleted);
    device->readIngressCntrs();
    sem_wait(&cmdCompleted);
    device->readHostChanCntrs();
    sem_wait(&cmdCompleted);
    device->readRxChanCntrs();
    sem_wait(&cmdCompleted);
}


int main(int argc, char **argv)
{
    char *pcap_file=NULL;
    struct arg_info arguments = {0, 0};
    struct pcap_trace_info pcap_info = {0, 0};

    FwdTestIndication echoIndication(IfcNames_FwdTestIndicationH2S);
    device = new FwdTestRequestProxy(IfcNames_FwdTestRequestS2H);

    parse_options(argc, argv, &pcap_file, &arguments);

    device->read_version();
    sem_wait(&cmdCompleted);

    if (pcap_file) {
        fprintf(stderr, "Attempts to read pcap file %s\n", pcap_file);
        load_pcap_file(pcap_file, &pcap_info);
    }

    sleep(5);

    read_status();

    return 0;
}
