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

import Vector            :: *;
import Clocks            :: *;
import GetPut            :: *;
import FIFO              :: *;
import BRAMFIFO          :: *;
import Connectable       :: *;
import ClientServer      :: *;
import DefaultValue      :: *;
import PcieSplitter      :: *;
import Xilinx            :: *;
import Portal            :: *;
import Top               :: *;
import Leds              :: *;
import MemSlaveEngine    :: *;
import MemMasterEngine   :: *;
import PcieCsr           :: *;
import MemTypes          :: *;
import Bscan             :: *;
import PcieEndpointS5    :: *;
import PcieHost           :: *;
import NetTop             :: *;
import HostInterface      :: *;
import ConnectalClocks    :: *;
import ALTERA_PLL_156     :: *;
import EthPorts           :: *;
import Ethernet           :: *;
import LedTop             :: *;
import PinsTop            :: *;
import AlteraExtra        :: *;
import ConfigCounter      :: *;
import ALTERA_SI570_WRAPPER          ::*;
import ALTERA_EDGE_DETECTOR_WRAPPER  ::*;
import ALTERA_ETH_SONIC_PMA :: *;
import EthSonicPma :: *;
import SonicUser::*;
import Pipe::*;

`ifndef DataBusWidth
`define DataBusWidth 64
`endif

`ifndef PinType
`define PinType Empty
`endif

`define ENABLE_PCIE

typedef `PinType PinType;
typedef `ExportType ExportType;

(* synthesize, no_default_clock, no_default_reset *)
(* clock_prefix="", reset_prefix="" *)
module mkSonicTop #(Clock pcie_refclk_p,
                    Clock osc_50_b3b,
                    Clock osc_50_b3d,
                    Clock osc_50_b4a,
                    Clock osc_50_b4d,
                    Clock osc_50_b7a,
                    Clock osc_50_b7d,
                    Clock osc_50_b8a,
                    Clock osc_50_b8d,
                    Clock sfp_refclk,
                    Reset pcie_perst_n,
                    Reset user_reset_n) (PcieTop#(ExportType));

   // ===================================
   // PLL:
   // Input:    50MHz
   // Output0: 156.25MHz
   //
   // NOTE: input clock must be dedicated to PLL to avoid error:
   // Error (175020): Illegal constraint of fractional PLL to the region (x-coordinate, y- coordinate) to (x-coordinate, y-coordinate): no valid locations in region
   // ===================================
`ifdef ENABLE_PCIE
   PcieHostTop host <- mkPcieHostTop(pcie_refclk_p, osc_50_b3b, pcie_perst_n);

`ifdef IMPORT_HOSTIF
   ConnectalTop#(PhysAddrWidth, DataBusWidth, PinType, NumberOfMasters) portalTop <- mkConnectalTop(host, clocked_by host.portalClock, reset_by host.portalReset);
`else
   ConnectalTop#(PhysAddrWidth, DataBusWidth, PinType, NumberOfMasters) portalTop <- mkConnectalTop(clocked_by host.portalClock, reset_by host.portalReset);
`endif //IMPORT_HOSTIF
`endif //ENABLE_PCIE

   AltClkCtrl clk_50_b4a_buf <- mkAltClkCtrl(osc_50_b4a);
   Reset rst_50   <- mkResetInverter(user_reset_n, clocked_by clk_50_b4a_buf.outclk);
   Reset rst_50_n <- mkAsyncReset(2, user_reset_n, clk_50_b4a_buf.outclk);
   Reset rst_644   <- mkResetInverter(user_reset_n, clocked_by sfp_refclk);
   Reset rst_644_n <- mkAsyncReset(2, user_reset_n, sfp_refclk);

   // ==============
   // Button 0 is wired at top level to user_reset_n
   // Button 1 is used to reset si570.
   ButtonIfc   btns <- mkButton(clocked_by clk_50_b4a_buf.outclk, reset_by rst_50_n);

   // ===================================
   // PLL:
   // Input:   SFP REFCLK from SI570
   // Output:  156.25MHz
   // Reset: Active High, must invert default Reset
   PLL156 pll156 <- mkPLL156(sfp_refclk, rst_644, clocked_by sfp_refclk, reset_by rst_644);
   Clock clk_156_25 = pll156.outclk0;
   Reset rst_156   <- mkResetInverter(user_reset_n, clocked_by clk_156_25);
   Reset rst_156_n <- mkAsyncReset(1, user_reset_n, clk_156_25, clocked_by clk_156_25);

   // ===================================
   // PLL: SI570 configurable clock
   // Input:
   // Output:
   // Reset: Active Low, use default Reset
   Si570Wrap            si570 <- mkSi570Wrap(clk_50_b4a_buf.outclk, rst_50_n, clocked_by clk_50_b4a_buf.outclk, reset_by rst_50_n);
   EdgeDetectorWrap     edgedetect <- mkEdgeDetectorWrap(clk_50_b4a_buf.outclk, rst_50_n, clocked_by clk_50_b4a_buf.outclk, reset_by rst_50_n);

   // ========================
   // Switch[2:0] is used to configure si570
   //
   SwitchIfc   switches <- mkSwitch(clocked_by clk_50_b4a_buf.outclk, reset_by rst_50_n);

