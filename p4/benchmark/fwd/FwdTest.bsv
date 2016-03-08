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
import RxChannel::*;
import PaxosTypes::*;
import FwdAPI::*;
import FwdTypes::*;
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

interface FwdTest;
   interface FwdTestRequest request;
   interface `PinType pins;
endinterface
module mkFwdTest#(
      HostInterface host,
      FwdTestIndication indication
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
   TxChannel txchan <- mkTxChannel(txClock, txReset);
   RxChannel rxchan <- mkRxChannel(txClock, txReset);
   PaxosIngressPipeline ingress <- mkPaxosIngressPipeline(vec(hostchan.next, rxchan.next));

   SharedBuffer#(12, 128, 1) mem <- mkSharedBuffer(
      vec(txchan.readClient)
      ,vec(txchan.freeClient)
      ,vec(hostchan.writeClient, rxchan.writeClient, ingress.writeClient)
      ,vec(hostchan.mallocClient, rxchan.mallocClient)
      ,memServerInd
      );

   mkConnection(ingress.eventPktSend, txchan.eventPktSend);

`ifndef SIMULATION
   // process p0 -> p1
   mkConnection(txchan.macTx, mac[1].packet_tx);
   mkConnection(mac[0].packet_rx, rxchan.macRx);

   // bypass p1 -> p0
   mkConnection(mac[1].packet_rx, mac[0].packet_tx);
`else
   rule drainTx;
      let v <- txchan.macTx.get;
      $display("tx data %h %h %h %h", v.sop, v.eop, v.mask, v.data);
//`ifdef LOOPTEST
      rxchan.macRx.put(v);
//`endif
   endrule
`endif
   //P4Register#(InstanceSize, RoundSize) roundRegs <- mkP4RoundRegister(vec(roleTable.regAccess));
   //P4Register#(1, 8) roleRegs <- mkP4RoleRegister(vec(roundTable.regAccess));

   FwdAPI api <- mkFwdAPI(indication, ingress, hostchan, rxchan, txchan, mem);

   interface request = api.request;
`ifdef BOARD_nfsume
   interface `PinType pins = mk`PinType(defaultClock, phys, leds, sfpctrl);
`endif
endmodule: mkFwdTest
endpackage: FwdTest
