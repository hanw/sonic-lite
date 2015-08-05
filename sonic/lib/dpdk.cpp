/**
 * @file dpdk.cpp
 * @author Han Wang
 * @brief Connectal API for Intel DPDK
 */
#include <sys/mman.h>
#include <assert.h>

#include "dmaManager.h"
#include "GeneratedTypes.h" //ChannelType!!
#include "SonicUserRequest.h"
#include "SonicUserIndication.h"

#define SONIC_TX_CREDIT 128

static int trace_memory = 1;
static pthread_mutex_t mutex;
static int tx_credit = SONIC_TX_CREDIT;
static int rx_credit = 0;

class SonicUserIndication : public SonicUserIndicationWrapper
{
    public:
        void sonic_read_version_resp(uint32_t a) {
            fprintf(stderr, "read version %d\n", a);
        }
        void readDone(uint32_t a) {
            fprintf(stderr, "SonicUser::readDone(%x)\n", a);
        }
        void started(uint32_t words) {
            fprintf(stderr, "Memwrite::started: words=%x\n", words);
        }
        void writeDone ( uint32_t srcGen ) {
            fprintf(stderr, "Memwrite::writeDone (%08x)\n", srcGen);
        }
        void reportStateDbg(uint32_t streamWrCnt, uint32_t srcGen) {
            fprintf(stderr, "Memwrite::reportStateDbg: streamWrCnt=%08x srcGen=%d\n", streamWrCnt, srcGen);
        }
        void writeTxCred (uint32_t cred) {
            fprintf(stderr, "Received Cred %d\n", cred);
            pthread_mutex_lock(&mutex);
            tx_credit += cred;
            pthread_mutex_unlock(&mutex);
        }
        void writeRxCred (uint32_t cred) {
            pthread_mutex_lock(&mutex);
            rx_credit -= cred;
            pthread_mutex_unlock(&mutex);
        }
        SonicUserIndication(unsigned int id) : SonicUserIndicationWrapper(id){}
};

#define PLATFORM_TILE 0
#define PAGE_SHIFT0 12
#define PAGE_SHIFT4 16
#define PAGE_SHIFT8 20
#define PAGE_SHIFT12 24
static int shifts[] = {PAGE_SHIFT12, PAGE_SHIFT8, PAGE_SHIFT4, PAGE_SHIFT0, 0};

class SonicDpdkManager {
    public:
        SonicDpdkManager();
        ~SonicDpdkManager();

        void init (int fd, uint64_t phys_addr, uint32_t len);
        void tx_send_pa(uint64_t pkt_base, uint32_t len);
        void rx_send_pa(uint64_t pkt_base, uint32_t len);
        uint32_t get_tx_credit();
        void read_version();
    private:
        DmaManager *dma;
        SonicUserRequestProxy *device;
        SonicUserIndication *indication;
        int mmu_sglId;
        uint64_t phys_base;

        int dma_reference (DmaManagerPrivate* priv, int fd, size_t sz);
        int send_fd_to_portal(PortalInternal *device, int fd, int id, size_t sz);
};

SonicDpdkManager::SonicDpdkManager () {
    dma = platformInit();
    device = new SonicUserRequestProxy(IfcNames_SonicUserRequestS2H);
    indication = new SonicUserIndication(IfcNames_SonicUserIndicationH2S);
}

SonicDpdkManager::~SonicDpdkManager() {
    // Nothing here.
}

void
SonicDpdkManager::init (int fd, uint64_t phys_addr, uint32_t len) {
    DmaManagerPrivate *priv = &dma->priv;
    mmu_sglId = dma_reference(priv, fd, len);
    phys_base = phys_addr;
    pthread_mutex_init(&mutex, NULL);
    PORTAL_PRINTF("[%s:%d] mmu sglId=%d at phys_addr 0x%lx with len=0x%lx\n", __FUNCTION__, __LINE__, mmu_sglId, phys_base, len);
}

uint32_t SonicDpdkManager::get_tx_credit() {
    return tx_credit;
}

void
SonicDpdkManager::read_version() {
    assert(device != NULL);
    device->sonic_read_version();
}

void
SonicDpdkManager::tx_send_pa(uint64_t pkt_base, uint32_t len) {
    uint32_t offset = pkt_base - phys_base;
    device->startRead(mmu_sglId, offset, len*4, 32*4);
}

void
SonicDpdkManager::rx_send_pa(uint64_t pkt_base, uint32_t len) {
    uint32_t offset = pkt_base - phys_base;
    device->startWrite(mmu_sglId, offset, len*4, 32*4, 1);
}

