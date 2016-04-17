package ParserTest;

import BRAMFIFO::*;
import BuildVector::*;
import Clocks::*;
import Connectable::*;
import DefaultValue::*;
import GetPut::*;
import ClientServer::*;
import StmtFSM::*;
import FIFO::*;
import FIFOF::*;
import Pipe::*;
import Vector::*;
import ConnectalMemory::*;

import Ethernet::*;
import PacketBuffer::*;
import MemTypes::*;
import MemServerIndication::*;
import MMUIndication::*;
import Paxos::*;
import SharedBuff::*;
import HostChannel::*;
import TxChannel::*;
import Ingress::*;
import Sims::*;
import PaxosTypes::*;
import ConnectalTypes::*;

typedef 12 PktSize; // maximum 4096b
typedef TDiv#(`DataBusWidth, 32) WordsPerBeat;


interface ParserTestIndication;
   method Action read_version_resp(Bit#(32) version);
//   method Action parsed_ipv4_resp(Bit#(8) ttl);
//   method Action parsed_vlan_resp();
//   method Action parsed_ether_resp(Bit#(48) srcAddr, Bit#(48) dstAddr);
endinterface

interface ParserTestRequest;
   method Action read_version();
   method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
   method Action roundReq(RoundRegRequest r);
   method Action roleReq(RoleRegRequest r);
   method Action sequenceTable_add_entry(Bit#(16) msgtype, SequenceTblActionT action_);
   method Action acceptorTable_add_entry(Bit#(16) msgtype, AcceptorTblActionT action_);
   //method Action dmacTable_add_entry(Bit#(48) mac, DmacTblActionT action_, Bit#(9) port_);
   method Action dmacTable_add_entry(Bit#(48) mac, Bit#(9) port_);
endinterface

interface ParserTest;
   interface ParserTestRequest request;
endinterface
module mkParserTest#(ParserTestIndication indication
                    ,ConnectalMemory::MemServerIndication memServerInd
                    )(ParserTest);
   let verbose = True;
   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();
   SimClocks clocks <- mkSimClocks();
   Clock txClock = clocks.clock_156_25;
   Reset txReset <- mkSyncReset(2, defaultReset, txClock);

   HostChannel hostchan <- mkHostChannel();
   Ingress ingress <- mkIngress(vec(hostchan.next));
   TxChannel txchan <- mkTxChannel(txClock, txReset);
   SyncFIFOIfc#(EtherData) txSyncFifo <- mkSyncBRAMFIFO(6, txClock, txReset, defaultClock, defaultReset);

   SharedBuffer#(12, 128, 1) mem <- mkSharedBuffer(vec(txchan.readClient)
                                                  ,vec(txchan.freeClient)
                                                  ,vec(hostchan.writeClient, ingress.writeClient)
                                                  ,vec(hostchan.mallocClient)
                                                  ,memServerInd
                                                  );

   mkConnection(ingress.eventPktSend, txchan.eventPktSend);

   interface ParserTestRequest request;
      method Action read_version();
         let v= `NicVersion;
         $display("read version");
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
      method roundReq = ingress.roundReq;
      method roleReq = ingress.roleReq;
      method sequenceTable_add_entry = ingress.sequenceTable_add_entry;
      method acceptorTable_add_entry = ingress.acceptorTable_add_entry;
      method dmacTable_add_entry = ingress.dmacTable_add_entry;
   endinterface
endmodule: mkParserTest
endpackage: ParserTest
