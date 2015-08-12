#include <assert.h>
#include <pthread.h>
#include <stdio.h>
#include <tins/tins.h>

#include "dmaManager.h"
#include "SonicTopRequest.h"
#include "SonicTopIndication.h"

using namespace Tins;

int burstLen = 8;
int numWords = 0x4000/4; // make sure to allocate at least one entry of each size
int iterCnt = 1;
static SonicTopRequestProxy *device = 0;
static sem_t test_sem;
static size_t test_sz  = numWords*sizeof(unsigned int);
static size_t alloc_sz = test_sz;
static int mismatchCount = 0;

class SonicTopIndication : public SonicTopIndicationWrapper
{
    public:
        virtual void sonic_read_version_resp(uint32_t a) {
            fprintf(stderr, "read version %d\n", a);
        }
        virtual void readDone(uint32_t a) {
            fprintf(stderr, "SonicTop::readDone(%x)\n", a);
            mismatchCount += a;
            sem_post(&test_sem);
        }
        void writeDone ( uint32_t srcGen ) {
            fprintf(stderr, "Memwrite::writeDone (%08x)\n", srcGen);
            sem_post(&test_sem);
        }
        void writeTxCred (uint32_t cred) {
            fprintf(stderr, "Received Cred %d\n", cred);
        }
        void writeRxCred (uint32_t cred) {
            fprintf(stderr, "Received Cred %d\n", cred);
        }
        SonicTopIndication(unsigned int id) : SonicTopIndicationWrapper(id){}
};

#define SRC_MAC "77:22:33:11:ad:ad"
#define DST_MAC "11:22:33:44:55:66"
#define SRC_IP  "192.168.2.1"
#define DST_IP  "192.168.0.1"
#define SRC_TCP 15
#define DST_TCP 13
#define PAYLOAD "I'm a payload! Test sending one packet."

int check_packet(EthernetII orig, EthernetII t) {
    assert (t.dst_addr() == orig.dst_addr());
    assert (t.src_addr() == orig.src_addr());

    const IP &ip_orig = orig.rfind_pdu<IP>();
    const IP &ip_t = t.rfind_pdu<IP>();
    assert (ip_t.dst_addr() == ip_orig.dst_addr());
    assert (ip_t.src_addr() == ip_orig.src_addr());

    const TCP &tcp_orig = orig.rfind_pdu<TCP>();
    const TCP &tcp_t = t.rfind_pdu<TCP>();
    assert (tcp_t.dport() == tcp_orig.dport());
    assert (tcp_t.sport() == tcp_orig.sport());

    return 0;
}

int main(int argc, const char **argv)
{
    if (sem_init(&test_sem, 1, 0)) {
        fprintf(stderr, "error: failed to init test_sem\n");
        exit(1);
    }
    fprintf(stderr, "testmemwrite: start %s %s\n", __DATE__, __TIME__);
    DmaManager *dma = platformInit();
    device = new SonicTopRequestProxy(IfcNames_SonicTopRequestS2H);
    SonicTopIndication deviceIndication(IfcNames_SonicTopIndicationH2S);

    fprintf(stderr, "main::allocating memory...\n");
    int dstAlloc = portalAlloc(alloc_sz, 0);
    unsigned int *dstBuffer = (unsigned int *)portalMmap(dstAlloc, alloc_sz);
    unsigned int ref_dstAlloc = dma->reference(dstAlloc);

    // construct packet
    int packet_size;
    int i;
    int numBeats;
    EthernetII eth = EthernetII(DST_MAC, SRC_MAC) /
                     IP(DST_IP, SRC_IP) /
                     TCP(DST_TCP, SRC_TCP) /
                     RawPDU(PAYLOAD);

    PDU::serialization_type buff = eth.serialize();
    packet_size = buff.size();
    numBeats = packet_size / 16; // 16 bytes per beat for 128-bit datawidth;
    if (packet_size % 16 != 0) numBeats++;
    fprintf(stderr, "nBeats=%d\n", numBeats);

    // transfer packet to receive
    uint64_t *data_hi, *data_lo;
    for (i=0; i<numBeats*2; i+=2) {
        data_hi = 0;
        data_lo = 0;

        data_lo = (uint64_t *)(&buff[0]) + i;
        data_hi = (uint64_t *)(&buff[0]) + i + 1;

        if (i==0) {
            device->writePacketData(*data_hi, *data_lo, 1, 0);
        } else if (i==(numBeats-1)*2) {
            device->writePacketData(*data_hi, *data_lo, 0, 1);
        } else {
            device->writePacketData(*data_hi, *data_lo, 0, 0);
        }

        fprintf(stderr, "%p %016lx %p %016lx \n", data_hi, *data_hi, data_lo, *data_lo);
    }

    // transfer descriptor
    for (int i = 0; i < numWords; i++)
        dstBuffer[i] = 0xDEADBEEF;
    portalCacheFlush(dstAlloc, dstBuffer, alloc_sz, 1);
    fprintf(stderr, "testmemwrite: flush and invalidate complete\n");
    fprintf(stderr, "testmemwrite: starting write %08x\n", numWords);
    portalTimerStart(0);
    device->startWrite(ref_dstAlloc, 0, numWords*4, burstLen*4, iterCnt);

    sem_wait(&test_sem);

    // check packet
    const EthernetII eth2 = EthernetII((unsigned char*)(&dstBuffer[0]), buff.size());
    if (check_packet(eth, eth2)) {
        fprintf(stderr, "Test failed\n");
        return 1;
    }
    const TCP& tcp = eth2.rfind_pdu<TCP>();
    const RawPDU& raw = tcp.rfind_pdu<RawPDU>();
    const RawPDU::payload_type &payload = raw.payload();
    std::string message(payload.begin(), payload.end());
    fprintf(stderr, "%s\n", message.c_str());
    fprintf(stderr, "Test passed\n");
    return 0;
}
