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
#include "MemoryTestIndication.h"
#include "MemoryTestRequest.h"
#include "GeneratedTypes.h"
#include "lutils.h"
#include "lpcap.h"

using namespace std;

#define DATA_WIDTH 128
#define LINK_SPEED 10
#define InstanceSize 32

static MemoryTestRequestProxy *device = 0;
uint16_t flowid;

bool hwpktgen = false;

void device_writePacketData(uint64_t* data, uint8_t* mask, int sop, int eop) {
    if (hwpktgen) {
        device->writePktGenData(data, mask, sop, eop);
    } else {
        device->writePacketData(data, mask, sop, eop);
    }
}

class MemoryTestIndication : public MemoryTestIndicationWrapper
{
public:
    virtual void read_version_resp(uint32_t a) {
        fprintf(stderr, "version %x\n", a);
    }
    virtual void read_ingress_debug_info_resp(IngressDbgRec a) {
        fprintf(stderr, "fwdCount %ld, acc_in %ld, acc_out %ld, seq_in %ld, seq_out %ld, dmac_in %ld, dmac_out %ld\n",
            a.fwdCount, a.accTbl.pktIn, a.accTbl.pktOut, a.seqTbl.pktIn, a.seqTbl.pktOut, a.dmacTbl.pktIn, a.dmacTbl.pktOut);
    }
    virtual void read_hostchan_debug_info_resp(HostChannelDbgRec a) {
        fprintf(stderr, "paxosCount %ld, sop %ld/%ld, eop %ld/%ld\n",
            a.paxosCount, a.pktBuff.sopEnq, a.pktBuff.sopDeq, a.pktBuff.eopEnq, a.pktBuff.eopDeq);
    }
    virtual void read_txchan_debug_info_resp(TxChannelDbgRec a) {
        fprintf(stderr, "egressCount %ld, sop %ld/%ld, eop %ld/%ld\n",
            a.egressCount, a.pktBuff.sopEnq, a.pktBuff.sopDeq, a.pktBuff.eopEnq, a.pktBuff.eopDeq);
    }
    virtual void read_rxchan_debug_info_resp(HostChannelDbgRec a) {
        fprintf(stderr, "paxosCount %ld, sop %ld/%ld, eop %ld/%ld\n",
            a.paxosCount, a.pktBuff.sopEnq, a.pktBuff.sopDeq, a.pktBuff.eopEnq, a.pktBuff.eopDeq);
    }
    virtual void read_role_resp(Role role) {
        fprintf(stderr, "role %d\n", role);
    }
    virtual void read_ingress_perf_info_resp(IngressPerfRec a) {
        fprintf(stderr, "perf: ingress %x, %x, acceptor %x, %x, sequence %x, %x\n", 
            a.ingress_start_time, a.ingress_end_time, a.acceptor_start_time, a.acceptor_end_time,
            a.sequence_start_time, a.sequence_end_time);
    }
    virtual void read_parser_perf_info_resp(ParserPerfRec a) {
        fprintf(stderr, "perf: parser %x %x\n", a.parser_start_time, a.parser_end_time);
    }
    MemoryTestIndication(unsigned int id) : MemoryTestIndicationWrapper(id) {}
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
    " -p, --parser=FILE                demo parsing pcap log\n"
    );
}

struct arg_info {
    Role role;
    uint16_t acptid;
    uint32_t inst;
    double rate;
    uint64_t tracelen;
};

static void 
parse_options(int argc, char *argv[], char **pcap_file, struct arg_info* info) {
    int c, option_index;

    static struct option long_options [] = {
        {"help",                no_argument, 0, 'h'},
        {"pcap",                required_argument, 0, 'p'},
        {"acceptor",            no_argument, 0, 'A'},
        {"coordinator",         no_argument, 0, 'C'},
        {"acptid",              required_argument, 0, 'a'},
        {"inst",                required_argument, 0, 'i'},
        {"pktgen-rate",         required_argument, 0, 'r'},
        {"pktgen-count",        required_argument, 0, 'n'},
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
            case 'A':
                info->role = ACCEPTOR;
                break;
            case 'C':
                info->role = COORDINATOR;
                break;
            case 'a':
                info->acptid = atoi(optarg);
                break;
            case 'i':
                info->inst = atoi(optarg);
                break;
            case 'r':
                info->rate = strtod(optarg, NULL);
                break;
            case 'n':
                info->tracelen = strtol(optarg, NULL, 0);
                break;
            default:
                break;
        }
    }
}

int main(int argc, char **argv)
{
    char *pcap_file=NULL;
    struct arg_info arguments = {ACCEPTOR, 0, 0, 0.0, 0};
    struct pcap_trace_info pcap_info = {0, 0};

    MemoryTestIndication echoIndication(IfcNames_MemoryTestIndicationH2S);
    device = new MemoryTestRequestProxy(IfcNames_MemoryTestRequestS2H);

    parse_options(argc, argv, &pcap_file, &arguments);

    device->read_version();

    device->datapath_id_reg_write(arguments.acptid);
    device->role_reg_write(arguments.role);
    device->instance_reg_write(arguments.inst);
    bsvvector_Luint32_t_L8 vect;
    for (int i = 0; i < 8; i++)
        vect[i] = 0;

    for (int index=0; index<InstanceSize; index++){
        device->vround_reg_write(index, 0);
        device->round_reg_write(index, 0);
        device->value_reg_write(index, vect);
    }
    device->role_reg_read();

    //device->dmacTable_add_entry(0x80a810270008, FORWARD, 1);
    device->dmacTable_add_entry(0x80a810270008, 1);
    device->dmacTable_add_entry(0x491d035e0001, 1);
    device->dmacTable_add_entry(0x471d035e0001, 1);

    device->sequenceTable_add_entry(0x4, IncreaseInstance);
    device->sequenceTable_add_entry(0x3, IncreaseInstance);
    device->sequenceTable_add_entry(0x2, IncreaseInstance);
    device->sequenceTable_add_entry(0x1, IncreaseInstance);
    device->sequenceTable_add_entry(0x0, IncreaseInstance);
    device->acceptorTable_add_entry(0x3, Handle2A);
    device->acceptorTable_add_entry(0x1, Handle1A);

    if (arguments.rate && arguments.tracelen) {
        hwpktgen = true;
    }

    if (pcap_file) {
        fprintf(stderr, "Attempts to read pcap file %s\n", pcap_file);
        load_pcap_file(pcap_file, &pcap_info);
    }

    if (arguments.rate && arguments.tracelen) {
        int idle = compute_idle(&pcap_info, arguments.rate, LINK_SPEED);
        device->pktgen_start(arguments.tracelen, idle);
    }

    sleep(3);
    device->read_ingress_debug_info();
    device->read_hostchan_debug_info();
    device->read_txchan_debug_info();
    device->read_rxchan_debug_info();
    device->read_ingress_perf_info();
    device->read_parser_perf_info();
    sleep(3);
    return 0;
}
