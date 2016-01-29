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
#ifdef DEBUG
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
    virtual void addEntryResp(uint16_t a) {
        fprintf(stderr, "add flow id %x\n", a);
        sem_post(&cmdCompleted);
    }
    virtual void delEntryResp(uint16_t a) {
        fprintf(stderr, "del flow id %x\n", a);
        sem_post(&cmdCompleted);
    }
    virtual void readRingBuffCntrsResp(uint64_t sopEnq, uint64_t eopEnq, uint64_t sopDeq, uint64_t eopDeq) {
        fprintf(stderr, "RingBufferStatus:\n Rx sop=%ld, eop=%ld \n Tx sop=%ld, eop=%ld \n", sopEnq, eopEnq, sopDeq, eopDeq);
        sem_post(&cmdCompleted);
    }
    virtual void readMemMgmtCntrsResp(uint64_t allocCnt, uint64_t freeCnt, uint64_t allocCompleted, uint64_t freeCompleted, uint64_t errorCode, uint64_t lastIdFreed, uint64_t lastIdAllocated, uint64_t freeStarted, uint64_t firstSegment, uint64_t lastSegment, uint64_t currSegment, uint64_t invalidSegment) {
        fprintf(stderr, "MemMgmt: alloc=%ld, free=%ld, allocCompleted=%ld, freeCompleted=%ld, error=%ld\n", allocCnt, freeCnt, allocCompleted, freeCompleted, errorCode);
        fprintf(stderr, "MemMgmt: lastIdFreed=0x%lx, lastIdAllocated=0x%lx, freeStarted=%ld, firstSegment=0x%lx, lastSegment=0x%lx, currSegment=0x%lx, invalidSegment=%ld\n", lastIdFreed, lastIdAllocated, freeStarted, firstSegment, lastSegment, currSegment, invalidSegment);
        sem_post(&cmdCompleted);
    }
    virtual void readTDMCntrsResp(uint64_t lookupCnt, uint64_t modifyMacCnt, uint64_t fwdReqCnt, uint64_t sendCnt) {
        fprintf(stderr, "TDM: lookup=%ld, modifyMac=%ld, fwdReq=%ld, sent=%ld\n", lookupCnt, modifyMacCnt, fwdReqCnt, sendCnt);
        sem_post(&cmdCompleted);
    }
    virtual void readMatchTableCntrsResp(uint64_t matchRequestCount, uint64_t matchResponseCount, uint64_t matchValidCount, uint64_t lastMatchIdx, uint64_t lastMatchRequest) {
        fprintf(stderr, "MatchTable: matchRequestCount=%ld, matchResponseCount=%ld, matchValidCount=%ld\n lastMatchIdx=%lx lastMatchRequest=%lx\n", matchRequestCount, matchResponseCount, matchValidCount, lastMatchIdx, lastMatchRequest);
        sem_post(&cmdCompleted);
    }
    virtual void readTxThruCntrsResp(uint64_t goodputCount, uint64_t idleCount) {
        double utilization = (double) goodputCount / (goodputCount + idleCount);
        fprintf(stderr, "TxThru: GoodputCount=%ld, IdleCount=%ld, utilization=%f", goodputCount, idleCount, utilization);
        sem_post(&cmdCompleted);
    }
    MemoryTestIndication(unsigned int id) : MemoryTestIndicationWrapper(id) {}
};

#ifdef DEBUG
class MemMgmtIndication : public MemMgmtIndicationWrapper
{
public:
    virtual void memory_allocated(uint32_t a) {
        fprintf(stderr, "allocated id %x\n", a);
    }
    virtual void packet_committed(uint32_t a) {
        fprintf(stderr, "committed tag %x\n", a);
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
    bool checkStatus;
};

static void
parse_options(int argc, char *argv[], char **pcap_file, struct arg_info* info) {
    int c, option_index;

    static struct option long_options [] = {
        {"help",                no_argument, 0, 'h'},
        {"parser-test",         required_argument, 0, 'p'},
        {"pktgen-rate",         required_argument, 0, 'r'},
        {"pktgen-count",        required_argument, 0, 'n'},
        {"table-add",           no_argument, 0, 'a'},
        {"table-del",           no_argument, 0, 'd'},
        {"dump-stats",          no_argument, 0, 's'},
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
            case 's':
                info->checkStatus = true;
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

void erase_table () {
    for (int i =0; i < 256; i++) {
        device->deleteEntry(0, i);
        //sem_wait(&cmdCompleted);
    }
}

void add_entry (MatchField *field) {
    device->addEntry(0, *field);
    sem_wait(&cmdCompleted);
}

void read_status () {
    device->readRingBuffCntrs(0);
    sem_wait(&cmdCompleted);
    device->readRingBuffCntrs(1);
    sem_wait(&cmdCompleted);
    device->readRingBuffCntrs(2);
    sem_wait(&cmdCompleted);
    device->readTDMCntrs();
    sem_wait(&cmdCompleted);
    device->readMemMgmtCntrs();
    sem_wait(&cmdCompleted);
    device->readMatchTableCntrs();
    sem_wait(&cmdCompleted);
}

int main(int argc, char **argv)
{
    char *pcap_file=NULL;
    struct arg_info arguments = {0, 0};
    struct pcap_trace_info pcap_info = {0, 0};

    MemoryTestIndication echoIndication(IfcNames_MemoryTestIndicationH2S);
#ifdef DEBUG
    MemMgmtIndication memMgmtIndication(IfcNames_MemMgmtIndicationH2S);
#endif

    device = new MemoryTestRequestProxy(IfcNames_MemoryTestRequestS2H);

    parse_options(argc, argv, &pcap_file, &arguments);

    device->read_version();
    sem_wait(&cmdCompleted);

    if (pcap_file) {
        fprintf(stderr, "Attempts to read pcap file %s\n", pcap_file);
        load_pcap_file(pcap_file, &pcap_info);
    }

    if (arguments.tableadd) {
        MatchField fields = {dstip: 0x0300000a};
        add_entry(&fields);
        fields.dstip = 0x0400000a;
        add_entry(&fields);
        fields.dstip = 0x0100000a;
        add_entry(&fields);
        fields.dstip = 0x0200000a;
        add_entry(&fields);
    }

    if (arguments.tabledel) {
        erase_table();
    }

    if (arguments.tableadd) {
        MatchField fields = {dstip: 0x0300000a};
        add_entry(&fields);
        fields.dstip = 0x0400000a;
        add_entry(&fields);
        fields.dstip = 0x0100000a;
        add_entry(&fields);
        fields.dstip = 0x0200000a;
        add_entry(&fields);
    }

    if (arguments.rate && arguments.tracelen) {
        int idle = compute_idle(&pcap_info, arguments.rate, LINK_SPEED);
        device->start(arguments.tracelen, idle);
        sleep(5);
        device->stop();
    }

    if (arguments.checkStatus) {
        sleep(1);
        read_status();
    }

    return 0;
}
