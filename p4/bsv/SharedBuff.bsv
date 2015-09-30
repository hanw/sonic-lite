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

// NOTE:
// - This module stores packet in FIFO order with no guarantees on per-port fairness.
// - Access-control module provides per-port fairness, which is outside the packet buffer.

import BRAM::*;
import FIFO::*;
import FIFOF::*;
import GetPut::*;
import Vector::*;
import Connectable::*;
import ConnectalBram::*;
import ConnectalMemory::*;
import MemTypes::*;
import MemServer::*;
import MemServerInternal::*;
import MMU::*;
import SimpleMMU::*;
import PhysMemToBram::*;

interface SharedBuffer#(numeric type addrWidth, numeric type busWidth, numeric type nMasters);
   interface MemServerRequest request;
endinterface

module mkSharedBuffer#(Vector#(numReadClients, MemReadClient#(busWidth)) readClients,
                       Vector#(numWriteClients, MemWriteClient#(busWidth)) writeClients,
                       MemServerIndication indication,
                       MMUIndication mmuIndication)
                       (SharedBuffer#(addrWidth, busWidth, nMasters))
   provisos(Add#(TLog#(TDiv#(busWidth, 8)), e__, 8)
	    ,Add#(TLog#(TDiv#(busWidth, 8)), f__, BurstLenSize)
	    ,Add#(c__, addrWidth, 64)
	    ,Add#(d__, addrWidth, MemOffsetSize)
	    ,Add#(numWriteClients, a__, TMul#(TDiv#(numWriteClients, nMasters),nMasters))
	    ,Add#(numReadClients, b__, TMul#(TDiv#(numReadClients, nMasters),nMasters))
	    );

   MMU#(addrWidth) simpleMMU <- mkSimpleMMU();
   MemServer#(addrWidth, busWidth, nMasters) dma <- mkMemServer(readClients, writeClients, cons(simpleMMU, nil), indication);

   BRAM_Configure bramConfig = defaultValue;
   bramConfig.latency = 2;
   BRAM1Port#(Bit#(addrWidth), Bit#(busWidth)) memBuff <- ConnectalBram::mkBRAM1Server(bramConfig);
   Vector#(nMasters, PhysMemSlave#(addrWidth, busWidth)) memSlaves <- replicateM(mkPhysMemToBram(memBuff.portA));

   mkConnection(dma.masters, memSlaves);

   interface MemServerRequest request = dma.request;
endmodule

