
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

import AlteraMacWrap::*;
import Ethernet::*;

interface EthMacIfc;
   (* always_ready, always_enabled *)
   method Bit#(72) tx;
   (* always_ready, always_enabled *)
   method Action rx (Bit#(72) v);
   interface Put#(PacketDataT#(Bit#(64))) packet_tx; 
   interface Get#(PacketDataT#(Bit#(64))) packet_rx;
endinterface

//
// AvalonStreaming
// ===============
// 
// This library provides Bluespec wrappers for Altera's Avalon Streaming
// interface.
(* always_ready, always_enabled *)
interface AvalonStTx#(numeric type dataT_width);
   method Bit#(dataT_width) data;
   method Bool valid;
   method Action stream_out_ready(Bool ready);
   method Bool startofpacket;
   method Bool endofpacket;
endinterface

typedef struct {
   dataT d;  // data (generic)
   Bool sop; // start-of-packet marker
   Bool eop; // end-of-packet marker
} PacketDataT#(type dataT) deriving (Bits,Eq);

interface AvalonStTxVerboseIfc#(type dataT, numeric type dataT_width);
   interface Put#(PacketDataT#(dataT)) tx;
   interface AvalonStTx#(dataT_width) physical;
endinterface

typedef AvalonStTxVerboseIfc#(dataT,SizeOf#(dataT)) AvalonStTxIfc#(type dataT);

module mkPut2AvalonStTx(AvalonStTxVerboseIfc#(dataT,dataT_width))
   provisos(Bits#(dataT,dataT_width));

   Wire#(Maybe#(Bit#(dataT_width))) data_dw <- mkDWire(tagged Invalid);
   Wire#(Bool) ready_w <- mkBypassWire;
   Wire#(Bool) sop_dw <- mkDWire(False);
   Wire#(Bool) eop_dw <- mkDWire(False);

   interface Put tx;
      method Action put(PacketDataT#(dataT) d) if(ready_w);
         data_dw <= tagged Valid pack(d.d);
         sop_dw <= d.sop;
         eop_dw <= d.eop;
      endmethod
   endinterface

   interface AvalonStTx physical;
      method Bit#(dataT_width) data;
         return fromMaybe(0,data_dw);
      endmethod
      method Bool valid;
         return isValid(data_dw);
      endmethod
      method Action stream_out_ready(Bool ready);
         ready_w <= ready;
      endmethod
      method Bool startofpacket;
         return sop_dw;
      endmethod
      method Bool endofpacket;
         return eop_dw;
      endmethod
   endinterface
endmodule

(* always_ready, always_enabled *)
interface AvalonStRx#(type dataT_width);
   method Action stream_in(Bit#(dataT_width) data, Bool valid,
			   Bool startofpacket, Bool endofpacket);
   method Bool stream_in_ready;
endinterface

interface AvalonStRxVerboseIfc#(type dataT, numeric type dataT_width);
   interface Get#(PacketDataT#(dataT)) rx;
   interface AvalonStRx#(dataT_width) physical;
endinterface

typedef AvalonStRxVerboseIfc#(dataT,SizeOf#(dataT)) AvalonStRxIfc#(type dataT);

module mkAvalonStRx2Get(AvalonStRxVerboseIfc#(dataT,dataT_width))
provisos(Bits#(dataT,dataT_width));

   FIFOF#(PacketDataT#(dataT)) f <- mkLFIFOF;
   Wire#(Maybe#(PacketDataT#(dataT))) d_dw <- mkDWire(tagged Invalid);

   rule push_data_into_fifo (isValid(d_dw));
      f.enq(fromMaybe(?,d_dw));
   endrule

   interface Get rx = toGet(f);

   interface AvalonStRx physical;
      // method to receive data.  Note that the data should be held
      // until stream_in_ready is True, i.e. there is room in the internal
      // FIFO - f - so we should never loose data from our d_dw DWire
      method Action stream_in(Bit#(dataT_width) data, Bool valid, Bool startofpacket, Bool endofpacket);
         if(valid)
            d_dw <= tagged Valid PacketDataT{d:unpack(data), sop:startofpacket, eop:endofpacket};
      endmethod
      method Bool stream_in_ready;
         return f.notFull;
      endmethod
   endinterface
endmodule

// Mac Wrapper
(* synthesize *)
module mkEthMac#(Clock clk_50, Clock clk_156_25, Clock rx_clk, Reset rst_156_25_n)(EthMacIfc);
    Clock defaultClock <- exposeCurrentClock;
    Reset defaultReset <- exposeCurrentReset;

    Reset rx_rst <- mkAsyncReset(2, rst_156_25_n, rx_clk);
    Reset rst_50_n <- mkAsyncReset(2, defaultReset, clk_50);

    MacWrap mac <- mkMacWrap(clk_50, clk_156_25, rx_clk, rst_50_n, rst_156_25_n, rx_rst, clocked_by clk_156_25, reset_by rst_156_25_n);

    AvalonStTxIfc#(Bit#(64)) stream_out <- mkPut2AvalonStTx(clocked_by clk_156_25, reset_by rst_156_25_n);
    AvalonStRxIfc#(Bit#(64)) stream_in <- mkAvalonStRx2Get(clocked_by rx_clk, reset_by rx_rst);

    rule txFromPacketBuffer;
       mac.tx.fifo_in_data(stream_out.physical.data);
       mac.tx.fifo_in_endofpacket(pack(stream_out.physical.endofpacket));
       stream_out.physical.stream_out_ready(unpack(mac.tx.fifo_in_ready));
       mac.tx.fifo_in_startofpacket(pack(stream_out.physical.startofpacket));
       mac.tx.fifo_in_valid(pack(stream_out.physical.valid));
    endrule

    rule rxToPacketBuffer;
       stream_in.physical.stream_in(mac.rx.fifo_out_data,
          unpack(mac.rx.fifo_out_valid),
          unpack(mac.rx.fifo_out_startofpacket),
          unpack(mac.rx.fifo_out_endofpacket));
       mac.rx.fifo_out_ready(pack(stream_in.physical.stream_in_ready()));
    endrule

    method tx = mac.xgmii.tx_data;
    method Action rx(x) = mac.xgmii.rx_data(x);
    interface packet_tx = stream_out.tx;
    interface packet_rx = stream_in.rx;
endmodule
endpackage: EthMac
