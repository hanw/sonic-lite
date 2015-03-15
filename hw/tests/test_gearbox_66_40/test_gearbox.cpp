#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>

#include "StdDmaIndication.h"
#include "MemServerRequest.h"
#include "MMURequest.h"
#include "PmaTestRequest.h"
#include "PmaTestIndication.h"

sem_t test_sem;

int burstLen = 16;
int numWords = 0x200/4;
size_t test_sz = numWords*sizeof(unsigned int);
size_t alloc_sz = test_sz;

class PmaTestIndication : public PmaTestIndicationWrapper {
public:
  unsigned int rDataCnt;
  virtual void pmaTestDone(uint32_t v){
    printf( "PmaTest::pmaTestDone(mismatch = %x)\n", v);
    sem_post(&test_sem);
  }
  PmaTestIndication(int id) : PmaTestIndicationWrapper(id){}
};

int main(int argc, char **argv) {
    PmaTestRequestProxy *device = new PmaTestRequestProxy(IfcNames_PmaTestRequest);
    PmaTestIndication *deviceIndication = new PmaTestIndication(IfcNames_PmaTestIndication);
    MemServerRequestProxy *hostMemServerRequest = new MemServerRequestProxy(IfcNames_HostMemServerRequest);
    MMURequestProxy *dmap = new MMURequestProxy(IfcNames_HostMMURequest);
    DmaManager *dma = new DmaManager(dmap);
    MemServerIndication *hostMemServerIndication = new MemServerIndication(hostMemServerRequest, IfcNames_HostMemServerIndication);
    MMUIndication *hostMMUIndication = new MMUIndication(dma, IfcNames_HostMMUIndication);

    int srcAlloc;
    srcAlloc = portalAlloc(alloc_sz);
    unsigned int *srcBuffer = (unsigned int *)portalMmap(srcAlloc, alloc_sz);

    portalExec_start();

	int j = 0;
    for (int i = 0; i < numWords; i++) {
        srcBuffer[i] = j | (j+1) << 8 | (j+2) << 16 | (j+3) << 24;
		j += 4;
	}

    portalDCacheFlushInval(srcAlloc, alloc_sz, srcBuffer);
    unsigned int ref_srcAlloc = dma->reference(srcAlloc);
    printf( "Main::starting read %08x\n", numWords);
    device->startPma(ref_srcAlloc, numWords, burstLen, 1);
    sem_wait(&test_sem);
    return 0;
}
