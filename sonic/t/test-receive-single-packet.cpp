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
#include <assert.h>
#include <pthread.h>
#include <stdio.h>

#include "dmaManager.h"
#include "SonicTopRequest.h"
#include "SonicTopIndication.h"

int burstLen = 8;
int numWords = 0x4000/4; // make sure to allocate at least one entry of each size
int iterCnt = 1;
static SonicTopRequestProxy *device = 0;
static sem_t test_sem;
static size_t test_sz  = numWords*sizeof(unsigned int);
static size_t alloc_sz = test_sz;
static int mismatchCount = 0;

class SonicTopIndication : public SonicTopIndicationWrapper
{
    public:
        virtual void sonic_read_version_resp(uint32_t a) {
            fprintf(stderr, "read version %d\n", a);
        }
        virtual void readDone(uint32_t a) {
            fprintf(stderr, "SonicTop::readDone(%x)\n", a);
            mismatchCount += a;
            sem_post(&test_sem);
        }
        void writeDone ( uint32_t srcGen ) {
            fprintf(stderr, "Memwrite::writeDone (%08x)\n", srcGen);
            sem_post(&test_sem);
        }
        void writeTxCred (uint32_t cred) {
            fprintf(stderr, "Received Cred %d\n", cred);
        }
        void writeRxCred (uint32_t cred) {
            fprintf(stderr, "Received Cred %d\n", cred);
        }
        SonicTopIndication(unsigned int id) : SonicTopIndicationWrapper(id){}
};

int main(int argc, const char **argv)
{
    if (sem_init(&test_sem, 1, 0)) {
        fprintf(stderr, "error: failed to init test_sem\n");
        exit(1);
    }
    fprintf(stderr, "testmemwrite: start %s %s\n", __DATE__, __TIME__);
    DmaManager *dma = platformInit();
    device = new SonicTopRequestProxy(IfcNames_SonicTopRequestS2H);
    SonicTopIndication deviceIndication(IfcNames_SonicTopIndicationH2S);

    fprintf(stderr, "main::allocating memory...\n");
    int dstAlloc = portalAlloc(alloc_sz, 0);
    unsigned int *dstBuffer = (unsigned int *)portalMmap(dstAlloc, alloc_sz);
    unsigned int ref_dstAlloc = dma->reference(dstAlloc);

    int i,j;
    int dataWidth = 128; // 16 bytes per beat
    int numBeats = 13; // number of beats
    int wordsPerBeat = dataWidth / 16;
    int wordsPerBeat2 = wordsPerBeat / 2;
    unsigned long long data_hi;
    unsigned long long data_lo;
    for (i=0; i< numBeats; i++) {
        data_hi = 0;
        data_lo = 0;
        for (j=0; j < wordsPerBeat2; j++) {
            data_hi = (data_hi << 16) + (i*8 + j + 4);
            data_lo = (data_lo << 16) + (i*8 + j);
        }
        if (i==0) {
            device->writePacketData(data_hi, data_lo, 1, 0);
        } else if (i==numBeats-1) {
            device->writePacketData(data_hi, data_lo, 0, 1);
        } else {
            device->writePacketData(data_hi, data_lo, 0, 0);
        }
    }

    for (int i = 0; i < numWords; i++)
        dstBuffer[i] = 0xDEADBEEF;
    portalCacheFlush(dstAlloc, dstBuffer, alloc_sz, 1);
    fprintf(stderr, "testmemwrite: flush and invalidate complete\n");
    fprintf(stderr, "testmemwrite: starting write %08x\n", numWords);
    portalTimerStart(0);
    device->startWrite(ref_dstAlloc, 0, numWords*4, burstLen*4, iterCnt);

    sem_wait(&test_sem);

    for (int i=0; i<numBeats*4; i++) {
        if (i % 4 == 0) fprintf(stderr, "%d ", i * 4);
        fprintf(stderr, "%08x ", dstBuffer[i]);
        if ((i+1) % 4 == 0) fprintf(stderr, "\n");
    }
}
