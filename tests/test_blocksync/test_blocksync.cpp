#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fstream>
#include <sstream>
#include <iostream>
#include <sys/mman.h>

#include "StdDmaIndication.h"
#include "MemServerRequest.h"
#include "MMURequest.h"
#include "BlockSyncTestRequest.h"
#include "BlockSyncTestIndication.h"

sem_t test_sem;

int burstLen = 16;
int numWords = 0x1000/4;
size_t test_sz = numWords*sizeof(unsigned long int);
size_t alloc_sz = test_sz;

class BlockSyncTestIndication : public BlockSyncTestIndicationWrapper {
public:
  unsigned int rDataCnt;
  virtual void blockSyncTestDone(uint32_t v){
    printf( "BlockSyncTest::blockSyncTestDone(mismatch = %x)\n", v);
    sem_post(&test_sem);
  }
  BlockSyncTestIndication(int id) : BlockSyncTestIndicationWrapper(id){}
};

int main(int argc, char **argv) {
    BlockSyncTestRequestProxy *device = new BlockSyncTestRequestProxy(IfcNames_BlockSyncTestRequest);
    BlockSyncTestIndication *deviceIndication = new BlockSyncTestIndication(IfcNames_BlockSyncTestIndication);
    MemServerRequestProxy *hostMemServerRequest = new MemServerRequestProxy(IfcNames_HostMemServerRequest);
    MMURequestProxy *dmap = new MMURequestProxy(IfcNames_HostMMURequest);
    DmaManager *dma = new DmaManager(dmap);
    MemServerIndication *hostMemServerIndication = new MemServerIndication(hostMemServerRequest, IfcNames_HostMemServerIndication);
    MMUIndication *hostMMUIndication = new MMUIndication(dma, IfcNames_HostMMUIndication);

    const std::string path="../../data/xgmii.data.scrambled";
    std::ifstream traceinfo(path.c_str());
    std::string line;

    int srcAlloc;
    srcAlloc = portalAlloc(alloc_sz);
    unsigned long int *srcBuffer = (unsigned long int *)portalMmap(srcAlloc, alloc_sz);

    portalExec_start();

    for (int i = 0; i < numWords; /*NONE*/ ) {
        std::getline(traceinfo, line);
        std::istringstream iss(line);
        std::string first_64;
        iss >> first_64;
        std::string second_64;
        iss >> second_64;
        srcBuffer[i++] = strtoul(second_64.c_str(), NULL, 16); /*second_64 is LSB*/
        srcBuffer[i++] = strtoul(first_64.c_str(), NULL, 16);
    }

    portalDCacheFlushInval(srcAlloc, alloc_sz, srcBuffer);
    unsigned int ref_srcAlloc = dma->reference(srcAlloc);
    printf( "Main::starting read %08x\n", numWords);
    device->startBlockSync(ref_srcAlloc, numWords, burstLen, 1);
    sem_wait(&test_sem);
    return 0;
}
