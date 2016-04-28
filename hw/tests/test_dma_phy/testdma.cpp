/* Copyright (c) 2015 Connectal Project
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
#include <sys/mman.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include <semaphore.h>
#include "TestRequest.h"
#include "TestIndication.h"

#include "dmac.h"

#ifdef SIMULATION
int arraySize = 1024;
#else
int arraySize = 1024;
#endif
int numchannels = 1;
int numIters = 1;
int writeReqBytes = 256;
int readReqBytes = 256;

class TestTop : public TestIndicationWrapper
{
    public:
    virtual void read_version_resp(uint32_t a) {
        fprintf(stderr, "read version %d\n", a);
    }
    virtual void read_txpktbuf_debug_resp(uint8_t p, uint64_t a, uint64_t b, uint64_t c, uint64_t d) {
        fprintf(stderr, "Port %d: sop_enq: %ld sop_deq: %ld eop_enq: %ld eop_deq: %ld\n", p, a, b, c, d);
    }
    virtual void read_rxpktbuf_debug_resp(uint8_t p, uint64_t a, uint64_t b, uint64_t c, uint64_t d) {
        fprintf(stderr, "Port %d: sop_enq: %ld sop_deq: %ld eop_enq: %ld eop_deq: %ld\n", p, a, b, c, d);
    }
    virtual void read_ring2mac_debug_resp(uint8_t p, uint64_t a, uint64_t b, uint64_t c, uint64_t d, uint64_t e) {
        fprintf(stderr, "Ring2Mac %d: bytes: %ld sop: %ld eop: %ld idles: %ld total: %ld\n", p, a, b, c, d, e);
    }
    virtual void read_mac2ring_debug_resp(uint8_t p, uint64_t a, uint64_t b, uint64_t c, uint64_t d, uint64_t e) {
        fprintf(stderr, "Mac2Ring %d: bytes: %ld sop: %ld eop: %ld idles: %ld total: %ld\n", p, a, b, c, d, e);
    }

    TestTop(unsigned int id) : TestIndicationWrapper(id) {}
};
static TestRequestProxy *device = 0;

class ChannelWorker : public DmaCallback {
    DmaChannel *channel;
    int channelNumber;
    int numReads;
    int numWrites;
    int waitCount;
    DmaBuffer *buffers[4];
    static void *threadfn(void *c);
    void run();

    static volatile int started;
    static pthread_t *threads;

    public:
    ChannelWorker(int channelNumber)
    : channelNumber(channelNumber), numReads(0), numWrites(0), waitCount(0) {

        channel = new DmaChannel(channelNumber, this);

        fprintf(stderr, "[%s:%d] channel %d allocating buffers\n", __FUNCTION__, __LINE__, channelNumber);
        for (int i = 0; i < 4; i++) {
            buffers[i] = new DmaBuffer(4096);
            //memset(buffers[i]->buffer(), 0xba, arraySize);

            char * p = buffers[i]->buffer();
            for ( int j = 0 ; j < arraySize ; j ++) 
                p[j] = (char) j;

            channel->setObjTransferFromFpga(i, buffers[i]->reference());
        }
    }

    double linkUtilization(int32_t cycles, int inclHeaders = 0) {
        double dataBeats = (double)arraySize/16;
        int headerBeats = 0;
        if (inclHeaders) {
            headerBeats = arraySize / writeReqBytes;
        }
        double totalBeats = dataBeats + headerBeats;
        return totalBeats / (double)(-cycles);
    }

    void transferToFpgaDone (const uint8_t tag) {
        numReads--;
        if (numReads) {
            fprintf(stderr, "[%s:%d] channel %d requesting dma transferToFpga size=%d\n", __FUNCTION__, __LINE__, channelNumber, arraySize);
            //	    int tag = 0;
            channel->transferToFpga(buffers[1], 0, arraySize, channelNumber);
        } 
    }
    void transferFromFpgaDone ( uint32_t sglId, uint32_t len ) {
        if (0)
            for (int i = 0; i < 4; i++) {
                if (buffers[i]->reference() == sglId) {
                    for (int j = 0; j < 8; j++) {
                    fprintf(stderr, "%d: %016lx\n", j, *(uint64_t *)(buffers[i]->buffer() + j*8));
                    }
                }
            }

        if (numWrites) {
            fprintf(stderr, "[%s:%d] channel %d requesting dma transferFromFpga size=%d\n", __FUNCTION__, __LINE__, channelNumber, arraySize);
            numWrites--;
        } 
    }
    static void runTest();
};

void *ChannelWorker::threadfn(void *c)
{
    ChannelWorker *worker = (ChannelWorker *)c;
    while (!started) {
        // wait for other threads to be ready
    }
    worker->run();
    return 0;
}

void ChannelWorker::run()
{
    channel->setWriteRequestSize(writeReqBytes);
    channel->setReadRequestSize(readReqBytes);
    
    numReads = numWrites = numIters;

    if (numReads) {
        fprintf(stderr, "[%s:%d] channel %d requesting dma read size=%d\n", __FUNCTION__, __LINE__, channelNumber, arraySize);
//	    int tag = 0;
        channel->transferToFpga(buffers[1], 0, arraySize, channelNumber);
        waitCount++;
    }

    while (numReads > 0 && numWrites > 0) {
        channel->checkIndications();
    }
}

volatile int ChannelWorker::started = 0;
pthread_t *ChannelWorker::threads = 0;

void ChannelWorker::runTest()
{
    started = 0;
    threads = new pthread_t[numchannels];
    for (int i = 0; i < numchannels; i++) {
        ChannelWorker * worker = new ChannelWorker(i);
        pthread_create(&threads[i], 0, worker->threadfn, worker);
    }
    started = 1;

    // wait for threads to exit
    for (int i = 0; i < numchannels; i++) {
        void *ret;
        pthread_join(threads[i], &ret);
        fprintf(stderr, "thread exited ret=%p\n", ret);
    }
}

int main(int argc, char * const*argv)
{
    int opt;
    while ((opt = getopt(argc, argv, "R:W:i:s:n:")) != -1) {
        switch (opt) {
        case 'W':
            writeReqBytes = strtoul(optarg, 0, 0);
            if (writeReqBytes > 1024)
              writeReqBytes = 1024;
            break;
        case 'R':
            readReqBytes = strtoul(optarg, 0, 0);
            if (readReqBytes > 1024)
              readReqBytes = 1024;
            break;
        case 'i':
            numIters = strtoul(optarg, 0, 0);
            break;
        case 's': {
            char *endptr = 0;
            arraySize = strtoul(optarg, &endptr, 0);
            if (endptr) {
                switch (*endptr) {
                case 'K':
                    arraySize *= 1024;
                    break;
                case 'M':
                    arraySize *= 1024*1024;
                    break;
                default:
                    break;
                }
            }
        } break;
        case 'n':
            numchannels = strtoul(optarg, 0, 0);
            break;
        default:
            fprintf(stderr,
                "Usage: %s [-r] [-w] [-s transferSize]\n"
                "       -r read only\n"
                "       -r write only\n",
                argv[0]);
            exit(EXIT_FAILURE);
        }
    }
    TestTop indication (IfcNames_TestIndicationH2S);
    device = new TestRequestProxy(IfcNames_TestRequestS2H);

    ChannelWorker::runTest();
   
    while(1) {
        device->read_txpktbuf_debug(0);
        device->read_rxpktbuf_debug(0);
        device->read_ring2mac_debug(0);
        device->read_mac2ring_debug(0);
        sleep(2);
        fprintf(stderr, "\n");
    }

    return 0;
}
