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
#include <pthread.h>
#include <stdio.h>
#include <assert.h>
#include "dmaManager.h"
#include "SonicUserRequest.h"
#include "SonicUserIndication.h"

#define NUMBER_OF_TESTS 1

int burstLen = 32;
int numWords = 0x1240000/4; // make sure to allocate at least one entry of each size
int iterCnt = 64;
static SonicUserRequestProxy *device = 0;
static sem_t test_sem;
static size_t test_sz  = numWords*sizeof(unsigned int);
static size_t alloc_sz = test_sz;
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
        void writeTxCred (uint32_t cred) {
            fprintf(stderr, "Received Cred %d\n", cred);
        }
		SonicUserIndication(unsigned int id) : SonicUserIndicationWrapper(id){}
};

int main(int argc, const char **argv)
{
    int test_result = 0;
    int srcAlloc;
    unsigned int *srcBuffer = 0;

	fprintf(stderr, "Main::allocating memory...\n");
    srcAlloc = portalAlloc(alloc_sz, 0);
    srcBuffer = (unsigned int *)portalMmap(srcAlloc, alloc_sz);
    for (int i = 0; i < numWords; i++)
        srcBuffer[i] = i;
    portalCacheFlush(srcAlloc, srcBuffer, alloc_sz, 1);
    fprintf(stderr, "Main::flush and invalidate complete\n");

	fprintf(stderr, "Main::%s %s\n", __DATE__, __TIME__);
	DmaManager *dma = platformInit();
	device = new SonicUserRequestProxy(IfcNames_SonicUserRequestS2H);
	SonicUserIndication memReadIndication(IfcNames_SonicUserIndicationH2S);

    /* Test 1: check that match is ok */
    unsigned int ref_srcAlloc = dma->reference(srcAlloc);
    fprintf(stderr, "ref_srcAlloc=%d\n", ref_srcAlloc);
    fprintf(stderr, "Main::orig_test read numWords=%d burstLen=%d iterCnt=%d\n", numWords, burstLen, iterCnt);
    portalTimerStart(0);
    device->startRead(ref_srcAlloc, 0, numWords * 4, burstLen * 4, iterCnt);
    sem_wait(&test_sem);
    if (mismatchCount) {
        fprintf(stderr, "Main::first test failed to match %d.\n", mismatchCount);
        test_result++;     // failed
    }
    platformStatistics();

    /* Test 2: check that mismatch is detected */
    srcBuffer[0] = -1;
    srcBuffer[numWords/2] = -1;
    srcBuffer[numWords-1] = -1;
    portalCacheFlush(srcAlloc, srcBuffer, alloc_sz, 1);

    fprintf(stderr, "Starting second read, mismatches expected\n");
    mismatchCount = 0;
    device->startRead(ref_srcAlloc, 0, numWords * 4, burstLen * 4, iterCnt);
    sem_wait(&test_sem);
    if (mismatchCount != 3/*number of errors introduced above*/ * iterCnt) {
        fprintf(stderr, "Main::second test failed to match mismatchCount=%d (expected %d) iterCnt=%d numWords=%d.\n",
            mismatchCount, 3*iterCnt,
            iterCnt, numWords);
        test_result++;     // failed
    }
    return test_result;
}
