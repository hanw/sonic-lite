/**
 * @file dpdk.cpp
 * @author Han Wang
 * @brief Connectal API for Intel DPDK
 */

#include "GeneratedTypes.h"
#include "MMURequest.h"
#include "MMUIndication.h"
#include "MemServerRequest.h"
#include "MemServerIndication.h"
#include "dmaManager.h"

#include "SonicUserRequest.h"
#include "SonicUserIndication.h"

#define PLATFORM_TILE 0
#define PAGE_SHIFT0 12
#define PAGE_SHIFT4 16
#define PAGE_SHIFT8 20
static int shifts[] = {PAGE_SHIFT8, PAGE_SHIFT4, PAGE_SHIFT0, 0};

static DmaManager *dma = 0;
static SonicUserRequestProxy *device = 0;
static int trace_memory = 1;

/**
 * @brief
 */
int _send_fd_to_portal(PortalInternal *device, int fd, int id, int pa_fd)
{
    int rc = 0;
    int i, j;
    uint32_t regions[3] = {0,0,0};
    uint64_t border = 0;
    unsigned char entryCount = 0;
    uint64_t borderVal[3];
    uint32_t indexVal[3];
    unsigned char idxOffset;
    int size_accum = 0;
    rc = id;
    unsigned entries=4;
    for(i = 0; 1; i++){
        long len, addr;
        len=0x10000; //Each page is 1MB.
        if (!entries)
            break;
        entries -= 1;
        if (!len)
            break;
        addr = size_accum;
        size_accum += len;
        addr |= ((long)id) << 32; //[39:32] = truncate(pref);

        for(j = 0; j < 3; j++)
            if (len == 1<<shifts[j]) {
                regions[j]++;
                if (addr & ((1L<<shifts[j]) - 1))
                    PORTAL_PRINTF("%s: addr %lx shift %x *********\n", __FUNCTION__, addr, shifts[j]);
                addr >>= shifts[j];
                break;
            }
        if (j >= 3)
            PORTAL_PRINTF("DmaManager:unsupported sglist size %lx\n", len);
        if (trace_memory)
            PORTAL_PRINTF("DmaManager:sglist(id=%08x, i=%d dma_addr=%08lx, len=%08lx)\n", id, i, (long)addr, len);
        MMURequest_sglist(device, id, i, addr, len);
    } // balance }

    // HW interprets zeros as end of sglist
    if (trace_memory)
        PORTAL_PRINTF("DmaManager:sglist(id=%08x, i=%d end of list)\n", id, i);
    MMURequest_sglist(device, id, i, 0, 0); // end list

    for(i = 0; i < 3; i++){
        idxOffset = entryCount - border;
        entryCount += regions[i];
        border += regions[i];
        borderVal[i] = border;
        indexVal[i] = idxOffset;
        border <<= (shifts[i] - shifts[i+1]);
    }

    if (trace_memory) {
        PORTAL_PRINTF("regions %d (%x %x %x)\n", id,regions[0], regions[1], regions[2]);
        PORTAL_PRINTF("borders %d (%"PRIx64" %"PRIx64" %"PRIx64")\n", id,borderVal[0], borderVal[1], borderVal[2]);
    }
    MMURequest_region(device, id, borderVal[0], indexVal[0], borderVal[1], indexVal[1], borderVal[2], indexVal[2]);
    PORTAL_PRINTF("[%s:%d]\n", __FUNCTION__, __LINE__);
    /* ifdefs here to supress warning during kernel build */
    return rc;
}

/**
 * @brief dma reference
 */
int dma_reference (DmaManagerPrivate* priv, int fd) {
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
    PORTAL_PRINTF("[%s:%d] id=%d, fd=%d, pa_fd=%d\n", __FUNCTION__, __LINE__, id, fd, global_pa_fd);
    rc = _send_fd_to_portal(priv->sglDevice, fd, id, global_pa_fd);
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
	dma = platformInit();
    //hostMemServerIndication = new MemServerIndication(hostMemServerRequest, IfcNames_MemServerIndicationH2S, PLATFORM_TILE);
    //mmuIndication = new MMUIndication(dma, IfcNames_MMUIndicationH2S, PLATFORM_TILE);
    device = new SonicUserRequestProxy(IfcNames_SonicUserRequestS2H);
    printf("[%s:%d]: dma %p device %p\n", __func__, __LINE__, dma, device);

    DmaManagerPrivate *priv = &dma->priv;
    dma_reference(priv, fd);
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

} //extern "C"

/*
 * @brief main() unused
 */
int main(int argc, char **argv) { return 0; }
