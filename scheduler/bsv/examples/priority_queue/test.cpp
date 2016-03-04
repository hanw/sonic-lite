/* Copyright (c) 2014 Quanta Research Cambridge, Inc
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

#include <errno.h>
#include <stdio.h>
#include "PriorityQueueTopIndication.h"
#include "PriorityQueueTopRequest.h"
#include "GeneratedTypes.h"

static PriorityQueueTopRequestProxy *priorityQueueTopRequestProxy = 0;

class PriorityQueueTopIndication : public PriorityQueueTopIndicationWrapper
{
public:
    virtual void status(uint8_t s) {
        if (s == 1)
            printf("Exiting successfully");
        else
            printf("Encountered some error");
    }

    PriorityQueueTopIndication(unsigned int id) : PriorityQueueTopIndicationWrapper(id) {}
};


int main(int argc, const char **argv)
{
    PriorityQueueTopIndication echoIndication(IfcNames_PriorityQueueTopIndicationH2S);
    priorityQueueTopRequestProxy = new PriorityQueueTopRequestProxy(IfcNames_PriorityQueueTopRequestS2H);

    priorityQueueTopRequestProxy->start();

    while(1);
}
