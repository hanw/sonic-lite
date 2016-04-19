// Copyright (c) 2015 Cornell University.

// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#include <iostream>
#include <unordered_map>

#ifdef __cplusplus
extern "C" {
#endif
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

typedef uint64_t DmacReqT;
typedef uint16_t DmacRespT;
typedef uint16_t SequenceReqT;
typedef uint8_t SequenceRespT;
typedef uint16_t AcceptorReqT;
typedef uint8_t AcceptorRespT;

std::unordered_map<DmacReqT, DmacRespT> dmac_table;
std::unordered_map<SequenceReqT, SequenceRespT> sequence_table;
std::unordered_map<AcceptorReqT, AcceptorRespT> acceptor_table;

extern "C" uint16_t matchtable_read_dmac(DmacReqT rdata)
{
    fprintf(stderr, "CPP: match table read %lx\n", rdata);
    for( const auto& n : dmac_table ) {
        fprintf(stderr, "READ: Key:[%lx] Value:[%x]\n", n.first, n.second);
    }
    auto it = dmac_table.find(rdata);
    if (it != dmac_table.end()) {
        return dmac_table[rdata];
    } else {
        return 0;
    }
}

extern "C" void matchtable_write_dmac(DmacReqT wdata, DmacRespT action)
{
    fprintf(stderr, "CPP: match table write %lx %x\n", wdata, action);
    dmac_table[wdata] = action;
    for( const auto& n : dmac_table ) {
        fprintf(stderr, "WRITE: Key:[%lx] Value:[%x]\n", n.first, n.second);
    }
}

extern "C" SequenceRespT matchtable_read_sequence(SequenceReqT rdata)
{
    std::cout << "CPP: match table read" << std::hex << rdata << "\n";
    for( const auto& n : sequence_table) {
        fprintf(stderr, "READ: Key:[%x] Value:[%x]\n", n.first, n.second);
    }
    fprintf(stderr, "accessing table %p with key %x\n", &sequence_table, rdata);
    auto it = sequence_table.find(rdata);
    if (it != sequence_table.end()) {
        return sequence_table[rdata];
    } else {
        return 0;
    }
}

extern "C" void matchtable_write_sequence(SequenceReqT wdata, SequenceRespT action)
{
    fprintf(stderr, "CPP: match table write %x %x\n", wdata, action);
    sequence_table[wdata] = action;
    for( const auto& n : sequence_table ) {
        fprintf(stderr, "WRITE: Key:[%x] Value:[%x]\n", n.first, n.second);
    }
}

extern "C" AcceptorRespT matchtable_read_acceptor(AcceptorReqT rdata)
{
    fprintf(stderr, "CPP: match table read %x\n", rdata);
    for( const auto& n : acceptor_table) {
        fprintf(stderr, "READ: Key:[%x] Value:[%x]\n", n.first, n.second);
    }
    fprintf(stderr, "accessing table %p with key %x\n", &acceptor_table, rdata);
    auto it = acceptor_table.find(rdata);
    if (it != acceptor_table.end()) {
        return acceptor_table[rdata];
    } else {
        return 0;
    }
}

extern "C" void matchtable_write_acceptor(AcceptorReqT wdata, AcceptorRespT action)
{
    fprintf(stderr, "CPP: match table write %x %x\n", wdata, action);
    acceptor_table[wdata] = action;
    for( const auto& n : acceptor_table ) {
        fprintf(stderr, "WRITE: Key:[%x] Value:[%x]\n", n.first, n.second);
    }
}

#ifdef __cplusplus
}
#endif
