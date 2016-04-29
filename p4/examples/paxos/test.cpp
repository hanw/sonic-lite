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
#define InstanceSize 32

static MemoryTestRequestProxy *device = 0;
uint16_t flowid;

void device_writePacketData(uint64_t* data, uint8_t* mask, int sop, int eop) {
    device->writePacketData(data, mask, sop, eop);
}

class MemoryTestIndication : public MemoryTestIndicationWrapper
{
public:
    virtual void read_version_resp(uint32_t a) {
        fprintf(stderr, "version %x\n", a);
    }
    virtual void read_ingress_debug_info_resp(IngressDbgRec a) {
        fprintf(stderr, "fwdCount %ld, acc_in %ld, acc_out %ld, dmac_in %ld, dmac_out %ld\n",
            a.fwdCount, a.accTbl.pktIn, a.accTbl.pktOut, a.dmacTbl.pktIn, a.dmacTbl.pktOut);
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
    double rate;
    int tracelen;
    Role role;
};

static void 
parse_options(int argc, char *argv[], char **pcap_file, struct arg_info* info) {
    int c, option_index;

    static struct option long_options [] = {
        {"help",                no_argument, 0, 'h'},
        {"parser-test",         required_argument, 0, 'p'},
        {"acceptor",            no_argument, 0, 'A'},
        {"coordinator",         no_argument, 0, 'C'},
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
            default:
                break;
        }
    }
}

int main(int argc, char **argv)
{
    char *pcap_file=NULL;
    struct arg_info arguments = {0, 0, ACCEPTOR};
    struct pcap_trace_info pcap_info = {0, 0};

    MemoryTestIndication echoIndication(IfcNames_MemoryTestIndicationH2S);
    device = new MemoryTestRequestProxy(IfcNames_MemoryTestRequestS2H);

    parse_options(argc, argv, &pcap_file, &arguments);

    device->read_version();

    device->datapath_id_reg_write(1);
    device->role_reg_write(arguments.role);
    device->instance_reg_write(0x1234);
    bsvvector_Luint32_t_L8 vect;
    for (int i = 0; i < 8; i++)
        vect[i] = 0;

    for (int index=0; index<InstanceSize; index++){
        device->vround_reg_write(index, 0);
        device->round_reg_write(index, 0);
        device->value_reg_write(index, vect);
    }

    //device->dmacTable_add_entry(0x80a810270008, FORWARD, 1);
    device->dmacTable_add_entry(0x80a810270008, 1);
    device->dmacTable_add_entry(0x491d035e0001, 1);

    device->sequenceTable_add_entry(1, IncreaseInstance);
    AcceptorTblActionT action_ = Handle2A;
    device->acceptorTable_add_entry(0x4, action_);
    device->acceptorTable_add_entry(0x3, action_);
    device->acceptorTable_add_entry(0x2, action_);
    device->acceptorTable_add_entry(0x1, action_);
    device->acceptorTable_add_entry(0x0, action_);

    if (pcap_file) {
        fprintf(stderr, "Attempts to read pcap file %s\n", pcap_file);
        load_pcap_file(pcap_file, &pcap_info);
    }

    sleep(3);
    device->read_ingress_debug_info();
    device->read_hostchan_debug_info();
    device->read_txchan_debug_info();
    device->read_rxchan_debug_info();
    sleep(3);
    return 0;
}
