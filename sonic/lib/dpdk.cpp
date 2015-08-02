/**
 * @file dpdk.cpp
 * @author Han Wang
 * @brief Connectal API for Intel DPDK
 */
#include <sys/mman.h>
#include <assert.h>

#include "dmaManager.h"

#include "SonicUserRequest.h"
#include "SonicUserIndication.h"

#define PLATFORM_TILE 0
#define PAGE_SHIFT0 12
#define PAGE_SHIFT4 16
#define PAGE_SHIFT8 20
#define PAGE_SHIFT12 24
#define LENGTH (1024UL * 1024 * 1024)
static int shifts[] = {PAGE_SHIFT12, PAGE_SHIFT8, PAGE_SHIFT4, PAGE_SHIFT0, 0};

static sem_t test_sem;
static int mismatchCount = 0;
class SonicUserIndication : public SonicUserIndicationWrapper
{
	public:
		virtual void sonic_read_version_resp(uint32_t a) {
			fprintf(stderr, "read version %d\n", a);
		}
		virtual void readDone(uint32_t a) {
			fprintf(stderr, "SonicUser::readDone(%x)\n", a);
			mismatchCount += a;
			sem_post(&test_sem);
		}
		void started(uint32_t words) {
			fprintf(stderr, "Memwrite::started: words=%x\n", words);
		}
		void writeDone ( uint32_t srcGen ) {
			fprintf(stderr, "Memwrite::writeDone (%08x)\n", srcGen);
			sem_post(&test_sem);
		}
		void reportStateDbg(uint32_t streamWrCnt, uint32_t srcGen) {
			fprintf(stderr, "Memwrite::reportStateDbg: streamWrCnt=%08x srcGen=%d\n", streamWrCnt, srcGen);
		}
		SonicUserIndication(unsigned int id) : SonicUserIndicationWrapper(id){}
};

static DmaManager *dma = 0;
static SonicUserRequestProxy *device = 0;
static SonicUserIndication *indication = 0;
static int trace_memory = 1;

/**
 * @brief
 */
int snd_fd_to_portal(PortalInternal *device, int fd, int id, size_t sz)
{
    int rc = 0;
    int i, j;
    uint32_t regions[4] = {0, 0,0,0};
    uint64_t border = 0;
    unsigned char entryCount = 0;
    uint64_t borderVal[4];
    uint32_t indexVal[4];
    unsigned char idxOffset;
    int size_accum = 0;
    rc = id;
    long len = 1 << PAGE_SHIFT12; // 16MB pages
    unsigned entries = sz >> PAGE_SHIFT12;

    PORTAL_PRINTF("%s: nb_entries %d\n", __FUNCTION__, entries);
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
    } // balance }

    // HW interprets zeros as end of sglist
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
        PORTAL_PRINTF("regions %d (%x %x %x %x)\n", id,regions[0], regions[1], regions[2], regions[3]);
        PORTAL_PRINTF("borders %d (%"PRIx64" %"PRIx64" %"PRIx64" %"PRIx64")\n", id,borderVal[0], borderVal[1], borderVal[2], borderVal[3], indexVal[3]);
    }
    MMURequest_region(device, id, borderVal[0], indexVal[0], borderVal[1], indexVal[1], borderVal[2], indexVal[2], borderVal[3], indexVal[3]);
    PORTAL_PRINTF("[%s:%d]\n", __FUNCTION__, __LINE__);
    /* ifdefs here to supress warning during kernel build */
    return rc;
}

/**
 * @brief dma reference
 */
int dma_reference (DmaManagerPrivate* priv, int fd, size_t sz) {
    int id = 0;
    int rc = 0;
    PORTAL_PRINTF("[%s:%d] fd=%d\n", __FUNCTION__, __LINE__, fd);
    MMURequest_idRequest(priv->sglDevice, (SpecialTypeForSendingFd)fd);
    printf("[%s:%d] polling function %p\n", __FUNCTION__, __LINE__, priv->poll);
    if (priv->poll) {
        int rc = priv->poll(priv->shared_mmu_indication, &priv->sglId);
        printf("[%s:%d] return after idrequest %d %d\n", __FUNCTION__, __LINE__, rc, priv->sglId);
    }
    else {
        PORTAL_PRINTF("[%s:%d] sem_wait on first id request\n", __FUNCTION__, __LINE__);
        sem_wait(&priv->sglIdSem);
    }
    id = priv->sglId;
    PORTAL_PRINTF("[%s:%d] id=%d, fd=%d\n", __FUNCTION__, __LINE__, id, fd);
    rc = snd_fd_to_portal(priv->sglDevice, fd, id, sz);
    if (rc <= 0) {
        PORTAL_PRINTF("%s:%d sem_wait\n", __FUNCTION__, __LINE__);
        if (priv->poll) {
            uint32_t ret;
            int rc = priv->poll(priv->shared_mmu_indication, &ret);
            printf("[%s:%d] return after sendfd %d %d\n", __FUNCTION__, __LINE__, rc, ret);
        }
        else
            sem_wait(&priv->confSem);
    }
    return rc;
}

extern "C" {

/**
 * @brief create handle to access connectal device
 *
 * This function instantiates a DMA Manager* to access Connectal DMA engine. It
 * returns
 *
 */

void dma_init (uint32_t fd) {
    // Only create on dma instance
    if (!dma) {
    PORTAL_PRINTF("[%s:%d] platformInit\n", __FUNCTION__, __LINE__);
	dma = platformInit();
    PORTAL_PRINTF("[%s:%d] platformInit finished\n", __FUNCTION__, __LINE__);
    device = new SonicUserRequestProxy(IfcNames_SonicUserRequestS2H);
	//SonicUserIndication memReadIndication(IfcNames_SonicUserIndicationH2S);
    indication = new SonicUserIndication(IfcNames_SonicUserIndicationH2S);
    printf("[%s:%d]: dma %p device %p\n", __func__, __LINE__, dma, device);

    //write_shared_data(fd, offset);
    DmaManagerPrivate *priv = &dma->priv;
    dma_reference(priv, fd, LENGTH);
    PORTAL_PRINTF("[%s:%d] dma_init finished\n", __FUNCTION__, __LINE__);
    }
}

/**
 * @brief Used by Tx to send PA(physical address) of a tx_buff to hardware
 */
void tx_send_pa(uint64_t base, uint32_t len) {
    printf("[%s:%d], do dma read.\n", __func__, __LINE__);
    // start read
}

/**
 * @brief Used by Rx to send PA(physical address) of a free rx_buff to hardware
 */
void rx_send_pa(uint64_t base, uint32_t len) {

}

/**
 * @brief sonic_read_version
 */
void read_version(void) {
    fprintf(stderr, "[%s:%d] read version.\n", __func__, __LINE__);
    assert(device != NULL);
    device->sonic_read_version();
}

} //extern "C"

/*
 * @brief main() unused
 */
int main(int argc, char **argv) { return 0; }
