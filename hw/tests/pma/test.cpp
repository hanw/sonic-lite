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

#include "PmaTestRequest.h"
#include "PmaTestIndication.h"
#include "GeneratedTypes.h"

static PmaTestRequestProxy *device = 0;

class PmaTestTop : public PmaTestIndicationWrapper
{
   public:
      virtual void read_version_resp(uint32_t a) {
         fprintf(stderr, "read version %x\n", a);
      }

      PmaTestTop (unsigned int id) : PmaTestIndicationWrapper(id) {}
};

int main(int argc, const char **argv)
{
   PmaTestTop indication(IfcNames_PmaTestIndicationH2S);
   device = new PmaTestRequestProxy (IfcNames_PmaTestRequestS2H);
   device->pint.busyType = BUSY_SPIN;

   device->dtp_reset(32);
   return 0;
}
