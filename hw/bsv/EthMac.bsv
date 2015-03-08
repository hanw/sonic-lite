
// Copyright (c) 2014 Cornell University.

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

package EthMac;

import Clocks::*;
import Vector::*;

import Ethernet::*;
import AvalonStreaming::*;

// 4-port 10GbE MAC Qsys wrapper
import ALTERA_MAC_WRAPPER::*;

`ifdef N_CHAN
typedef `N_CHAN N_CHAN;
`else
typedef 4 N_CHAN;
`endif

(* always_ready, always_enabled *)
interface EthMacAvalonSTIfc;
   interface AvalonPacketStreamSinkPhysicalIfc#(64) asi;
   interface AvalonPacketStreamSourcePhysicalIfc#(64) aso;
endinterface

(* always_ready, always_enabled *)
interface EthMacIfc#(numeric type np);
   interface Vector#(np, XGMII_MAC) xgmii;
   interface Vector#(np, EthMacAvalonSTIfc) avalon;
endinterface

(* synthesize *)
module mkEthMac#(Clock clk_50, Reset rst_50, Clock clk_156_25, Reset rst_156_25)(EthMacIfc#(4));
   Clock default_clock <- exposeCurrentClock;
   Reset default_reset <- exposeCurrentReset;

   MacWrap mac <- mkMacWrap(clk_50, clk_156_25, clk_156_25, clk_156_25, clk_156_25,
                                    clk_156_25, clk_156_25, clk_156_25, clk_156_25,
                            rst_50, rst_50,
                            rst_156_25, rst_156_25, rst_156_25, rst_156_25,
                            rst_156_25, rst_156_25, rst_156_25, rst_156_25,
                            rst_156_25, rst_156_25, rst_156_25, rst_156_25,
                            rst_156_25, rst_156_25, rst_156_25, rst_156_25);

   Vector#(N_CHAN, EthMacAvalonSTIfc) avalon_ifcs;
   for (Integer i=0; i<valueOf(N_CHAN); i=i+1) begin
      avalon_ifcs[i] = interface EthMacAvalonSTIfc;
         interface AvalonPacketStreamSourcePhysicalIfc aso;
            method stream_out_data;
               case(i)
                  0: return mac.p0_rx.fifo_out_data;
                  1: return mac.p1_rx.fifo_out_data;
                  2: return mac.p2_rx.fifo_out_data;
                  3: return mac.p3_rx.fifo_out_data;
               endcase
            endmethod

            method Action stream_out(Bool ready);
               case(i)
                  0: mac.p0_rx.fifo_out_ready(pack(ready));
                  1: mac.p1_rx.fifo_out_ready(pack(ready));
                  2: mac.p2_rx.fifo_out_ready(pack(ready));
                  3: mac.p3_rx.fifo_out_ready(pack(ready));
               endcase
            endmethod

            method stream_out_valid;
               case(i)
                  0: return unpack(mac.p0_rx.fifo_out_valid);
                  1: return unpack(mac.p1_rx.fifo_out_valid);
                  2: return unpack(mac.p2_rx.fifo_out_valid);
                  3: return unpack(mac.p3_rx.fifo_out_valid);
               endcase
            endmethod

//            method stream_out_empty;
//               case(i)
//                  0: return mac.p0_rx.fifo_out_empty;
//                  1: return mac.p1_rx.fifo_out_empty;
//                  2: return mac.p2_rx.fifo_out_empty;
//                  3: return mac.p3_rx.fifo_out_empty;
//               endcase
//            endmethod

