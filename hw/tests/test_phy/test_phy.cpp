#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include <fstream>
#include <sstream>
#include <iostream>

#include "StdDmaIndication.h"
#include "MemServerRequest.h"
#include "MMURequest.h"
#include "PhyTestRequest.h"
#include "PhyTestIndication.h"

sem_t test_sem;

int burstLen = 128;
int numEntries = 0x16000/32;
size_t entry_size = sizeof(unsigned long int) * 4; //32 Bytes
size_t test_sz = numEntries*entry_size;
size_t alloc_sz = test_sz;

class PhyTestIndication : public PhyTestIndicationWrapper {
public:
  unsigned int rDataCnt;
  virtual void phyTestDone(uint32_t v){
    printf( "PhyTest::phyTestDone(mismatch = %x)\n", v);
    sem_post(&test_sem);
  }
  PhyTestIndication(int id) : PhyTestIndicationWrapper(id){}
};

int main(int argc, char **argv) {
    PhyTestRequestProxy *device = new PhyTestRequestProxy(IfcNames_PhyTestRequest);
    PhyTestIndication *deviceIndication = new PhyTestIndication(IfcNames_PhyTestIndication);
    MemServerRequestProxy *hostMemServerRequest = new MemServerRequestProxy(IfcNames_HostMemServerRequest);
    MMURequestProxy *dmap = new MMURequestProxy(IfcNames_HostMMURequest);
    DmaManager *dma = new DmaManager(dmap);
    MemServerIndication *hostMemServerIndication = new MemServerIndication(hostMemServerRequest, IfcNames_HostMemServerIndication);
    MMUIndication *hostMMUIndication = new MMUIndication(dma, IfcNames_HostMMUIndication);

    // column 1, 2 = xgmii data[63:0] [63:0]
    // column 3, 4 = scrambled data [65:64] [63:0]
//    const std::string path="../data/list.hex";
    const std::string path="../data/xgmii.data";
    std::ifstream traceinfo(path.c_str());
    std::string line;

    int srcAlloc;
    srcAlloc = portalAlloc(alloc_sz);
    unsigned long int *srcBuffer = (unsigned long int *)portalMmap(srcAlloc, alloc_sz);

    portalExec_start();

    for (int i = 0; i < numEntries; /*NONE*/ ) {
        // read one line from xgmii, put to higher 128 bits.
        std::getline(traceinfo, line);
        std::istringstream iss(line);
        std::string first_64;
        iss >> first_64;
        std::string second_64;
        iss >> second_64;
//        std::string third_64;
//        iss >> third_64;
//        std::string fourth_64;
//        iss >> third_64;
//        srcBuffer[i++] = strtoul(fourth_64.c_str(), NULL, 16);
//        srcBuffer[i++] = strtoul(third_64.c_str(), NULL, 16);
        srcBuffer[i++] = strtoul("", NULL, 16);
        srcBuffer[i++] = strtoul("", NULL, 16);
        srcBuffer[i++] = strtoul(second_64.c_str(), NULL, 16); /*second_64 is LSB*/
        srcBuffer[i++] = strtoul(first_64.c_str(), NULL, 16);
        //std::cout<< line << std::endl;
    }

    portalDCacheFlushInval(srcAlloc, alloc_sz, srcBuffer);
    unsigned int ref_srcAlloc = dma->reference(srcAlloc);
    printf( "Main::starting read %08x\n", numEntries);
    device->startPhy(ref_srcAlloc, numEntries, burstLen, 1);
    sem_wait(&test_sem);
    return 0;
}
