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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fstream>
#include <sstream>
#include <iostream>
#include <sys/mman.h>

#include "MemServerRequest.h"
#include "TestRequest.h"
#include "TestIndication.h"
#include "GeneratedTypes.h"
#include "utils.h"
#include "sonic_pcap_utils.h"

#define DATA_WIDTH 128
#define ITERATION 1024

using namespace std;

sem_t test_sem;
static TestRequestProxy *device=0;

void mem_copy(const void *buff, int length);

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

    const std::string path="../../data/xgmii.data.scrambled";
    std::ifstream traceinfo(path.c_str());
    std::string line;
    uint64_t data[2];
    int sop, eop;

    for (int i = 0; i < ITERATION; i=i+2) {
        std::getline(traceinfo, line);
        std::istringstream sstream(line);
        std::string first_64;
        std::string second_64;
        sstream >> first_64;
        sstream >> second_64;
        data[1] = strtoul(first_64.c_str(), NULL, 16);
        data[0] = strtoul(second_64.c_str(), NULL, 16);
        sop = (i == 0) ? 1 : 0;
        eop = (i == ITERATION-2) ? 1 : 0;
        device->writePacketData(data, 0xff, sop, eop);
        PRINT_INFO("%016lx %016lx %d %d\n", data[1], data[0], sop, eop);
    }

    sem_wait(&test_sem);
    return 0;
}
