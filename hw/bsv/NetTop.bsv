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
import Leds              :: *;
import ConfigCounter     :: *;
import PcieCsr           :: *;
import ConnectalClocks    ::*;
import ALTERA_PLL_WRAPPER ::*;
import EthPorts           ::*;
import Ethernet           ::*;
import Avalon2ClientServer ::*;
import ALTERA_SI570_WRAPPER          ::*;

`ifdef DataBusWidth
typedef `DataBusWidth DataBusWidth;
`else
typedef 64 DataBusWidth;
`endif

`ifdef NUMBER_OF_10G_PORTS
typedef `NUMBER_OF_10G_PORTS NumPorts;
`else
typedef 4 NumPorts;
`endif

interface NetExportIfc;
   interface Vector#(NumPorts, SerialIfc) serial;
   interface SfpCtrlIfc#(NumPorts) sfpctrl;
   interface Clock clk_net;
   interface Vector#(NumPorts, Clock) clk_xcvr;
   interface LoopbackIfc loopback;
   interface SwitchIfc switchctrl;
   interface Vector#(NumPorts, Bool) led_rx_ready;
endinterface

interface NetTopIfc;
   (* always_ready, always_enabled *)
   (* prefix="" *)
   interface NetExportIfc ifcs;
   (* prefix="" *)
   interface NetToConnectalIfc api;
endinterface

(* synthesize *)
(* clock_family = "default_clock, clk_156_25" *)
module mkNetTop #(Clock clk_50, Clock clk_156_25, Clock clk_644)(NetTopIfc);
   Clock defaultClock <- exposeCurrentClock;
   Reset defaultReset <- exposeCurrentReset;
   Reset rst_156_n <- mkAsyncReset(1, defaultReset, clk_156_25);

   EthPortIfc ports <- mkEthPorts(clk_50, clk_156_25, clk_644, clocked_by clk_156_25, reset_by rst_156_n);

   interface api = ports.api;
   interface ifcs = (interface NetExportIfc;
      interface loopback = ports.loopback;
      interface switchctrl = ports.switchctrl;
      interface sfpctrl = ports.sfpctrl;
      interface serial = ports.serial;
      interface Clock clk_net = clk_156_25;
      interface Clock clk_xcvr = ports.tx_clkout;
      interface led_rx_ready = ports.led_rx_ready;
   endinterface);
endmodule
