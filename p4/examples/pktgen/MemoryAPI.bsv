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

import BuildVector::*;
import ClientServer::*;
import Connectable::*;
import DefaultValue::*;
import GetPut::*;
import Vector::*;

import Ethernet::*;
import PacketBuffer::*;
import PktGen::*;

interface MemoryTestIndication;
   method Action read_version_resp(Bit#(32) version);
endinterface

interface MemoryTestRequest;
   method Action read_version();
   method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
   method Action start(Bit#(32) iter, Bit#(32) ipg);
   method Action stop();
   method Action clear();
endinterface

interface MemoryAPI;
   interface MemoryTestRequest request;
endinterface

module mkMemoryAPI#(MemoryTestIndication indication, PktGen pktgen)(MemoryAPI);

   interface MemoryTestRequest request;
      method Action read_version();
         let v= `NicVersion;
         indication.read_version_resp(v);
      endmethod
      method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
         ByteStream#(16) beat = defaultValue;
         beat.data = pack(reverse(data));
         beat.mask = pack(reverse(mask));
         beat.sop = unpack(sop);
         beat.eop = unpack(eop);
         pktgen.writeServer.writeData.put(beat);
      endmethod
      method start = pktgen.start;
      method stop = pktgen.stop;
   endinterface
endmodule