int
SonicDpdkManager::dma_reference(DmaManagerPrivate* priv, int fd, size_t sz) {
    int id = 0;
    int rc = 0;
    MMURequest_idRequest(priv->sglDevice, (SpecialTypeForSendingFd)fd);
    sem_wait(&priv->sglIdSem);
    id = priv->sglId;
    rc = send_fd_to_portal(priv->sglDevice, fd, id, sz);
    if (rc <= 0) {
        sem_wait(&priv->confSem);
    }
    PORTAL_PRINTF("[%s:%d] rc=%d\n", __FUNCTION__, __LINE__, rc);
    return rc;
}

int
SonicDpdkManager::send_fd_to_portal(PortalInternal *device, int fd,
                                    int id, size_t sz) {
    int rc = 0;
    int i, j;
    uint32_t regions[4] = {0,0,0,0};
    uint64_t border = 0;
    unsigned char entryCount = 0;
    uint64_t borderVal[4];
    uint32_t indexVal[4];
    unsigned char idxOffset;
    int size_accum = 0;
    rc = id;
    long len = 1 << PAGE_SHIFT12; // 16MB pages
    unsigned entries = sz >> PAGE_SHIFT12;

    for(i = 0; 1; i++){
        long addr;
        if (!entries)
            break;
        if (!len)
            break;
        addr = size_accum;
        size_accum += len;
        addr |= ((long)id) << 32; //[39:32] = truncate(pref);

        for(j = 0; j < 4; j++)
            if (len == 1<<shifts[j]) {
                regions[j]++;
                if (addr & ((1L<<shifts[j]) - 1))
                    PORTAL_PRINTF("%s: addr %lx shift %x *********\n", __FUNCTION__, addr, shifts[j]);
                addr >>= shifts[j];
                break;
            }
        if (j >= 4)
            PORTAL_PRINTF("DmaManager:unsupported sglist size %lx\n", len);
        if (trace_memory)
            PORTAL_PRINTF("DmaManager:sglist(id=%08x, i=%d dma_addr=%08lx, len=%08lx)\n", id, i, (long)addr, len);
        MMURequest_sglist(device, id, i, addr, len);
        entries--;
    }

    if (trace_memory)
        PORTAL_PRINTF("DmaManager:sglist(id=%08x, i=%d end of list)\n", id, i);
    MMURequest_sglist(device, id, i, 0, 0); // end list

    for(i = 0; i < 4; i++){
        idxOffset = entryCount - border;
        entryCount += regions[i];
        border += regions[i];
        borderVal[i] = border;
        indexVal[i] = idxOffset;
        border <<= (shifts[i] - shifts[i+1]);
    }

    if (trace_memory) {
        PORTAL_PRINTF("regions %d (%x %x %x %x)\n", id, regions[0], regions[1], regions[2], regions[3]);
        PORTAL_PRINTF("borders %d (%"PRIx64" %"PRIx64" %"PRIx64" %"PRIx64")\n", id, borderVal[0], borderVal[1], borderVal[2], borderVal[3]);
    }
    MMURequest_region(device, id, borderVal[0], indexVal[0], borderVal[1], indexVal[1], borderVal[2], indexVal[2], borderVal[3], indexVal[3]);
    /* ifdefs here to supress warning during kernel build */
    return rc;
} // send_fd_to_portal

extern "C" {

SonicDpdkManager& theDpdk() {
    static SonicDpdkManager dpdk;
    return dpdk;
}

void init (uint32_t fd, uint64_t phys_addr, uint32_t len) {
    theDpdk().init(fd, phys_addr, len);
}

void start_default_poller() {
    defaultPoller->start();
}

void stop_default_poller() {
    defaultPoller->stop();
}

void poll(void) {
    defaultPoller->event();
}

void tx_send_pa(uint64_t base, uint32_t len) {
    theDpdk().tx_send_pa(base, len);
}

void rx_send_pa(uint32_t id, uint64_t base, uint32_t len) {
    theDpdk().rx_send_pa(base, len);
}

void read_version(void) {
    theDpdk().read_version();
}

uint32_t tx_credit_available(void) {
    return tx_credit;
}

void tx_credit_decrement(uint32_t v) {
    pthread_mutex_lock(&mutex);
    tx_credit -= v;
    pthread_mutex_unlock(&mutex);
}

uint32_t rx_credit_available(void) {
    return rx_credit;
}

void rx_credit_increment(uint32_t v) {
    pthread_mutex_lock(&mutex);
    rx_credit += v;
    pthread_mutex_unlock(&mutex);
}

} //extern "C"

/*
 * @brief main() unused
 */
int main(int argc, char **argv) { return 0; }
