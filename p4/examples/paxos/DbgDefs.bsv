// Copyright (c) 2016 Cornell University.

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

import DefaultValue::*;
import DbgTypes::*;

typedef UInt#(64) LUInt;
typedef Int#(64)  LInt;

typedef struct {
   LUInt pktIn;
   LUInt pktOut;
} TableDbgRec deriving (Bits, Eq, FShow);
instance DefaultValue #(TableDbgRec);
   defaultValue = unpack(0);
endinstance

typedef struct {
   LUInt fwdCount;
   TableDbgRec accTbl;
   TableDbgRec seqTbl;
   TableDbgRec dmacTbl;
} IngressDbgRec deriving (Bits, Eq, FShow);
instance DefaultValue #(IngressDbgRec);
   defaultValue = unpack(0);
endinstance

typedef struct {
   LUInt paxosCount;
   LUInt ipv6Count;
   LUInt udpCount;
   PktBuffDbgRec pktBuff;
} HostChannelDbgRec deriving (Bits, Eq, FShow);
instance DefaultValue#(HostChannelDbgRec);
   defaultValue = unpack(0);
endinstance

typedef struct {
   LUInt egressCount;
   PktBuffDbgRec pktBuff;
} TxChannelDbgRec deriving (Bits, Eq, FShow);
instance DefaultValue#(TxChannelDbgRec);
   defaultValue = unpack(0);
endinstance

typedef struct {
   Bit#(32) ingress_start_time;
   Bit#(32) ingress_end_time;
   Bit#(32) acceptor_start_time;
   Bit#(32) acceptor_end_time;
   Bit#(32) sequence_start_time;
   Bit#(32) sequence_end_time;
} IngressPerfRec deriving (Bits, Eq, FShow);
instance DefaultValue#(IngressPerfRec);
   defaultValue = unpack(0);
endinstance

typedef struct {
   Bit#(32) parser_start_time;
   Bit#(32) parser_end_time;
} ParserPerfRec deriving (Bits, Eq, FShow);
instance DefaultValue#(ParserPerfRec);
   defaultValue = unpack(0);
endinstance
