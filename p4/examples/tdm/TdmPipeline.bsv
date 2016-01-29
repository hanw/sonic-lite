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

import DbgTypes::*;
import Ethernet::*;
import EthMac::*;
import GenericMatchTable::*;
import IPv4Parser::*;
import MMU::*;
import MemMgmt::*;
import PacketBuffer::*;
import SharedBuff::*;
import StoreAndForward::*;
import Tap::*;
import TDM::*;
import TdmTypes::*;

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
   method MatchTableDbgRec matchTableDbg;
   method TxThruDbgRec ringToMacDbg;
endinterface

module mkTdmPipeline#(Clock txClock, Reset txReset
                     ,Clock rxClock, Reset rxReset
                     ,MemoryTestIndication indication
                     ,ConnectalMemory::MemServerIndication memServerInd
`ifdef DEBUG
                     ,MemMgmtIndication memTestInd
                     ,ConnectalMemory::MMUIndication mmuInd
`endif
   )(TdmPipeline);

   // Ethernet Port
   PacketBuffer hostPktBuff <- mkPacketBuffer();
   PacketBuffer txPktBuff <- mkPacketBuffer();
   PacketBuffer rxPktBuff <- mkPacketBuffer();

   // Ethernet Parser
   TapPktRead txTap <- mkTapPktRead();
   Parser txParser <- mkParser();

   // Ingress Pipeline
   MatchTable#(256, 36) matchTable <- mkMatchTable();

   // Egress Pipeline
   ModifyMac modMac <- mkModifyMac();

   StoreAndFwdFromRingToMem txIngress <- mkStoreAndFwdFromRingToMem();
   StoreAndFwdFromRingToMem rxIngress <- mkStoreAndFwdFromRingToMem();

   // Network Ingress
   StoreAndFwdFromMacToRing rxMacToRing <- mkStoreAndFwdFromMacToRing(rxClock, rxReset);

   // Egress
   StoreAndFwdFromMemToRing egress <- mkStoreAndFwdFromMemToRing();
   StoreAndFwdFromRingToMac egressRingToMac <- mkStoreAndFwdFromRingToMac(txClock, txReset);


   SharedBuffer#(12, 128, 1) mem <- mkSharedBuffer(vec(egress.readClient)
                                                  ,vec(egress.free)
                                                  ,vec(txIngress.writeClient, modMac.writeClient)
                                                  ,vec(txIngress.malloc, rxIngress.malloc)
                                                  ,memServerInd
`ifdef DEBUG
                                                  ,memTestInd
                                                  ,mmuInd
`endif
                                                  );

   // Host Tx Ingress
   mkConnection(txTap.readClient, hostPktBuff.readServer);
   mkConnection(txIngress.readClient, txTap.readServer);
   mkConnection(txTap.tap_out, toPut(txParser.frameIn));

   // Network Rx Ingress
   mkConnection(rxMacToRing.writeClient, rxPktBuff.writeServer);
   //mkConnection(rxIngress.readClient, rxPktBuff.readServer);

   // Network Tx Egress
   mkConnection(egress.writeClient, txPktBuff.writeServer);
   mkConnection(egressRingToMac.readClient, txPktBuff.readServer);

   TDM sched <- mkTDM(txIngress, egress, txParser, matchTable, modMac);

   rule read_flow_id;
      let v <- toGet(matchTable.entry_added).get;
      indication.addEntryResp(v);
   endrule

   interface macRx = rxMacToRing.macRx;
   interface macTx = egressRingToMac.macTx;
   interface writeServer = hostPktBuff.writeServer;
   interface add_entry = matchTable.add_entry;
   interface delete_entry = matchTable.delete_entry;
   interface modify_entry = matchTable.modify_entry;
   method matchTableDbg = matchTable.dbg;
   method memMgmtDbg = mem.dbg;
   method tdmDbg = sched.dbg;
   method ringToMacDbg = egressRingToMac.dbg;
   method ActionValue#(PktBuffDbgRec) pktBuffDbg(Bit#(8) id);
      PktBuffDbgRec v = defaultValue;
      case (id) matches
         0: v = PktBuffDbgRec{sopEnq: hostPktBuff.dbg.sopEnq, eopEnq: hostPktBuff.dbg.eopEnq, sopDeq: hostPktBuff.dbg.sopDeq, eopDeq: hostPktBuff.dbg.eopDeq};
         1: v = PktBuffDbgRec{sopEnq: txPktBuff.dbg.sopEnq, eopEnq: txPktBuff.dbg.eopEnq, sopDeq: txPktBuff.dbg.sopDeq, eopDeq: txPktBuff.dbg.eopDeq};
         2: v = PktBuffDbgRec{sopEnq: rxPktBuff.dbg.sopEnq, eopEnq: rxPktBuff.dbg.eopEnq, sopDeq: rxPktBuff.dbg.sopDeq, eopDeq: rxPktBuff.dbg.eopDeq};
         default: $display("invalid buffer");
      endcase
      return v;
   endmethod
endmodule
