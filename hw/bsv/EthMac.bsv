
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
import Connectable                   ::*;
import Pipe                          ::*;
import FIFOF                         ::*;
import GetPut                        ::*;
import Pipe::*;
import DefaultValue::*;
import OInt::*;

import AlteraMacWrap::*;
import Ethernet::*;

interface EthMacIfc;
   (* always_ready, always_enabled *)
   method Bit#(72) tx;
   (* always_ready, always_enabled *)
   method Action rx (Bit#(72) v);
   interface Put#(PacketDataT#(64)) packet_tx;
   interface Get#(PacketDataT#(64)) packet_rx;
endinterface

typedef struct {
   Bit#(n) data;
   Bit#(TDiv#(n, 8)) mask;
   Bit#(1) sop;
   Bit#(1) eop;
} PacketDataT#(numeric type n) deriving (Bits,Eq);

instance DefaultValue#(PacketDataT#(64));
    defaultValue = PacketDataT {
        data : 0,
        mask : 0,
        sop : 0,
        eop : 0
    };
endinstance

// Mac Wrapper
(* synthesize *)
module mkEthMac#(Clock clk_50, Clock clk_156_25, Clock rx_clk, Reset rst_156_25_n)(EthMacIfc);
   Clock defaultClock <- exposeCurrentClock;
   Reset defaultReset <- exposeCurrentReset;

   Reset rx_rst_n <- mkAsyncReset(2, rst_156_25_n, rx_clk);
   Reset rst_50_n <- mkAsyncReset(2, defaultReset, clk_50);

   // Wire data_dw
   Wire#(Maybe#(Bit#(64))) tx_data_w <- mkDWire(tagged Invalid, clocked_by clk_156_25, reset_by rst_156_25_n);
   Wire#(Bit#(3)) tx_empty_w <- mkDWire(0, clocked_by clk_156_25, reset_by rst_156_25_n);
   Wire#(Bit#(1)) tx_ready_w <- mkDWire(0, clocked_by clk_156_25, reset_by rst_156_25_n);
   Wire#(Bit#(1)) tx_sop_w <- mkDWire(0, clocked_by clk_156_25, reset_by rst_156_25_n);
   Wire#(Bit#(1)) tx_eop_w <- mkDWire(0, clocked_by clk_156_25, reset_by rst_156_25_n);

   FIFOF#(PacketDataT#(64)) rx_fifo <- mkFIFOF(clocked_by rx_clk, reset_by rx_rst_n);

   MacWrap mac <- mkMacWrap(clk_50, clk_156_25, rx_clk, rst_50_n, rst_156_25_n, rx_rst_n, clocked_by clk_156_25, reset_by rst_156_25_n);

   rule tx_ready;
      tx_ready_w <= mac.tx.fifo_in_ready();
   endrule

   rule tx_data;
      mac.tx.fifo_in_data(fromMaybe(0,tx_data_w));
   endrule

   rule tx_sop;
      mac.tx.fifo_in_startofpacket(tx_sop_w);
   endrule

   rule tx_eop;
      mac.tx.fifo_in_endofpacket(tx_eop_w);
   endrule

   rule tx_empty;
      mac.tx.fifo_in_empty(tx_empty_w);
   endrule

   rule tx_error;
      mac.tx.fifo_in_error(1'b0);
   endrule

   rule tx_valid;
      mac.tx.fifo_in_valid(pack(isValid(tx_data_w)));
   endrule

   rule rx_data;
      let valid = mac.rx.fifo_out_valid();

      PacketDataT#(64) packet = defaultValue;
      packet.data = mac.rx.fifo_out_data();
      packet.sop = mac.rx.fifo_out_startofpacket();
      packet.eop = mac.rx.fifo_out_endofpacket();
      packet.mask = 1<<mac.rx.fifo_out_empty() - 1;

      if (valid == 1'b1) begin
         rx_fifo.enq(packet);
      end
   endrule

   rule rx_ready;
      mac.rx.fifo_out_ready(pack(rx_fifo.notFull));
   endrule

   method tx = mac.xgmii.tx_data;
   method Action rx(x) = mac.xgmii.rx_data(x);
   interface Put packet_tx;
      method Action put(PacketDataT#(64) d) if (tx_ready_w != 0);
         Bit#(3) tx_empty = truncate(pack(countOnes(maxBound-unpack(d.mask))));
         //Bit#(3) tx_empty = truncate(fromOInt(unpack(d.mask + 1)));
         tx_data_w <= tagged Valid pack(d.data);
         tx_empty_w <= tx_empty;
         tx_sop_w <= pack(d.sop);
         tx_eop_w <= pack(d.eop);
         //$display("tx_empty %h", tx_empty);
      endmethod
   endinterface
   interface Get packet_rx = toGet(rx_fifo);
endmodule
endpackage: EthMac
