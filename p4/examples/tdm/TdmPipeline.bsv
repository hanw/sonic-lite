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
import HostChannel::*;
import TxChannel::*;
import RxChannel::*;
import ModifyMac::*;
import IPv4Parser::*;
import IPv4Route::*;
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

   RxChannel rxchan <- mkRxChannel(rxClock, rxReset);
   HostChannel hostchan <- mkHostChannel();
   TxChannel txchan <- mkTxChannel(txClock, txReset);

   IPv4Route ipv4Route <- mkIPv4Route(hostchan.next);
   ModifyMac modMac <- mkModifyMac(ipv4Route.next);
   TDM sched <- mkTDM(modMac.next, txchan);

   SharedBuffer#(12, 128, 1) mem <- mkSharedBuffer(vec(txchan.readClient)
                                                  ,vec(txchan.freeClient)
                                                  ,vec(hostchan.writeClient, modMac.writeClient)
                                                  ,vec(hostchan.mallocClient)
                                                  ,memServerInd
`ifdef DEBUG
                                                  ,memTestInd
                                                  ,mmuInd
`endif
                                                  );

   rule read_flow_id;
      let v <- toGet(ipv4Route.entry_added).get;
      indication.addEntryResp(v);
   endrule

   interface macRx = rxchan.macRx;
   interface macTx = txchan.macTx;
   interface writeServer = hostchan.writeServer;
   interface add_entry = ipv4Route.add_entry;
   interface delete_entry = ipv4Route.delete_entry;
   interface modify_entry = ipv4Route.modify_entry;
   method matchTableDbg = ipv4Route.mdbg;
   method memMgmtDbg = mem.dbg;
   method tdmDbg = sched.dbg;
   //method ringToMacDbg = txchan.dbg;
   method ActionValue#(PktBuffDbgRec) pktBuffDbg(Bit#(8) id);
      PktBuffDbgRec v = defaultValue;
      case (id) matches
         0: v = hostchan.dbg;
         1: v = txchan.dbg;
         2: v = rxchan.dbg;
      endcase
      return v;
   endmethod
endmodule
