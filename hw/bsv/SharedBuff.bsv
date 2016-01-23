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
import SharedBuffMMU::*;
import MemMgmt::*;
import PhysMemToBram::*;
import Ethernet::*;

interface SharedBuffer#(numeric type addrWidth, numeric type busWidth, numeric type nMasters);
   interface MemServerRequest memServerRequest;
   interface Put#(Bit#(EtherLen)) mallocReq;
   interface Get#(Maybe#(Bit#(32))) mallocDone;
   interface Put#(Bit#(32)) freeReq;
   interface Get#(Bool) freeDone;
endinterface

module mkSharedBuffer#(Vector#(numReadClients, MemReadClient#(busWidth)) readClients
                       ,Vector#(numWriteClients, MemWriteClient#(busWidth)) writeClients
                       ,MemServerIndication memServerInd
`ifdef DEBUG
                       ,MemMgmtIndication memTestInd
                       ,MMUIndication mmuInd
`endif
                      )(SharedBuffer#(addrWidth, busWidth, nMasters))
   provisos(Add#(TLog#(TDiv#(busWidth, 8)), e__, 8)
	    ,Add#(TLog#(TDiv#(busWidth, 8)), f__, BurstLenSize)
	    ,Add#(c__, addrWidth, 64)
	    ,Add#(d__, addrWidth, MemOffsetSize)
	    ,Add#(numWriteClients, a__, TMul#(TDiv#(numWriteClients, nMasters),nMasters))
	    ,Add#(numReadClients, b__, TMul#(TDiv#(numReadClients, nMasters),nMasters))
            ,Mul#(TDiv#(busWidth, TDiv#(busWidth, 8)), TDiv#(busWidth, 8), busWidth)
            ,Mul#(TDiv#(busWidth, ByteEnableSize), ByteEnableSize, busWidth)
            ,Add#(`DataBusWidth, 0, busWidth)
	    );
   let verbose = True;

   MemMgmt#(addrWidth) alloc <- mkMemMgmt(
`ifdef DEBUG
                                          memTestInd
                                         ,mmuInd
`endif
                                         );
   MemServer#(addrWidth, busWidth, nMasters) dma <- mkMemServer(readClients, writeClients, cons(alloc.mmu, nil), memServerInd);

   // TODO: use two ports to improve throughput
   BRAM_Configure bramConfig = defaultValue;
   bramConfig.latency = 2;
`ifdef BYTE_ENABLES
   BRAM1PortBE#(Bit#(addrWidth), Bit#(busWidth), ByteEnableSize) memBuff <- mkBRAM1ServerBE(bramConfig);
   Vector#(nMasters, PhysMemSlave#(addrWidth, busWidth)) memSlaves <- replicateM(mkPhysMemToBramBE(memBuff.portA));
`else
   BRAM1Port#(Bit#(addrWidth), Bit#(busWidth)) memBuff <- ConnectalBram::mkBRAM1Server(bramConfig);
   Vector#(nMasters, PhysMemSlave#(addrWidth, busWidth)) memSlaves <- replicateM(mkPhysMemToBram(memBuff.portA));
`endif

   mkConnection(dma.masters, memSlaves);

   interface MemServerRequest memServerRequest = dma.request;
   interface Put mallocReq = alloc.mallocReq;
   interface Get mallocDone = alloc.mallocDone;
   interface Put freeReq = alloc.freeReq;
   interface Get freeDone = alloc.freeDone;
endmodule

