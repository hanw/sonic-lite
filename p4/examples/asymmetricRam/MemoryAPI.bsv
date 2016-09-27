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
import AsymmetricBRAM::*;

interface MemoryTestIndication;
   method Action read_version_resp(Bit#(32) version);
   method Action readMemResp(Bit#(32) data);
endinterface

interface MemoryTestRequest;
   method Action read_version();
   method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
   method Action memWrite(Bit#(64) address, Bit#(64) data);
   method Action memRead(Bit#(64) address);
endinterface

interface MemoryAPI;
   interface MemoryTestRequest request;
endinterface

module mkMemoryAPI#(MemoryTestIndication indication, AsymmetricBRAM#(Bit#(9), Bit#(16), Bit#(11), Bit#(4)) bram)(MemoryAPI);
   let verbose = True;

   rule read_mem_output;
      let v <- bram.readServer.response.get;
      indication.readMemResp(extend(v));
      if (verbose) $display("indxram: read response=%x", v);
   endrule

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
      endmethod
      method Action memWrite(Bit#(64) address, Bit#(64) data);
         bram.writeServer.put(tuple2(truncate(address), truncate(data)));
      endmethod
      method Action memRead(Bit#(64) address);
         bram.readServer.request.put(truncate(address));
      endmethod
   endinterface
endmodule
