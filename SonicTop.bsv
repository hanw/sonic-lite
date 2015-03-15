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
import ALTERA_PLL_644     :: *;
import EthPorts           :: *;
import Ethernet           :: *;
import LedTop             :: *;
import PinsTop            :: *;
import AlteraExtra        :: *;
import ALTERA_SI570_WRAPPER          ::*;
import ALTERA_EDGE_DETECTOR_WRAPPER  ::*;
import ALTERA_ETH_SONIC_PMA :: *;
import EthSonicPma :: *;

`ifndef DataBusWidth
`define DataBusWidth 64
`endif

`ifndef PinType
`define PinType Empty
`endif

typedef `PinType PinType;

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
                    Reset pcie_perst_n) (PcieTop#(PinType));

   // ===================================
   // PLL:
   // Input:    50MHz
   // Output0: 156.25MHz
   //
   // NOTE: input clock must be dedicated to PLL to avoid error:
   // Error (175020): Illegal constraint of fractional PLL to the region (x-coordinate, y- coordinate) to (x-coordinate, y-coordinate): no valid locations in region
   // ===================================
   //PcieHostTop host <- mkPcieHostTop(pcie_refclk_p, osc_50_b3b, pcie_perst_n);

   AltClkCtrl clk_50_b4a_buf <- mkAltClkCtrl(osc_50_b4a);
   Reset rst_50   <- mkResetInverter(pcie_perst_n, clocked_by clk_50_b4a_buf.outclk);
   Reset rst_50_n <- mkAsyncReset(2, pcie_perst_n, clk_50_b4a_buf.outclk);

   // ===================================
   // PLL:
   // Input:   156.25MHz
   // Output: 644MHz
   //
   // NOTE: input clock must be dedicated to PLL to avoid error:
   PLL156 pll156 <- mkPLL156(clk_50_b4a_buf.outclk, rst_50_n, clocked_by clk_50_b4a_buf.outclk, reset_by rst_50_n);
   Reset rst_156_n <- mkAsyncReset(1, pcie_perst_n, pll156.outclk, clocked_by pll156.outclk);
   //PLL644 pll644 <- mkPLL644(pll156.outclk, rst_156_n, clocked_by pll156.outclk, reset_by rst_156_n);

   // ===================================
   // PLL: SI570 configurable clock
   // Input:
   // Output:
   //
   Si570Wrap            si570 <- mkSi570Wrap(clk_50_b4a_buf.outclk, rst_50_n, clocked_by clk_50_b4a_buf.outclk, reset_by rst_50_n);
   EdgeDetectorWrap     edgedetect <- mkEdgeDetectorWrap(clk_50_b4a_buf.outclk, rst_50_n, clocked_by clk_50_b4a_buf.outclk, reset_by rst_50_n);

   rule si570_connections;
      //ifreq_mode = 3'b000;  //100.0 MHZ
      //ifreq_mode = 3'b001;  //125.0 MHZ
      //ifreq_mode = 3'b010;  //156.25.0 MHZ
      //ifreq_mode = 3'b011;  //250 MHZ
      //ifreq_mode = 3'b100;  //312.5 MHZ
      //ifreq_mode = 3'b101;  //322.26 MHZ
      //ifreq_mode = 3'b110;  //644.53125 MHZ
      si570.ifreq.mode(3'b110); //644.53125 MHZ
      si570.istart.go(edgedetect.odebounce.out);
   endrule

   //Eth10GPhyTopIfc    phy <- mkEth10GPhyTop(clk_50_b4a_buf.outclk, pll644.outclk, rst_50_n, clocked_by clk_50_b4a_buf.outclk, reset_by rst_50_n);
   //EthSonicPmaTopIfc pma <- mkEthSonicPmaTop(clk_50_b4a_buf.outclk, pll644.outclk, rst_50_n, clocked_by clk_50_b4a_buf.outclk, reset_by rst_50_n);

   NetTopIfc   nets <- mkNetTop(clk_50_b4a_buf.outclk, pll156.outclk, sfp_refclk, clocked_by pll156.outclk, reset_by rst_156_n);
   LedTopIfc   dbg <- mkLedTop(pcie_refclk_p, pcie_perst_n, clocked_by pcie_refclk_p, reset_by pcie_perst_n);

   ButtonIfc   btns <- mkButton(clocked_by clk_50_b4a_buf.outclk, reset_by rst_50_n);

   rule button_to_si570;
      edgedetect.itrigger.in(btns.out.getButton0());
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
//`ifndef BSIM
//   interface pcie = host.tep7.pcie;
////   method Bit#(NumLeds) leds();
////      return dbg.leds.leds();
////   endmethod
   interface Clock deleteme_unused_clockLeds = osc_50_b3b; //host.tep7.epClock125;
//   //interface pins = portalTop.pins;
   interface pins = interface PinsTopIfc;
      interface nets = nets;
      interface i2c =  si570.i2c;
      interface leds = dbg;
      interface buttons = btns.in;
      interface Clock clk_si570 = clk_50_b4a_buf.outclk;
      endinterface;
//`endif
endmodule
