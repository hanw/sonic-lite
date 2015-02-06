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
import PcieHost         :: *;
import HostInterface    :: *;
import ConnectalClocks    ::*;
import ALTERA_PLL_WRAPPER ::*;
import EthPorts           ::*;
import Ethernet           ::*;
import LedTop             ::*;
import NetTop             ::*;
import AlteraExtra        ::*;
import ALTERA_PCIE_DMA_WRAP ::*;
import Avalon2ClientServer ::*;

`ifndef DataBusWidth
`define DataBusWidth 64
`endif
`ifndef PinType
`define PinType Empty
`endif

`ifdef PCIE_LANES
typedef `PCIE_LANES PcieLanes;
`else
typedef 8 PcieLanes;
`endif

typedef `PinType PinType;

(* always_ready, always_enabled *)
interface PciewrapPci_exp#(numeric type lanes);
(* prefix="", result="tx_p" *) method Bit#(lanes) tx_p();
(* prefix="", result="rx_p" *) method Action rx_p(Bit#(lanes) rx_p);
endinterface

(* always_ready, always_enabled *)
interface PcieS5NetAvm;
    method Bit#(26)               address();
    method Bit#(1)                read();
    method Bit#(1)                write();
    method Bit#(32)               writedata();
    method Action                 readdata(Bit#(32) v);
    method Action                 waitrequest(Bit#(1) v);
endinterface

(* always_ready, always_enabled *)
interface PcieS5DDR3Mem;
    method Bit#(14)               mem_a()     ;
    method Bit#(3)                mem_ba()    ;
    method Bit#(1)                mem_cas_n() ;
    method Bit#(1)                mem_ck()    ;
    method Bit#(1)                mem_ck_n()  ;
    method Bit#(1)                mem_cke()   ;
    method Bit#(1)                mem_cs_n()  ;
    method Bit#(8)                mem_dm()    ;
    method Bit#(1)                mem_odt()   ;
    method Bit#(1)                mem_ras_n() ;
    method Bit#(1)                mem_reset_n();
    method Bit#(1)                mem_we_n()  ;
    interface Inout#(Bit#(64))    mem_dq      ;
    interface Inout#(Bit#(8))     mem_dqs     ;
    interface Inout#(Bit#(8))     mem_dqs_n   ;
endinterface

(* always_ready, always_enabled *)
interface PciedmawrapOct;
    method Action      rzqin(Bit#(1) v);
endinterface

(* always_ready, always_enabled *)
interface PcieDmaTop;
   interface PciewrapPci_exp#(PcieLanes) pcie;
   interface PcieS5DDR3Mem ddr;
   interface PciedmawrapOct rzqin;
   interface AvalonMasterIfc#(24) avm;
   interface Clock core_clk;
endinterface

(* always_ready, always_enabled *)
interface SonicTop;
   (* prefix = "PCIE" *)
   interface PciewrapPci_exp#(8) pcie;
   (* always_ready *)
   method Bit#(NumLeds) leds();
   (* prefix = "DDR" *)
   interface PcieS5DDR3Mem ddr3;
   interface PciedmawrapOct rzqin;
   (* prefix = "Net" *)
   interface Vector#(N_CHAN, SerialIfc) serial;
   interface Clock deleteme_unused_clockLeds;
   interface Clock deleteme_unused_clockNets;
endinterface


module vmkPcieDmaTop#(Clock clk_100MHz, Clock clk_50MHz, Clock clk_156MHz, Reset perst_n)(PcieDmaTop);
   Reset rst_100_n <- mkAsyncReset(2, perst_n, clk_100MHz);
   Vector#(8, Wire#(Bit#(1))) rx_in_wires <- replicateM(mkDWire(0, clocked_by clk_100MHz, reset_by rst_100_n));

   Reset rst_50_n <- mkAsyncReset(3, perst_n, clk_50MHz);

   PcieDmaWrap pcie_ep <- mkPcieDmaWrap(clk_50MHz, clk_156MHz, clk_100MHz, noReset(), noReset(), noReset(), perst_n, perst_n, perst_n, clocked_by clk_100MHz, reset_by rst_100_n);

   (* no_implicit_conditions *)
   rule pcie_rx;
      pcie_ep.hip_serial.rx_in0(rx_in_wires[0]);
      pcie_ep.hip_serial.rx_in1(rx_in_wires[1]);
      pcie_ep.hip_serial.rx_in2(rx_in_wires[2]);
      pcie_ep.hip_serial.rx_in3(rx_in_wires[3]);
      pcie_ep.hip_serial.rx_in4(rx_in_wires[4]);
      pcie_ep.hip_serial.rx_in5(rx_in_wires[5]);
      pcie_ep.hip_serial.rx_in6(rx_in_wires[6]);
      pcie_ep.hip_serial.rx_in7(rx_in_wires[7]);
   endrule

   interface PciewrapPci_exp pcie;
      method Bit#(PcieLanes) tx_p();
         Vector#(8, Bit#(1)) ret_val;
         ret_val[0] = pcie_ep.hip_serial.tx_out0;
         ret_val[1] = pcie_ep.hip_serial.tx_out1;
         ret_val[2] = pcie_ep.hip_serial.tx_out2;
         ret_val[3] = pcie_ep.hip_serial.tx_out3;
         ret_val[4] = pcie_ep.hip_serial.tx_out4;
         ret_val[5] = pcie_ep.hip_serial.tx_out5;
         ret_val[6] = pcie_ep.hip_serial.tx_out6;
         ret_val[7] = pcie_ep.hip_serial.tx_out7;
         return pack(ret_val);
      endmethod
      method Action rx_p(Bit#(PcieLanes) v);
         action
            writeVReg(rx_in_wires, unpack(v));
         endaction
      endmethod
   endinterface

   interface PciedmawrapOct rzqin;
      method Action rzqin(Bit#(1) v);
         pcie_ep.oct.rzqin(v);
      endmethod
   endinterface

   interface PcieS5DDR3Mem ddr;
      method Bit#(14) mem_a();
         return pcie_ep.memory.mem_a();
      endmethod
      method Bit#(3) mem_ba();
         return pcie_ep.memory.mem_ba();
      endmethod
      method Bit#(1) mem_cas_n();
         return pcie_ep.memory.mem_cas_n();
      endmethod
      method Bit#(1) mem_ck();
         return pcie_ep.memory.mem_ck();
      endmethod
      method Bit#(1) mem_ck_n();
         return pcie_ep.memory.mem_ck_n();
      endmethod
      method Bit#(1) mem_cke();
         return pcie_ep.memory.mem_cke();
      endmethod
      method Bit#(1) mem_cs_n();
         return pcie_ep.memory.mem_cs_n();
      endmethod
      method Bit#(8) mem_dm();
         return pcie_ep.memory.mem_dm();
      endmethod
      method Bit#(1) mem_odt();
         return pcie_ep.memory.mem_odt();
      endmethod
      method Bit#(1) mem_ras_n();
         return pcie_ep.memory.mem_ras_n();
      endmethod
      method Bit#(1) mem_reset_n();
         return pcie_ep.memory.mem_reset_n();
      endmethod
      method Bit#(1) mem_we_n();
         return pcie_ep.memory.mem_we_n();
      endmethod
      interface mem_dq = pcie_ep.memory.mem_dq;
      interface mem_dqs = pcie_ep.memory.mem_dqs;
      interface mem_dqs_n = pcie_ep.memory.mem_dqs_n;
   endinterface

   interface AvalonMasterIfc avm;
      method Action m0(AvalonWordT readdata, Bool waitrequest);
         action
            pcie_ep.net_avm.readdata(pack(readdata));
            pcie_ep.net_avm.waitrequest(pack(waitrequest));
         endaction
      endmethod
      method AvalonWordT m0_writedata();
         return unpack(pcie_ep.net_avm.writedata);
      endmethod
      method UInt#(TAdd#(2, word_address_width)) m0_address 
         provisos (Bits#(UInt#(TAdd#(2, word_address_width)), 26));
         return unpack(pcie_ep.net_avm.address);
      endmethod
      method Bool m0_read;
         return unpack(pcie_ep.net_avm.read);
      endmethod
      method Bool m0_write;
         return unpack(pcie_ep.net_avm.write);
      endmethod
   endinterface

   interface core_clk = pcie_ep.core.clk_clk;
endmodule

(* no_default_clock, no_default_reset *)
module vmkSonicTop #(Clock pcie_refclk_p, Clock osc_50_b3b, Reset pcie_perst_n) (SonicTop);
   Reset reset_high <- mkResetInverter(pcie_perst_n, clocked_by pcie_refclk_p);
   Reset rst_50   <- mkResetInverter(pcie_perst_n, clocked_by osc_50_b3b);
   Reset rst_50_n <- mkAsyncReset(1, pcie_perst_n, osc_50_b3b);
   PLL156 pll_156 <- mkPLL156(osc_50_b3b, rst_50);

   Reset rst_156 <- mkAsyncReset(1, reset_high, pll_156.outclk_0);
   Reset rst_156_n <- mkAsyncReset(1, pcie_perst_n, pll_156.outclk_0);
   PLL644 pll_644 <- mkPLL644(pll_156.outclk_0, rst_156);

   //PcieHostTop host <- mkPcieHostTop(pcie_refclk_p, osc_50_b3b, pcie_perst_n);
   PcieDmaTop host <- vmkPcieDmaTop(pcie_refclk_p, osc_50_b3b, pll_156.outclk_0, pcie_perst_n);

   Reset rst_app_n  <- mkResetInverter(pcie_perst_n, clocked_by host.core_clk);
   NetTopIfc   nets <- mkNetTop(osc_50_b3b, pll_156.outclk_0, pll_644.outclk_0, host.core_clk, rst_156_n, rst_156_n, clocked_by pll_156.outclk_0, reset_by rst_156_n);
   LedTopIfc   dbg  <- mkLedTop(pll_156.outclk_0, rst_156_n, clocked_by pll_156.outclk_0, reset_by rst_156_n);

   Reset rst_250_n <- mkAsyncReset(1, pcie_perst_n, host.core_clk);
   mkConnection(host.avm, nets.avs, clocked_by pll_156.outclk_0, reset_by rst_156_n);

`ifndef BSIM
   interface pcie = host.pcie;
   interface ddr3 = host.ddr;
   interface serial = nets.serial;
   interface rzqin = host.rzqin;

   method Bit#(NumLeds) leds();
      return dbg.leds.leds();
   endmethod
   interface Clock deleteme_unused_clockLeds = osc_50_b3b; //host.tep7.epClock125;
   interface Clock deleteme_unused_clockNets = nets.clk_net;
`endif
endmodule

(* synthesize, no_default_clock, no_default_reset *)
(* clock_prefix="", reset_prefix="" *)
module mkSonicTop #(Clock pcie_refclk_p, Clock osc_50_b3b, Reset pcie_perst_n) (SonicTop);
   SonicTop _a <- vmkSonicTop(pcie_refclk_p, osc_50_b3b, pcie_perst_n);
   return _a;
endmodule
