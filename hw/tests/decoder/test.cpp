#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include <fstream>
#include <sstream>
#include <iostream>

#include "MemServerRequest.h"
#include "TestRequest.h"
#include "TestIndication.h"
#include "GeneratedTypes.h"
#include "utils.h"
#include "sonic_pcap_utils.h"

#define ITERATION 1024

sem_t test_sem;
static TestRequestProxy *device=0;

class TestIndication : public TestIndicationWrapper {
public:
  virtual void done(uint32_t v){
      sem_post(&test_sem);
  }
  TestIndication(int id) : TestIndicationWrapper(id){}
};

void mem_copy(const void *buff, int packet_size) {
}

int main(int argc, char **argv) {
    TestIndication deviceIndication(IfcNames_TestIndicationH2S);
    device = new TestRequestProxy(IfcNames_TestRequestS2H);

    const std::string path="../../data/xgmii.data.encoded";
    std::ifstream traceinfo(path.c_str());
    std::string line;
    uint64_t data[2];
    int sop, eop;

    for (int i = 0; i < ITERATION; i=i+2 ) {
        std::getline(traceinfo, line);
        std::istringstream iss(line);
        std::string first_64;
        iss >> first_64;
        std::string second_64;
        iss >> second_64;
        data[1] = strtoul(first_64.c_str(), NULL, 16);
        data[0] = strtoul(second_64.c_str(), NULL, 16);
        sop = (i == 0) ? 1 : 0;
        eop = (i == ITERATION-2) ? 1 : 0;
        device->writePacketData(data, sop, eop);
        PRINT_INFO("%016lx %016lx %d %d\n", data[1], data[0], sop, eop);
    }

    sem_wait(&test_sem);
    return 0;
}
