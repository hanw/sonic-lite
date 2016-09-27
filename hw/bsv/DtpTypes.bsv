// Copyright (c) 2014 Cornell University.

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


interface DtpToPhyIfc;
   interface PipeOut#(Bit#(32)) delayOut;
   interface PipeOut#(Bit#(32)) stateOut;
   interface PipeOut#(Bit#(64)) jumpCount;
   interface PipeOut#(Bit#(53)) cLocalOut;
   interface PipeOut#(Bit#(53)) toHost;
   interface PipeIn#(Bit#(53))  fromHost;
   interface PipeIn#(Bit#(32))  interval;
   interface PipeOut#(Bit#(32)) dtpErrCnt;
endinterface

interface DtpPhyApiIfc;
   interface PipeOut#(Bit#(128)) timestamp;
   interface PipeOut#(Bit#(53)) globalOut;
   interface PipeIn#(Bit#(1)) switchMode;
   interface Vector#(NumPorts, DtpToPhyIfc) phys;
   interface Vector#(NumPorts, PipeOut#(PcsDbgRec)) tx_dbg;
   interface Vector#(NumPorts, PipeOut#(PcsDbgRec)) rx_dbg;
endinterface

typedef struct {
   Bit#(3)  e; //event
   Bit#(53) t; //timestamp
} DtpEvent deriving (Eq, Bits, FShow);

