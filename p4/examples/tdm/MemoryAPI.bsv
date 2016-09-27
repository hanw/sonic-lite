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

import FIFO::*;
import BuildVector::*;
import ClientServer::*;
import Connectable::*;
import DefaultValue::*;
import GetPut::*;
import Vector::*;

import Ethernet::*;
import DbgTypes::*;
import PktGen::*;
import PacketBuffer::*;
import TdmTypes::*;
import TdmPipeline::*;

interface MemoryTestRequest;
   method Action read_version();
   method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
   method Action start(Bit#(32) iter, Bit#(32) ipg);
   method Action stop();
   method Action addEntry(Bit#(32) name, MatchField fields);
   method Action deleteEntry(Bit#(32) name, FlowId flow_id);
   method Action modifyEntry(Bit#(32) name, FlowId flow_id, ActionArg actions);
   method Action readRingBuffCntrs(Bit#(8) id);
   method Action readMemMgmtCntrs();
   method Action readTDMCntrs();
   method Action readMatchTableCntrs();
   method Action readTxThruCntrs();
endinterface

interface MemoryAPI;
   interface MemoryTestRequest request;
   interface Get#(Tuple2#(Bit#(32), Bit#(32))) pktGenStart;
   interface Get#(void) pktGenStop;
   interface Get#(ByteStream#(16)) pktGenWrite;
endinterface

module mkMemoryAPI#(MemoryTestIndication indication, TdmPipeline tdm)(MemoryAPI);
   
   FIFO#(Tuple2#(Bit#(32), Bit#(32))) startReqFifo <- mkFIFO;
   FIFO#(void) stopReqFifo <- mkFIFO;
   FIFO#(ByteStream#(16)) etherDataFifo <- mkFIFO;

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
         etherDataFifo.enq(beat);
      endmethod
      method Action start(Bit#(32) pktCount, Bit#(32) ipg);
         startReqFifo.enq(tuple2(pktCount, ipg));
      endmethod
      method Action stop();
         stopReqFifo.enq(?);
      endmethod
      method Action addEntry(Bit#(32) table_name, MatchField fields);
         $display("MemoryAPI:: added entry ", fshow(fields));
         ActionArg args = ActionArg{egress_index: 4};
         TableEntry entry = TableEntry{field: fields, argument: args };
         tdm.add_entry.put(entry);
      endmethod

      method Action deleteEntry(Bit#(32) table_name, FlowId id);
         $display("MemoryAPI:: delete entry flow id ", fshow(id));
         tdm.delete_entry.put(id);
      endmethod

      method Action modifyEntry(Bit#(32) table_name, FlowId id, ActionArg args);
         $display("MemoryAPI:: modify entry flow id ", fshow(id), " action ", fshow(args));
         tdm.modify_entry.put(tuple2(id, args));
      endmethod

      method Action readRingBuffCntrs(Bit#(8) id);
         if (id < 3) begin
            let v <- tdm.pktBuffDbg(id);
            indication.readRingBuffCntrsResp(v.sopEnq, v.eopEnq, v.sopDeq, v.eopDeq);
         end
         else begin
            indication.readRingBuffCntrsResp(0, 0, 0, 0);
         end
      endmethod

      method Action readMemMgmtCntrs();
         let v = tdm.memMgmtDbg();
         indication.readMemMgmtCntrsResp(v.allocCnt, v.freeCnt, v.allocCompleted, v.freeCompleted, v.errorCode, v.lastIdFreed, v.lastIdAllocated, v.freeStarted, v.firstSegment, v.lastSegment, v.currSegment, v.invalidSegment);
      endmethod

      method Action readTDMCntrs();
         let v = tdm.tdmDbg();
         indication.readTDMCntrsResp(v.fwdReqCnt, v.sendCnt);
      endmethod

      method Action readMatchTableCntrs();
         let v = tdm.matchTableDbg();
         indication.readMatchTableCntrsResp(v.matchRequestCount, v.matchResponseCount, v.matchValidCount, v.lastMatchIdx, v.lastMatchRequest);
      endmethod

      method Action readTxThruCntrs();
         let v = tdm.ringToMacDbg;
         indication.readTxThruCntrsResp(v.goodputCount, v.idleCount);
      endmethod
   endinterface
   interface pktGenStart = toGet(startReqFifo);
   interface pktGenStop = toGet(stopReqFifo);
   interface pktGenWrite = toGet(etherDataFifo);
endmodule
