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
import FwdTypes::*;
import PktGen::*;
import PacketBuffer::*;
import RxChannel::*;
import TxChannel::*;
import HostChannel::*;
import SharedBuff::*;
import PaxosIngressPipeline::*;

interface FwdTestRequest;
   method Action read_version();
   method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
   method Action readRxRingBuffCntrs();
   method Action readTxRingBuffCntrs();
   method Action readMemMgmtCntrs();
   method Action readIngressCntrs();
   method Action readHostChanCntrs();
   method Action readRxChanCntrs();
endinterface

interface FwdAPI;
   interface FwdTestRequest request;
endinterface

module mkFwdAPI#(FwdTestIndication indication, PaxosIngressPipeline ingress, HostChannel hostchan, RxChannel rxchan, TxChannel txchan, SharedBuffer#(12, 128, 1) buff)(FwdAPI);

   interface FwdTestRequest request;
      method Action read_version();
         let v= `NicVersion;
         indication.read_version_resp(v);
      endmethod
      method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
         EtherData beat = defaultValue;
         beat.data = pack(reverse(data));
         beat.mask = pack(reverse(mask));
         beat.sop = unpack(sop);
         beat.eop = unpack(eop);
         hostchan.writeServer.writeData.put(beat);
      endmethod
      method Action readRxRingBuffCntrs();
         let v = rxchan.dbg;
         indication.readRxRingBuffCntrsResp(v.sopEnq, v.eopEnq, v.sopDeq, v.eopDeq);
      endmethod
      method Action readTxRingBuffCntrs();
         let v = txchan.dbg;
         indication.readTxRingBuffCntrsResp(v.sopEnq, v.eopEnq, v.sopDeq, v.eopDeq);
      endmethod
      method Action readMemMgmtCntrs();
         let v = buff.dbg;
         indication.readMemMgmtCntrsResp(v.allocCnt, v.freeCnt, v.allocCompleted, v.freeCompleted, v.errorCode, v.lastIdFreed, v.lastIdAllocated, v.freeStarted, v.firstSegment, v.lastSegment, v.currSegment, v.invalidSegment);
      endmethod
      method Action readIngressCntrs();
         let v = ingress.dbg;
         indication.readIngressCntrsResp(v.fwdCount);
      endmethod
      method Action readHostChanCntrs();
         let v = hostchan.hostdbg;
         indication.readHostChanCntrsResp(v.paxosCount, v.ipv6Count, v.udpCount);
      endmethod
      method Action readRxChanCntrs();
         let v = rxchan.hostdbg;
         indication.readRxChanCntrsResp(v.paxosCount, v.ipv6Count, v.udpCount);
      endmethod
   endinterface
endmodule
