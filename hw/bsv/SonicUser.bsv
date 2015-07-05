
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

import FIFO ::*;
import FIFOF ::*;
import SpecialFIFOs ::*;
import Vector ::*;
import BuildVector::*;
import Pipe ::*;
import GetPut ::*;
import ClientServer::*;
import MemTypes::*;
import MemreadEngine::*;
import HostInterface::*;

interface SonicIfc;
   interface PipeIn#(Bit#(128)) timestamp; // streaming time counter from NetTop.
   interface Vector#(4, PipeOut#(Bit#(53))) fromHost;
   interface Vector#(4, PipeIn#(Bit#(53)))  toHost;
   interface Vector#(4, PipeIn#(Bit#(32)))  delay;
   interface Vector#(4, PipeIn#(Bit#(32)))  state;
   interface Vector#(4, PipeIn#(Bit#(64)))  jumpCount;
   interface Vector#(4, PipeIn#(Bit#(53)))  cLocal;
   interface PipeIn#(Bit#(53)) globalOut;
   interface Vector#(4, PipeOut#(Bit#(32))) interval;
   interface Vector#(4, PipeIn#(Bit#(32))) dtpErrCnt;
   interface PipeOut#(Bit#(1)) switchMode;
endinterface

interface SonicUserRequest;
   method Action sonic_read_version();
   method Action startRead(Bit#(32) pointer, Bit#(32) numBytes, Bit#(32) burstLen, Bit#(32) iterCnt);
endinterface

interface SonicUserIndication;
   method Action sonic_read_version_resp(Bit#(32) version);
   method Action readDone(Bit#(32) mismatchCnt);
endinterface

interface SonicUser;
   interface SonicUserRequest request;
   //interface Vector#(1, MemWriteClient#(DataBusWidth)) dmaWriteClient;
   interface Vector#(1, MemReadClient#(DataBusWidth)) dmaReadClient;
   interface SonicIfc sonicifc;
endinterface

typedef 12 NumOutstandingRequests;
typedef TMul#(NumOutstandingRequests, TMul#(32, 4)) BufferSizeBytes;

module mkSonicUser#(SonicUserIndication indication)(SonicUser);
   Clock defaultClock <- exposeCurrentClock();

   MemreadEngine#(DataBusWidth, NumOutstandingRequests, 1) re <- mkMemreadEngineBuff(valueof(BufferSizeBytes));

   interface dmaReadClient = vec(re.dmaClient);
   interface SonicUserRequest request;
      method Action sonic_read_version();
         let v = `SonicVersion; //Defined in Makefile as time of compilation.
         indication.sonic_read_version_resp(v);
      endmethod
      method Action startRead(Bit#(32) p, Bit#(32) nb, Bit#(32) bl, Bit#(32) ic);
         $display("start read");
      endmethod
   endinterface
endmodule
