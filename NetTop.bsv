// Copyright (c) 2014 Quanta Research Cambridge, Inc.

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
import Connectable       :: *;
import ClientServer      :: *;
import DefaultValue      :: *;
import PcieSplitter      :: *;
import Xilinx            :: *;
import Portal            :: *;
import Leds              :: *;
import ConfigCounter     :: *;
import Top               :: *;
import MemSlaveEngine    :: *;
import MemMasterEngine   :: *;
import PcieCsr           :: *;
import MemTypes          :: *;
import Bscan             :: *;
import PcieEndpointS5    :: *;
import PcieHost         :: *;
import HostInterface    :: *;
import ConnectalClocks    ::*;
import ALTERA_PLL_WRAPPER ::*;
import EthPorts           ::*;
import MasterSlave        ::*;
import Interconnect       ::*;

`ifndef DataBusWidth
`define DataBusWidth 64
`endif
`ifndef PinType
`define PinType Empty
`endif

typedef `PinType PinType;

`ifdef ALTERA
(* synthesize, no_default_clock, no_default_reset *)
(* clock_prefix="", reset_prefix="" *)
module mkNetTop #(Clock pcie_refclk_p, Clock osc_50_b3b, Reset pcie_perst_n) (PcieTop#(PinType));
`elsif VSIM
module mkNetTop #(Clock pcie_refclk_p, Clock osc_50_b3b, Reset pcie_perst_n) (PcieTop#(Pintype));
`endif

   Reset rst_50    <- mkResetInverter(pcie_perst_n, clocked_by osc_50_b3b);
   Reset rst_50_n  <- mkAsyncReset(1, pcie_perst_n, osc_50_b3b);
   B2C1 clk_125    <- mkB2C1(clocked_by osc_50_b3b, reset_by rst_50);
   B2C1 clk_156_25 <- mkB2C1(clocked_by osc_50_b3b, reset_by rst_50);
   Reset rst_156_n <- mkAsyncReset(1, pcie_perst_n, clk_156_25.c);

   PcieHostTop host <- mkPcieHostTop(pcie_refclk_p, osc_50_b3b, pcie_perst_n);
   Reset rst_250_n <- mkAsyncReset(1, pcie_perst_n, host.portalClock);

   PciePllWrap pll <- mkPciePllWrap(osc_50_b3b, rst_50, rst_50, clocked_by osc_50_b3b, reset_by rst_50);
   EthPortIfc ports <- mkEthPorts(osc_50_b3b, clk_156_25.c, rst_156_n, rst_156_n, clocked_by clk_156_25.c, reset_by rst_156_n);

   rule pll_clocks;
      clk_125.inputclock(pll.out.clk_0);
      clk_156_25.inputclock(pll.out.clk_1);
   endrule

   // ------------
   // Interconnect

   

   // --------
   // Leds
   Reg#(Bit#(1)) ledsReg <- mkReg(0, clocked_by osc_50_b3b, reset_by rst_50_n);
   ConfigCounter#(26) portal_led <- mkConfigCounter(0, clocked_by host.portalClock, reset_by rst_250_n);
   ConfigCounter#(26) pcie_led   <- mkConfigCounter(0, clocked_by pcie_refclk_p, reset_by pcie_perst_n);
   ConfigCounter#(26) mgmt_led   <- mkConfigCounter(0, clocked_by osc_50_b3b, reset_by rst_50_n);
   SyncBitIfc#(Bit#(1)) portal_led_sb <- mkSyncBit(host.portalClock, rst_250_n, osc_50_b3b);
   SyncBitIfc#(Bit#(1)) pcie_led_sb<- mkSyncBit(pcie_refclk_p, pcie_perst_n, osc_50_b3b);

   rule set_led1;
      mgmt_led.increment(1);
      ledsReg <= pack(mgmt_led.read())[25];
   endrule

   rule portal_led_cross;
      portal_led.increment(1);
      portal_led_sb.send(pack(portal_led.read())[25]);
   endrule

   rule pcie_led_cross;
      pcie_led.increment(1);
      pcie_led_sb.send(pack(pcie_led.read())[25]);
   endrule

//`ifdef IMPORT_HOSTIF
//   ConnectalTop#(PhysAddrWidth, DataBusWidth, PinType, NumberOfMasters) portalTop <- mkConnectalTop(host, clocked_by host.portalClock, reset_by host.portalReset);
//`else
//   ConnectalTop#(PhysAddrWidth, DataBusWidth, PinType, NumberOfMasters) portalTop <- mkConnectalTop(clocked_by host.portalClock, reset_by host.portalReset);
//`endif
//
//   mkConnection(host.tpciehost.master, portalTop.slave, clocked_by host.portalClock, reset_by host.portalReset);
//   if (valueOf(NumberOfMasters) > 0) begin
//      mapM(uncurry(mkConnection),zip(portalTop.masters, host.tpciehost.slave));
//   end
//
//   // going from level to edge-triggered interrupt
//   Vector#(16, Reg#(Bool)) interruptRequested <- replicateM(mkReg(False, clocked_by host.portalClock, reset_by host.portalReset));
//   rule interrupt_rule;
//     Maybe#(Bit#(4)) intr = tagged Invalid;
//     for (Integer i = 0; i < 16; i = i + 1) begin
//	 if (portalTop.interrupt[i] && !interruptRequested[i])
//             intr = tagged Valid fromInteger(i);
//	 interruptRequested[i] <= portalTop.interrupt[i];
//     end
//     if (intr matches tagged Valid .intr_num) begin
//        ReadOnly_MSIX_Entry msixEntry = host.tpciehost.msixEntry[intr_num];
//        host.tpciehost.interruptRequest.put(tuple2({msixEntry.addr_hi, msixEntry.addr_lo}, msixEntry.msg_data));
//     end
//   endrule
//
`ifndef BSIM
   interface pcie = host.tep7.pcie;
   method Bit#(NumLeds) leds();
      return {portal_led_sb.read, pcie_led_sb.read, ledsReg, 1'b0};
      //return portalTop.leds.leds();
   endmethod
   interface Clock deleteme_unused_clockLeds = osc_50_b3b; //host.tep7.epClock125;
//   interface pins = portalTop.pins;
`endif
endmodule
