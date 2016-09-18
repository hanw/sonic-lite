/* Copyright (c) 2016 Cornell University
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

#include "BcamTestIndication.h"
#include "BcamTestRequest.h"
#include "GeneratedTypes.h"

static BcamTestRequestProxy *device = 0;

class BcamTestIndication : public BcamTestIndicationWrapper
{
public:
    virtual void read_version_resp(uint32_t a) {
        fprintf(stderr, "version %x\n", a);
    }
    BcamTestIndication(unsigned int id): BcamTestIndicationWrapper(id) {}
};

int main(int argc, char **argv)
{
    BcamTestIndication indication(IfcNames_BcamTestIndicationH2S);
    device = new BcamTestRequestProxy(IfcNames_BcamTestRequestS2H);

    device->add_entry(0x3417EB96BF1C,0x200);

    sleep(3);
    return 0;
}
