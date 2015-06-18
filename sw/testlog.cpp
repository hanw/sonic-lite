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
#include <assert.h>

#include "SonicUserRequest.h"
#include "SonicUserIndication.h"

#define NUMBER_OF_TESTS 1

static SonicUserRequestProxy *device = 0;
//static sem_t wait_log;

class SonicUser : public SonicUserIndicationWrapper
{
public:
  virtual void dtp_read_version_resp(uint32_t a) {
    fprintf(stderr, "read version %d\n", a);
  }

  virtual void dtp_read_delay_resp(uint8_t p, uint32_t a) {
    fprintf(stderr, "read delay(%d) %d\n", p, a);
  }
  virtual void dtp_read_state_resp(uint8_t p, uint32_t a) {
    fprintf(stderr, "read state(%d) %d\n", p, a);
  }
  virtual void dtp_read_error_resp(uint8_t p, uint64_t a) {
    fprintf(stderr, "read error(%d) %ld\n", p, a);
  }
  virtual void dtp_read_cnt_resp(uint64_t a) {
    fprintf(stderr, "readCycleCount(%lx)\n", a);
  }
  virtual void dtp_logger_read_cnt_resp(uint8_t a, uint64_t b, uint64_t c, uint64_t d) {
	fprintf(stderr, "read from port(%d) local_cnt(%lx) msg1(%lx) msg2(%lx)\n", a, b, c, d);
  }
  virtual void dtp_read_local_cnt_resp(uint8_t p, uint64_t a) {
	fprintf(stderr, "read from port(%d) local_cnt(%lx)\n", p, a);
  }
  SonicUser(unsigned int id) : SonicUserIndicationWrapper(id) {}
};

int main(int argc, const char **argv)
{
	uint32_t count = 100;
	SonicUser indication(IfcNames_SonicUserIndicationH2S);
	device = new SonicUserRequestProxy(IfcNames_SonicUserRequestS2H);
	device->pint.busyType = BUSY_SPIN;   /* spin until request portal 'notFull' */

	device->dtp_reset(0x0);
	device->dtp_read_version();

	fprintf(stderr, "Main::about to go to sleep\n");
	while(true){
		for (int i=0; i<1; i++) {
			device->dtp_read_delay(i);
			device->dtp_read_state(i);
			device->dtp_read_error(i);
			device->dtp_read_cnt(i);
		}
		for (int i=0; i<4; i++) {
			device->dtp_logger_write_cnt(i, count);
		}
		for (int i=0; i<4; i++) {
			device->dtp_logger_read_cnt(i);
		}
		count ++;
		sleep(2);
	}
}
