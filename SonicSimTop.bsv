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
import ALTERA_PCIE_TB_WRAPPER ::*;
import AlteraExtra        ::*;
import AlteraPcieTestbench ::*;
import PS5LIB ::*;

`ifndef DataBusWidth
`define DataBusWidth 64
`endif

`ifndef PinType
`define PinType Empty
`endif

typedef `PinType PinType;

(* synthesize, no_default_clock, no_default_reset *)
module mkSonicSimTop (Empty);
   Clock clk_100Mhz   <- mkAbsoluteClock(5, 10);
   Clock clk_50Mhz    <- mkAbsoluteClock(5, 20);
   Reset reset_init   <- mkInitialReset(300, clocked_by clk_100Mhz);

   PcieS5HipTbPipe tb <- mkAlteraPcieTb(clocked_by clk_100Mhz, reset_by reset_init);
   PcieHostTop host <- mkPcieHostTop(clk_100Mhz, clk_50Mhz, reset_init);

   mkConnection(tb, host.tep7.pipe);

   rule simu_hip_ctrl;
      host.tep7.ctrl.simu_mode_pipe(1'b1); //1 for pipe mode
   endrule

`ifdef IMPORT_HOSTIF
   ConnectalTop#(PhysAddrWidth, DataBusWidth, PinType, NumberOfMasters) portalTop <- mkConnectalTop(host, clocked_by host.portalClock, reset_by host.portalReset);
`else
   ConnectalTop#(PhysAddrWidth, DataBusWidth, PinType, NumberOfMasters) portalTop <- mkConnectalTop(clocked_by host.portalClock, reset_by host.portalReset);
`endif

   mkConnection(host.tpciehost.master, portalTop.slave, clocked_by host.portalClock, reset_by host.portalReset);
   if (valueOf(NumberOfMasters) > 0) begin
      mapM(uncurry(mkConnection),zip(portalTop.masters, host.tpciehost.slave));
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
endmodule