`ifdef ENABLE_PCIE
   // Reset from PCIe Command
   Reset rst_api <- mkSyncReset(0, portalTop.pins.rst, clk_156_25);
   Reset net_top_rst <- mkResetEither(rst_156_n, rst_api, clocked_by clk_156_25);
   NetTopIfc   eth <- mkNetTop(clk_50_b4a_buf.outclk, clk_156_25, sfp_refclk, clocked_by clk_156_25, reset_by net_top_rst); //rst_156_n);
`else
   NetTopIfc   eth <- mkNetTop(clk_50_b4a_buf.outclk, clk_156_25, sfp_refclk, clocked_by clk_156_25, reset_by rst_156_n);
`endif //ENABLE_PCIE

   rule si570_connections;
      //ifreq_mode = 3'b000;  //100.0 MHZ
      //ifreq_mode = 3'b001;  //125.0 MHZ
      //ifreq_mode = 3'b010;  //156.25.0 MHZ
      //ifreq_mode = 3'b011;  //250 MHZ
      //ifreq_mode = 3'b100;  //312.5 MHZ
      //ifreq_mode = 3'b101;  //322.26 MHZ
      let ifreq_mode = 3'b110;  //644.53125 MHZ
      si570.ifreq.mode(ifreq_mode);
      si570.istart.go(edgedetect.odebounce.out);
   endrule

   rule button_to_si570;
      edgedetect.itrigger.in(btns.out.getButton1());
   endrule

   SyncBitIfc#(Bit#(1)) sw_mode_net <- mkSyncBit(clk_50_b4a_buf.outclk, rst_50_n, eth.ifcs.clk_net);
   rule read_sw2_to_net;
      sw_mode_net.send(switches.out.getSwitch2);
   endrule
   rule send_isSwitch_to_NetTop;
      eth.ifcs.switchctrl.ena(unpack(sw_mode_net.read));
   endrule

   SyncBitIfc#(Bit#(1)) sw_mode_portal <- mkSyncBit(clk_50_b4a_buf.outclk, rst_50_n, host.portalClock);
   rule read_sw2_to_portal;
      sw_mode_portal.send(switches.out.getSwitch2);
   endrule
   rule send_isSwitch_to_PortalTop;
      portalTop.pins.isSwitch.enq(unpack(sw_mode_portal.read));
   endrule

   // ===========
   // LED Outputs
   Reset sfp_reset_n <- mkAsyncReset(2, user_reset_n, sfp_refclk);
   Reset xcvr_reset_n <- mkAsyncReset(2, user_reset_n, eth.ifcs.clk_xcvr[0]);

   Reg#(Bit#(26)) pcie_cntr <- mkReg(0, clocked_by pcie_refclk_p, reset_by pcie_perst_n);
   rule heartbeat_pcie;
      pcie_cntr <= pcie_cntr + 1;
   endrule

   Reg#(Bit#(26)) net_cntr <- mkReg(0, clocked_by clk_156_25, reset_by rst_156_n);
   rule heartbeat_net;
      net_cntr <= net_cntr + 1;
   endrule

   Reg#(Bit#(26)) xcvr_cntr <- mkReg(0, clocked_by eth.ifcs.clk_xcvr[0], reset_by xcvr_reset_n);
   rule heartbeat_xcvr;
      xcvr_cntr <= xcvr_cntr + 1;
   endrule

   Reg#(Bit#(26)) si570_cntr <- mkReg(0, clocked_by sfp_refclk, reset_by sfp_reset_n);
   rule heartbeat_si570;
      si570_cntr <= si570_cntr + 1;
   endrule

   Reg#(Bit#(20)) led_rx_ready_cnt0 <- mkReg(0, clocked_by clk_50_b4a_buf.outclk, reset_by rst_50_n);
   Reg#(Bit#(20)) led_rx_ready_cnt1 <- mkReg(0, clocked_by clk_50_b4a_buf.outclk, reset_by rst_50_n);
   Reg#(Bit#(20)) led_rx_ready_cnt2 <- mkReg(0, clocked_by clk_50_b4a_buf.outclk, reset_by rst_50_n);
   Reg#(Bit#(20)) led_rx_ready_cnt3 <- mkReg(0, clocked_by clk_50_b4a_buf.outclk, reset_by rst_50_n);

   rule rx_ready0 (!eth.ifcs.led_rx_ready[0]);
      led_rx_ready_cnt0 <= led_rx_ready_cnt0 + 1;
   endrule
   rule rx_ready1 (!eth.ifcs.led_rx_ready[1]);
      led_rx_ready_cnt1 <= led_rx_ready_cnt1 + 1;
   endrule
   rule rx_ready2 (!eth.ifcs.led_rx_ready[2]);
      led_rx_ready_cnt2 <= led_rx_ready_cnt2 + 1;
   endrule
   rule rx_ready3 (!eth.ifcs.led_rx_ready[3]);
      led_rx_ready_cnt3 <= led_rx_ready_cnt3 + 1;
   endrule

`ifdef ENABLE_PCIE
   mkConnection(host.tpciehost.master, portalTop.slave, clocked_by host.portalClock, reset_by host.portalReset);
   if (valueOf(NumberOfMasters) > 0) begin
      mapM(uncurry(mkConnection),zip(portalTop.masters, host.tpciehost.slave));
   end

   // mkConnection between net and portalTop
   SyncFIFOIfc#(Bit#(128)) tsFifo <- mkSyncFIFO(8, clk_156_25, rst_156_n, host.portalClock);
   PipeOut#(Bit#(128)) txFifoPipeOut = toPipeOut(tsFifo);
   PipeIn#(Bit#(128)) txFifoPipeIn = toPipeIn(tsFifo);
   mkConnection(eth.api.timestamp, txFifoPipeIn);
   mkConnection(txFifoPipeOut, portalTop.pins.timestamp);

   // send log data from host to network
   Vector#(4, SyncFIFOIfc#(Bit#(53))) fromHostFifo <- replicateM(mkSyncFIFO(8, host.portalClock, host.portalReset, clk_156_25));
   Vector#(4, PipeOut#(Bit#(53))) fromHostPipeOut = map(toPipeOut,fromHostFifo);
   Vector#(4, PipeIn#(Bit#(53))) fromHostPipeIn = map(toPipeIn,fromHostFifo);
   for (Integer i=0; i<4; i=i+1) begin
      mkConnection(portalTop.pins.fromHost[i], fromHostPipeIn[i]);
      mkConnection(fromHostPipeOut[i], eth.api.phys[i].fromHost);
   end

   // send log data from network to host
   Vector#(4, SyncFIFOIfc#(Bit#(53))) toHostFifo <- replicateM(mkSyncFIFO(8, clk_156_25, rst_156_n, host.portalClock));
   Vector#(4, PipeOut#(Bit#(53))) toHostPipeOut = map(toPipeOut, toHostFifo);
   Vector#(4, PipeIn#(Bit#(53))) toHostPipeIn = map(toPipeIn, toHostFifo);
   for (Integer i=0; i<4; i=i+1) begin
      mkConnection(eth.api.phys[i].toHost, toHostPipeIn[i]);
      mkConnection(toHostPipeOut[i], portalTop.pins.toHost[i]);
   end

   // send delay measurement to host
   Vector#(4, SyncFIFOIfc#(Bit#(32))) delayFifo <- replicateM(mkSyncFIFO(8, clk_156_25, rst_156_n, host.portalClock));
   Vector#(4, PipeOut#(Bit#(32))) delayPipeOut = map(toPipeOut, delayFifo);
   Vector#(4, PipeIn#(Bit#(32))) delayPipeIn = map(toPipeIn, delayFifo);
   for (Integer i=0; i<4; i=i+1) begin
      mkConnection(eth.api.phys[i].delayOut, delayPipeIn[i]);
      mkConnection(delayPipeOut[i], portalTop.pins.delay[i]);
   end

   // send dtp state to host
   Vector#(4, SyncFIFOIfc#(Bit#(32))) stateFifo <- replicateM(mkSyncFIFO(8, clk_156_25, rst_156_n, host.portalClock));
   Vector#(4, PipeOut#(Bit#(32))) statePipeOut = map(toPipeOut, stateFifo);
   Vector#(4, PipeIn#(Bit#(32))) statePipeIn = map(toPipeIn, stateFifo);
   for (Integer i=0; i<4; i=i+1) begin
      mkConnection(eth.api.phys[i].stateOut, statePipeIn[i]);
      mkConnection(statePipeOut[i], portalTop.pins.state[i]);
   end

   // send dtp error count to host
   Vector#(4, SyncFIFOIfc#(Bit#(64))) jumpCountFifo <- replicateM(mkSyncFIFO(8, clk_156_25, rst_156_n, host.portalClock));
   Vector#(4, PipeOut#(Bit#(64))) jumpCountPipeOut = map(toPipeOut, jumpCountFifo);
   Vector#(4, PipeIn#(Bit#(64))) jumpCountPipeIn = map(toPipeIn, jumpCountFifo);
   for (Integer i=0; i<4; i=i+1) begin
      mkConnection(eth.api.phys[i].jumpCount, jumpCountPipeIn[i]);
      mkConnection(jumpCountPipeOut[i], portalTop.pins.jumpCount[i]);
   end

   // send dtp clocal to host
   Vector#(4, SyncFIFOIfc#(Bit#(53))) cLocalFifo <- replicateM(mkSyncFIFO(8, clk_156_25, rst_156_n, host.portalClock));
   Vector#(4, PipeOut#(Bit#(53))) cLocalPipeOut = map(toPipeOut, cLocalFifo);
   Vector#(4, PipeIn#(Bit#(53))) cLocalPipeIn = map(toPipeIn, cLocalFifo);
   for (Integer i=0; i<4; i=i+1) begin
      mkConnection(eth.api.phys[i].cLocalOut, cLocalPipeIn[i]);
      mkConnection(cLocalPipeOut[i], portalTop.pins.cLocal[i]);
   end

   // send dtp cglobal to host
   SyncFIFOIfc#(Bit#(53)) cGlobalFifo <- mkSyncFIFO(8, clk_156_25, rst_156_n, host.portalClock);
   PipeOut#(Bit#(53)) cGlobalPipeOut = toPipeOut(cGlobalFifo);
   PipeIn#(Bit#(53)) cGlobalPipeIn = toPipeIn(cGlobalFifo);
   mkConnection(eth.api.globalOut, cGlobalPipeIn);
   mkConnection(cGlobalPipeOut, portalTop.pins.globalOut);

   // set interval
   Vector#(4, SyncFIFOIfc#(Bit#(32))) intervalFifo <- replicateM(mkSyncFIFO(8, host.portalClock, host.portalReset, clk_156_25));
   Vector#(4, PipeOut#(Bit#(32))) intervalPipeOut = map(toPipeOut,intervalFifo);
   Vector#(4, PipeIn#(Bit#(32))) intervalPipeIn = map(toPipeIn,intervalFifo);
   for (Integer i=0; i<4; i=i+1) begin
      mkConnection(portalTop.pins.interval[i], intervalPipeIn[i]);
      mkConnection(intervalPipeOut[i], eth.api.phys[i].interval);
   end

   // send dtp rcvd err count
   Vector#(4, SyncFIFOIfc#(Bit#(32))) dtpErrCntFifo <- replicateM(mkSyncFIFO(8, clk_156_25, rst_156_n, host.portalClock));
   Vector#(4, PipeOut#(Bit#(32))) dtpErrCntPipeOut = map(toPipeOut, dtpErrCntFifo);
   Vector#(4, PipeIn#(Bit#(32))) dtpErrCntPipeIn = map(toPipeIn, dtpErrCntFifo);
   for (Integer i=0; i<4; i=i+1) begin
      mkConnection(eth.api.phys[i].dtpErrCnt, dtpErrCntPipeIn[i]);
      mkConnection(dtpErrCntPipeOut[i], portalTop.pins.dtpErrCnt[i]);
   end


   // going from level to edge-triggered interrupt
   Vector#(16, Reg#(Bool)) interruptRequested <- replicateM(mkReg(False, clocked_by host.portalClock, reset_by host.portalReset));
   rule interrupt_rule;
     Maybe#(Bit#(4)) intr = tagged Invalid;
     for (Integer i = 0; i < 16; i = i + 1) begin
	 if (portalTop.interrupt[i] && !interruptRequested[i])
             intr = tagged Valid fromInteger(i);
	 interruptRequested[i] <= portalTop.interrupt[i];
     end
     if (intr matches tagged Valid .intr_num) begin
        ReadOnly_MSIX_Entry msixEntry = host.tpciehost.msixEntry[intr_num];
        host.tpciehost.interruptRequest.put(tuple2({msixEntry.addr_hi, msixEntry.addr_lo}, msixEntry.msg_data));
     end
   endrule
`endif //ENABLE_PCIE

`ifndef BSIM
`ifdef ENABLE_PCIE
   interface pcie = host.tep7.pcie;
`endif
   interface pins = (interface PinsTopIfc;
      interface eth  = eth.ifcs;
      interface i2c  = si570.i2c;
      interface led0 = pcie_cntr[25];
      interface led1 = net_cntr[25];
      interface led2 = xcvr_cntr[25];
      interface led3 = si570_cntr[25];
      interface led_bracket = {led_rx_ready_cnt3[19], led_rx_ready_cnt2[19], led_rx_ready_cnt1[19], led_rx_ready_cnt0[19]};
      interface buttons  = btns.in;
      interface switches = switches.in;
      interface Clock clk_b4a = clk_50_b4a_buf.outclk;
   endinterface);
//`endif
endmodule