//            method stream_out_error;
//               case(i)
//                  0: return unpack(mac.p0_rx.fifo_out_error[0]);
//                  1: return unpack(mac.p1_rx.fifo_out_error[0]);
//                  2: return unpack(mac.p2_rx.fifo_out_error[0]);
//                  3: return unpack(mac.p3_rx.fifo_out_error[0]);
//               endcase
//            endmethod

            method stream_out_startofpacket;
               case(i)
                  0: return unpack(mac.p0_rx.fifo_out_startofpacket);
                  1: return unpack(mac.p1_rx.fifo_out_startofpacket);
                  2: return unpack(mac.p2_rx.fifo_out_startofpacket);
                  3: return unpack(mac.p3_rx.fifo_out_startofpacket);
               endcase
            endmethod

            method stream_out_endofpacket;
               case(i)
                  0: return unpack(mac.p0_rx.fifo_out_endofpacket);
                  1: return unpack(mac.p1_rx.fifo_out_endofpacket);
                  2: return unpack(mac.p2_rx.fifo_out_endofpacket);
                  3: return unpack(mac.p3_rx.fifo_out_endofpacket);
               endcase
            endmethod
         endinterface

         interface AvalonPacketStreamSinkPhysicalIfc asi;
            method Action stream_in(Bit#(64) data, Bool valid, Bool startofpacket, Bool endofpacket);
               case(i)
                  0: mac.p0_tx.fifo_in_data(data);
                  1: mac.p1_tx.fifo_in_data(data);
                  2: mac.p2_tx.fifo_in_data(data);
                  3: mac.p3_tx.fifo_in_data(data);
               endcase

               case(i)
                  0: mac.p0_tx.fifo_in_valid(pack(valid));
                  1: mac.p1_tx.fifo_in_valid(pack(valid));
                  2: mac.p2_tx.fifo_in_valid(pack(valid));
                  3: mac.p3_tx.fifo_in_valid(pack(valid));
               endcase

               case(i)
                  0: mac.p0_tx.fifo_in_startofpacket(pack(startofpacket));
                  1: mac.p1_tx.fifo_in_startofpacket(pack(startofpacket));
                  2: mac.p2_tx.fifo_in_startofpacket(pack(startofpacket));
                  3: mac.p3_tx.fifo_in_startofpacket(pack(startofpacket));
               endcase

               case(i)
                  0: mac.p0_tx.fifo_in_endofpacket(pack(endofpacket));
                  1: mac.p1_tx.fifo_in_endofpacket(pack(endofpacket));
                  2: mac.p2_tx.fifo_in_endofpacket(pack(endofpacket));
                  3: mac.p3_tx.fifo_in_endofpacket(pack(endofpacket));
               endcase
            endmethod

            method stream_in_ready;
               case(i)
                  0: return unpack(mac.p0_tx.fifo_in_ready);
                  1: return unpack(mac.p1_tx.fifo_in_ready);
                  2: return unpack(mac.p2_tx.fifo_in_ready);
                  3: return unpack(mac.p3_tx.fifo_in_ready);
               endcase
            endmethod

//            method Action stream_in_empty(Bit#(3) v);
//               case(i)
//                  0: mac.p0_tx.fifo_in_empty(v);
//                  1: mac.p1_tx.fifo_in_empty(v);
//                  2: mac.p2_tx.fifo_in_empty(v);
//                  3: mac.p3_tx.fifo_in_empty(v);
//               endcase
//            endmethod

//            method Action stream_in_error(Bool v);
//               case(i)
//                  0: mac.p0_tx.fifo_in_error(pack(v));
//                  1: mac.p1_tx.fifo_in_error(pack(v));
//                  2: mac.p2_tx.fifo_in_error(pack(v));
//                  3: mac.p3_tx.fifo_in_error(pack(v));
//               endcase
//            endmethod
         endinterface
      endinterface;
   end

   Vector#(N_CHAN, XGMII_MAC) xgmii_ifcs;
   for (Integer i=0; i<valueOf(N_CHAN); i=i+1) begin
      xgmii_ifcs[i] = interface XGMII_MAC;
         interface XGMII_RX_MAC rx;
            method Action rx_dc(Bit#(72) v);
               case(i)
                  0: mac.p0_xgmii.rx_data(v);
                  1: mac.p1_xgmii.rx_data(v);
                  2: mac.p2_xgmii.rx_data(v);
                  3: mac.p3_xgmii.rx_data(v);
               endcase
            endmethod
         endinterface
         interface XGMII_TX_MAC tx;
            method Bit#(72) tx_dc;
               case(i)
                  0: return mac.p0_xgmii.tx_data;
                  1: return mac.p1_xgmii.tx_data;
                  2: return mac.p2_xgmii.tx_data;
                  3: return mac.p3_xgmii.tx_data;
               endcase
            endmethod
         endinterface
      endinterface;
   end

   interface avalon = avalon_ifcs;
   interface xgmii  = xgmii_ifcs;

endmodule: mkEthMac
endpackage: EthMac
