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
import FIFOF::*;
import DefaultValue::*;
import Vector::*;
import BuildVector::*;
import GetPut::*;
import ClientServer::*;
import Connectable::*;
import Clocks::*;
import Gearbox::*;
import Pipe::*;
import RegFile::*;
import MemTypes::*;

import Ethernet::*;
import PacketBuffer::*;
import SharedBuff::*;
import StoreAndForward::*;
import TDM::*;
import EthMac::*;
import MMU::*;
import MemMgmt::*;
import IPv4Parser::*;
import Tap::*;
import GenericMatchTable::*;
import DbgTypes::*;
import TopTypes::*;

interface TdmPipeline;
   interface Put#(PacketDataT#(64)) macRx;
   interface Get#(PacketDataT#(64)) macTx;
   interface PktWriteServer writeServer;
   interface Put#(TableEntry) add_entry;
   interface Put#(FlowId) delete_entry;
   interface Put#(Tuple2#(FlowId, ActionArg)) modify_entry;
   method MemMgmtDbgRec memMgmtDbg;
   method TDMDbgRec tdmDbg;
   method ActionValue#(PktBuffDbgRec) pktBuffDbg(Bit#(8) id);
endinterface

module mkTdmPipeline#(Clock txClock, Reset txReset
                       ,MemoryTestIndication indication
                       ,ConnectalMemory::MemServerIndication memServerInd
`ifdef DEBUG
                       ,MemMgmtIndication memTestInd
                       ,MMUIndication mmuInd
`endif
   )(TdmPipeline);

   // Ethernet Port
   PacketBuffer incoming_buff <- mkPacketBuffer();
   PacketBuffer outgoing_buff <- mkPacketBuffer();

   // Ethernet Parser
   TapPktRead tap <- mkTapPktRead();
   Parser ipv4Parser <- mkParser();

   // Ingress Pipeline
   MatchTable#(256, 36) matchTable <- mkMatchTable();

   // Egress Pipeline
   ModifyMac modMac <- mkModifyMac();

   StoreAndFwdFromRingToMem ingress <- mkStoreAndFwdFromRingToMem(
`ifdef DEBUG
                                                                  memTestInd
`endif
                                                                 );
   StoreAndFwdFromMemToRing egress <- mkStoreAndFwdFromMemToRing();
   StoreAndFwdFromRingToMac ringToMac <- mkStoreAndFwdFromRingToMac(txClock, txReset);

   SharedBuffer#(12, 128, 1) mem <- mkSharedBuffer(vec(egress.readClient)
                                                  ,vec(ingress.writeClient, modMac.writeClient)
                                                  ,memServerInd
`ifdef DEBUG
                                                  ,memTestInd
                                                  ,mmuInd
`endif
                                                  );


   //mkConnection(ingress.readClient, incoming_buff.readServer);
   mkConnection(tap.readClient, incoming_buff.readServer);
   mkConnection(ingress.readClient, tap.readServer);
   mkConnection(tap.tap_out, toPut(ipv4Parser.frameIn));

   // alloc
   mkConnection(ingress.mallocReq, mem.mallocReq);
   mkConnection(mem.mallocDone, ingress.mallocDone);

   // free
   mkConnection(egress.freeReq, mem.freeReq);
   //mkConnection(mem.freeDone, egress.freeDone);

   mkConnection(egress.writeClient, outgoing_buff.writeServer);
   mkConnection(ringToMac.readClient, outgoing_buff.readServer);

   // Null Forwarding bypass pipeline
   //mkConnection(ingress.eventPktCommitted, egress.eventPktSend);

   TDM sched <- mkTDM(ingress, egress, ipv4Parser, matchTable, modMac);

   rule read_flow_id;
      let v <- toGet(matchTable.entry_added).get;
      indication.addEntryResp(v);
   endrule

   interface macTx = ringToMac.macTx;
   interface writeServer = incoming_buff.writeServer;
   interface add_entry = matchTable.add_entry;
   interface delete_entry = matchTable.delete_entry;
   interface modify_entry = matchTable.modify_entry;
   method memMgmtDbg = mem.dbg;
   method tdmDbg = sched.dbg;
   method ActionValue#(PktBuffDbgRec) pktBuffDbg(Bit#(8) id);
      PktBuffDbgRec v = defaultValue;
      case (id) matches
         0: v = PktBuffDbgRec{sopEnq: incoming_buff.dbg.sopEnq, eopEnq: incoming_buff.dbg.eopEnq, sopDeq: incoming_buff.dbg.sopDeq, eopDeq: incoming_buff.dbg.eopDeq};
         1: v = PktBuffDbgRec{sopEnq: outgoing_buff.dbg.sopEnq, eopEnq: outgoing_buff.dbg.eopEnq, sopDeq: outgoing_buff.dbg.sopDeq, eopDeq: outgoing_buff.dbg.eopDeq};
         default: $display("invalid buffer");
      endcase
      return v;
   endmethod
endmodule
