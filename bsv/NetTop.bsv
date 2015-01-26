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
import MasterSlave        ::*;
import Interconnect       ::*;

`ifndef DataBusWidth
`define DataBusWidth 64
`endif
`ifndef PinType
`define PinType Empty
`endif
`ifndef N_CHAN
`define N_CHAN 4
`endif

typedef `N_CHAN  N_CHAN;
typedef `PinType PinType;

(* always_ready, always_enabled *)
interface NetTopIfc;
   // avalon-mm interface to packet gencap
   interface Vector#(N_CHAN, SerialIfc) serial;
   interface Clock clk_net;
endinterface

(* synthesize, always_ready, always_enabled *)
(* clock_family = "default_clock, clk_156_25" *)
module mkNetTop #(Clock clk_50, Clock clk_156_25, Clock clk_644, Reset rst_156_n) (NetTopIfc);
   //EthPortIfc ports <- mkEthPorts(clk_50, clk_156_25, rst_156_n, rst_156_n, clocked_by clk_156_25, reset_by rst_156_n);
   EthPortIfc ports <- mkEthPorts(clk_50, clk_156_25, clk_644, rst_156_n, rst_156_n);

   interface serial = ports.serial;
   interface Clock clk_net = clk_156_25;
endmodule
