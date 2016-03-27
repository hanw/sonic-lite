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

#include "dmac.h"

#ifdef SIMULATION
int arraySize = 4*1024;
#else
int arraySize = 128*1024;
#endif
int doWrite = 1;
int doRead = 1;
int numchannels = 4;
int numIters = 10;
int writeReqBytes = 256;
int readReqBytes = 256;

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
	    buffers[i] = new DmaBuffer(arraySize);
	    memset(buffers[i]->buffer(), 0xba, arraySize);
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
    void transferToFpgaDone ( uint32_t sglId, uint32_t base, const uint8_t tag, uint32_t cycles ) {
	fprintf(stderr, "[%s:%d] sglId=%d base=%08x tag=%d readReqBytes=%d cycles=%d transferToFpga bandwidth %5.2f MB/s link utilization %5.2f%%\n",
		__FUNCTION__, __LINE__, sglId, base, tag, readReqBytes, cycles, 16*250*linkUtilization(cycles), 100.0*linkUtilization(cycles, 1));
	if (numReads) {
	    fprintf(stderr, "[%s:%d] channel %d requesting dma transferToFpga size=%d\n", __FUNCTION__, __LINE__, channelNumber, arraySize);
//	    int tag = 0;
	    channel->transferToFpga(buffers[0]->reference(), 0, arraySize, channelNumber);
	    numReads--;
	} else {
	    waitCount--;
	    fprintf(stderr, "[%s:%d] channel %d waiting for %d responses\n", __FUNCTION__, __LINE__, channelNumber, waitCount);
	}
    }
    void transferFromFpgaDone ( uint32_t sglId, uint32_t base, uint8_t tag, uint32_t cycles ) {
	fprintf(stderr, "[%s:%d] sglId=%d base=%08x tag=%d writeReqBytes=%d cycles=%d transferFromFpga bandwidth %5.2f MB/s link utilization %5.2f%%\n",
		__FUNCTION__, __LINE__, sglId, base, tag, writeReqBytes, cycles, 16*250*linkUtilization(cycles), 100.0*linkUtilization(cycles, 1));
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
//	    int tag = 1;
	    channel->transferFromFpga(buffers[1]->reference(), 0, arraySize, channelNumber);
	    numWrites--;
	} else {
	    waitCount--;
	    fprintf(stderr, "[%s:%d] channel %d waiting for %d responses\n", __FUNCTION__, __LINE__, channelNumber, waitCount);
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
    for (int i = 0; i < 2; i++) {
	if (i == 0 && doRead) {
	    numReads = numIters;
	    numWrites = 0;
	} else if (i==1 && doWrite){
	    numReads = 0;
	    numWrites = numIters;
	} else {
        numReads = 0;
        numWrites = 0;
    }
	if (numReads) {
	    fprintf(stderr, "[%s:%d] channel %d requesting dma read size=%d\n", __FUNCTION__, __LINE__, channelNumber, arraySize);
//	    int tag = 0;
	    channel->transferToFpga(buffers[0]->reference(), 0, arraySize, channelNumber);
	    waitCount++;
	    numReads--;
	}

	if (numWrites) {
	    fprintf(stderr, "[%s:%d] channel %d requesting dma transferFromFpga size=%d\n", __FUNCTION__, __LINE__, channelNumber, arraySize);
//	    int tag = 1;
	    channel->transferFromFpga(buffers[1]->reference(), 0, arraySize, channelNumber);
	    waitCount++;
	    numWrites--;
	}
	fprintf(stderr, "[%s:%d] channel %d waiting for responses\n", __FUNCTION__, __LINE__, channelNumber);
	while (waitCount > 0) {
	    channel->checkIndications();
        usleep(100);
	}
	waitCount = 0;
    }
}

volatile int ChannelWorker::started = 0;
pthread_t *ChannelWorker::threads = 0;

void ChannelWorker::runTest()
{
    started = 0;
    threads = new pthread_t[numchannels];
    for (int i = 0; i < numchannels; i++) {
	ChannelWorker *worker = new ChannelWorker(i);
	pthread_create(&threads[i], 0, worker->threadfn, worker);
    }
    started = 1;

    // let test run

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
    while ((opt = getopt(argc, argv, "b:R:W:i:rws:n:")) != -1) {
	switch (opt) {
	case 'r':
	    doWrite = 0;
	    break;
	case 'w':
	    doRead = 0;
	    break;
	case 'b':
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
    ChannelWorker::runTest();
    return 0;
}
