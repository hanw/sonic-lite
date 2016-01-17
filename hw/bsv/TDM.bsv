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

import Vector::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import BRAM::*;
import GetPut::*;
import DefaultValue::*;
import Clocks::*;

import PacketBuffer::*;
import MemTypes::*;
import Ethernet::*;
import MemoryAPI::*;
import SharedBuff::*;
import StoreAndForward::*;

`ifndef SIMULATION
import AlteraMacWrap::*;
import EthMac::*;
import AlteraEthPhy::*;
import DE5Pins::*;
`else
import Sims::*;
`endif

typedef 16 NumOfHosts;
typedef 8 SlotLen;

typedef struct {
   Bit#(TLog#(NumOfHosts)) host;
   Bit#(32) id;
} FQWriteRequest deriving(Bits, Eq);

typedef struct {
   Bit#(TLog#(NumOfHosts)) host;
} FQReadRequest deriving(Bits, Eq);

typedef struct {
   Bit#(32) id;
} FQReadResp deriving(Bits, Eq);

interface TimeSlot;
   interface Get#(Bit#(TLog#(NumOfHosts))) currSlot;
endinterface

module mkTimeSlot(TimeSlot);
   Reg#(Bit#(32)) global_count <- mkReg(0);

   rule increment;
      global_count <= global_count + 1;
   endrule

   function Bit#(TLog#(NumOfHosts)) get_slot (Bit#(32) v);
      let l = fromInteger(valueOf(TLog#(SlotLen)));
      Vector#(TLog#(NumOfHosts), Bit#(1)) slot = takeAt(l, unpack(v));
      return pack(slot);
   endfunction

   interface Get currSlot;
      method ActionValue#(Bit#(TLog#(NumOfHosts))) get;
         return get_slot(global_count);
      endmethod
   endinterface
endmodule

interface ForwardQ;
   interface Put#(FQWriteRequest) req_w;
   interface Put#(FQReadRequest) req_r;
   interface Get#(FQReadResp) resp_r;
endinterface

module mkForwardQ(ForwardQ);
   Vector#(NumOfHosts, FIFOF#(Bit#(32))) fwdFifo <- replicateM(mkSizedFIFOF(16));
   FIFO#(FQReadResp) resp_fifo <- mkFIFO;

   interface Put req_w;
      method Action put(FQWriteRequest req);
         let hostIdx = req.host;
         fwdFifo[hostIdx].enq(req.id);
      endmethod
   endinterface
   interface Put req_r;
      method Action put(FQReadRequest req);
         let hostIdx = req.host;
         if (fwdFifo[hostIdx].notEmpty) begin
            resp_fifo.enq(FQReadResp{id:fwdFifo[hostIdx].first});
            fwdFifo[hostIdx].deq;
         end
         else begin
            if (fwdFifo[0].notEmpty) begin
               resp_fifo.enq(FQReadResp{id:fwdFifo[hostIdx].first});
               fwdFifo[0].deq;
            end
         end
      endmethod
   endinterface
   interface Get resp_r = toGet(resp_fifo);
endmodule

interface TDM;
   interface Vector#(4, PktWriteClient) writeClients;
   interface Vector#(4, PktReadServer) readServers;
endinterface

module mkTDM#(SharedBuffer#(12, 128, 1) buff)(TDM);

   // Control Registers

   //! Schedule Table: support insert and lookup
   //! Mac Table: support insert and lookup

   //! Function: ipToIndex

   TimeSlot slot <- mkTimeSlot();
   ForwardQ fwdq <- mkForwardQ();

   //! poll rx, read packet if any
   //! let v <- id_fifo.get;

   // Packet Processing Pipeline
   // extract ip header
   // header = ExtractIP(id, offset, length)

   // map(ipToIndex, ip)
   // index = TableLookup(table, ip)

   // modify_mac
   // ModifyMac(id, offset, value)

   //! tx to mac
   //! TransmitPacket(id, slot, port);

endmodule

interface P4;

endinterface
module mkP4();

endmodule
