package FwdTest;

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
import HostChannel::*;
import HostInterface::*;
import MemTypes::*;
import MemServerIndication::*;
import MMUIndication::*;
import Paxos::*;
import PaxosIngressPipeline::*;
import PacketBuffer::*;
import SharedBuff::*;
import TxChannel::*;
import PaxosTypes::*;
import EthMac::*;

`ifdef SIMULATION
import Sims::*;
`endif

`ifdef BOARD_nfsume
import Xilinx10GE::*;
import XilinxMacWrap::*;
import XilinxEthPhy::*;
import NfsumePins::*;
`endif

typedef 12 PktSize; // maximum 4096b
typedef TDiv#(`DataBusWidth, 32) WordsPerBeat;

interface FwdTestIndication;
   method Action read_version_resp(Bit#(32) version);
//   method Action parsed_ipv4_resp(Bit#(8) ttl);
//   method Action parsed_vlan_resp();
//   method Action parsed_ether_resp(Bit#(48) srcAddr, Bit#(48) dstAddr);
endinterface

interface FwdTestRequest;
   method Action read_version();
   method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
endinterface

interface FwdTest;
   interface FwdTestRequest request;
   interface `PinType pins;
endinterface
module mkFwdTest#(HostInterface host, FwdTestIndication indication
                    ,ConnectalMemory::MemServerIndication memServerInd
                    )(FwdTest);
   let verbose = True;
   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

`ifdef SIMULATION
   SimClocks clocks <- mkSimClocks();
   Clock txClock = clocks.clock_156_25;
   Reset txReset <- mkSyncReset(2, defaultReset, txClock);
`endif
`ifdef BOARD_nfsume
   Clock mgmtClock = host.tsys_clk_200mhz_buf;
   Reset mgmtReset <- mkSyncReset(2, defaultReset, mgmtClock);
   EthPhyIfc phys <- mkXilinxEthPhy(mgmtClock);
   Clock txClock = phys.tx_clkout;
   Reset txReset <- mkSyncReset(2, defaultReset, txClock);
   Vector#(4, EthMacIfc) mac <- replicateM(mkEthMac(mgmtClock, txClock, txReset, clocked_by txClock, reset_by txReset));
   function Get#(XGMIIData) getTx(EthMacIfc _mac); return _mac.tx; endfunction
   function Put#(XGMIIData) getRx(EthMacIfc _mac); return _mac.rx; endfunction
   mapM(uncurry(mkConnection), zip(map(getTx, mac), phys.tx));
   mapM(uncurry(mkConnection), zip(phys.rx, map(getRx, mac)));
   NfsumeLeds leds <- mkNfsumeLeds(mgmtClock, txClock);
   NfsumeSfpCtrl sfpctrl <- mkNfsumeSfpCtrl(phys);
`endif

   HostChannel hostchan <- mkHostChannel();
   PaxosIngressPipeline ingress <- mkPaxosIngressPipeline(hostchan.next);
   TxChannel txchan <- mkTxChannel(txClock, txReset);
   SyncFIFOIfc#(EtherData) txSyncFifo <- mkSyncBRAMFIFO(6, txClock, txReset, defaultClock, defaultReset);

   SharedBuffer#(12, 128, 1) mem <- mkSharedBuffer(vec(txchan.readClient)
                                                  ,vec(txchan.freeClient)
                                                  ,vec(hostchan.writeClient, ingress.writeClient)
                                                  ,vec(hostchan.mallocClient)
                                                  ,memServerInd
                                                  );

   mkConnection(ingress.eventPktSend, txchan.eventPktSend);
   mkConnection(txchan.macTx, mac[0].packet_tx);
   //P4Register#(InstanceSize, RoundSize) roundRegs <- mkP4RoundRegister(vec(roleTable.regAccess));
   //P4Register#(1, 8) roleRegs <- mkP4RoleRegister(vec(roundTable.regAccess));

   interface FwdTestRequest request;
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
   endinterface
`ifdef BOARD_nfsume
   interface `PinType pins;
      method Action sfp(Bit#(1) refclk_p, Bit#(1) refclk_n);
         phys.refclk(refclk_p, refclk_n);
      endmethod
      method serial_tx_p = pack(phys.serial_tx_p);
      method serial_tx_n = pack(phys.serial_tx_n);
      method serial_rx_p = phys.serial_rx_p;
      method serial_rx_n = phys.serial_rx_n;
      interface leds = leds.led_out;
      interface led_grn = phys.tx_leds;
      interface led_ylw = phys.rx_leds;
      interface deleteme_unused_clock = defaultClock;
      interface sfpctrl = sfpctrl;
   endinterface
`endif
endmodule: mkFwdTest
endpackage: FwdTest
