
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

/*-
 * Copyright (c) 2011 Simon W. Moore
 * All rights reserved.
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-10-C-0237
 * ("CTSRD"), as part of the DARPA CRASH research programme.
 *
 * @BERI_LICENSE_HEADER_START@
 *
 * Licensed to BERI Open Systems C.I.C. (BERI) under one or more contributor
 * license agreements.  See the NOTICE file distributed with this work for
 * additional information regarding copyright ownership.  BERI licenses this
 * file to you under the BERI Hardware-Software License, Version 1.0 (the
 * "License"); you may not use this file except in compliance with the
 * License.  You may obtain a copy of the License at:
 *
 *   http://www.beri-open-systems.org/legal/license-1-0.txt
 *
 * Unless required by applicable law or agreed to in writing, Work distributed
 * under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations under the License.
 *
 * @BERI_LICENSE_HEADER_END@
 *
 *****************************************************************************/

package EthMac;

import Clocks::*;
import Vector::*;
import Connectable                   ::*;
import Pipe                          ::*;
import FIFOF                         ::*;
import GetPut                        ::*;
import Pipe::*;

import Ethernet::*;

// 4-port 10GbE MAC Qsys wrapper
import ALTERA_MAC_WRAPPER::*;

`ifdef NUMBER_OF_10G_PORTS
typedef `NUMBER_OF_10G_PORTS NumPorts;
`else
typedef 4 NumPorts;
`endif

//(* always_ready, always_enabled *)
interface EthMacIfc;
   interface Vector#(NumPorts, PipeOut#(Bit#(72))) tx; //XGMII
   interface Vector#(NumPorts, PipeIn#(Bit#(72))) rx;  //XGMII
   interface Vector#(NumPorts, Put#(PacketDataT#(Bit#(64)))) packet_tx; 
   interface Vector#(NumPorts, Get#(PacketDataT#(Bit#(64)))) packet_rx;
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
module mkEthMac#(Clock clk_50, Clock clk_156_25, Vector#(4, Clock) rx_clk, Reset rst_156_25_n)(EthMacIfc);
    Vector#(NumPorts, FIFOF#(Bit#(72))) txFifo = newVector;
    Vector#(NumPorts, FIFOF#(Bit#(72))) rxFifo = newVector;
    Vector#(NumPorts, Reset) rx_rst = newVector;
    Clock defaultClock <- exposeCurrentClock;
    Reset defaultReset <- exposeCurrentReset;

    for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
       rx_rst[i] <- mkAsyncReset(2, rst_156_25_n, rx_clk[i]);
    end
    Reset rst_50_n <- mkAsyncReset(2, defaultReset, clk_50);
    MacWrap mac <- mkMacWrap(clk_50, clk_156_25, rx_clk, rx_rst, rst_50_n, rst_156_25_n, clocked_by clk_156_25, reset_by rst_156_25_n);

    Vector#(NumPorts, AvalonStTxIfc#(Bit#(64))) stream_out <- replicateM(mkPut2AvalonStTx(clocked_by clk_156_25, reset_by rst_156_25_n));
    Vector#(NumPorts, AvalonStRxIfc#(Bit#(64))) stream_in = newVector;
    for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
       stream_in[i] <- mkAvalonStRx2Get(clocked_by rx_clk[i], reset_by rx_rst[i]);
    end

    for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
       rule txFromPacketBuffer;
         case(i)
            0: begin
               mac.p0_tx.fifo_in_data(stream_out[0].physical.data);
               mac.p0_tx.fifo_in_endofpacket(pack(stream_out[0].physical.endofpacket));
               stream_out[0].physical.stream_out_ready(unpack(mac.p0_tx.fifo_in_ready));
               mac.p0_tx.fifo_in_startofpacket(pack(stream_out[0].physical.startofpacket));
               mac.p0_tx.fifo_in_valid(pack(stream_out[0].physical.valid));
            end
            1: begin
               mac.p1_tx.fifo_in_data(stream_out[1].physical.data);
               mac.p1_tx.fifo_in_endofpacket(pack(stream_out[1].physical.endofpacket));
               stream_out[1].physical.stream_out_ready(unpack(mac.p1_tx.fifo_in_ready));
               mac.p1_tx.fifo_in_startofpacket(pack(stream_out[1].physical.startofpacket));
               mac.p1_tx.fifo_in_valid(pack(stream_out[1].physical.valid));
            end
            2: begin
               mac.p2_tx.fifo_in_data(stream_out[2].physical.data);
               mac.p2_tx.fifo_in_endofpacket(pack(stream_out[2].physical.endofpacket));
               stream_out[2].physical.stream_out_ready(unpack(mac.p2_tx.fifo_in_ready));
               mac.p2_tx.fifo_in_startofpacket(pack(stream_out[2].physical.startofpacket));
               mac.p2_tx.fifo_in_valid(pack(stream_out[2].physical.valid));
            end
            3: begin
               mac.p3_tx.fifo_in_data(stream_out[3].physical.data);
               mac.p3_tx.fifo_in_endofpacket(pack(stream_out[3].physical.endofpacket));
               stream_out[3].physical.stream_out_ready(unpack(mac.p3_tx.fifo_in_ready));
               mac.p3_tx.fifo_in_startofpacket(pack(stream_out[3].physical.startofpacket));
               mac.p3_tx.fifo_in_valid(pack(stream_out[3].physical.valid));
            end
         endcase
       endrule
    end

    for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
      rule rxToPacketBuffer;
         case(i)
            0: begin
               stream_in[0].physical.stream_in(mac.p0_rx.fifo_out_data,
                                               unpack(mac.p0_rx.fifo_out_valid),
                                               unpack(mac.p0_rx.fifo_out_startofpacket),
                                               unpack(mac.p0_rx.fifo_out_endofpacket));
               mac.p0_rx.fifo_out_ready(pack(stream_in[0].physical.stream_in_ready()));
            end
            1: begin
               stream_in[1].physical.stream_in(mac.p1_rx.fifo_out_data,
                                               unpack(mac.p1_rx.fifo_out_valid),
                                               unpack(mac.p1_rx.fifo_out_startofpacket),
                                               unpack(mac.p1_rx.fifo_out_endofpacket));
               mac.p1_rx.fifo_out_ready(pack(stream_in[1].physical.stream_in_ready));
            end
            2: begin
               stream_in[2].physical.stream_in(mac.p2_rx.fifo_out_data,
                                               unpack(mac.p2_rx.fifo_out_valid),
                                               unpack(mac.p2_rx.fifo_out_startofpacket),
                                               unpack(mac.p2_rx.fifo_out_endofpacket));
               mac.p2_rx.fifo_out_ready(pack(stream_in[2].physical.stream_in_ready));
            end
            3: begin
               stream_in[3].physical.stream_in(mac.p3_rx.fifo_out_data,
                                               unpack(mac.p3_rx.fifo_out_valid),
                                               unpack(mac.p3_rx.fifo_out_startofpacket),
                                               unpack(mac.p3_rx.fifo_out_endofpacket));
               mac.p3_rx.fifo_out_ready(pack(stream_in[3].physical.stream_in_ready));
            end
         endcase
      endrule
    end

    for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
       txFifo[i] <- mkFIFOF(clocked_by clk_156_25, reset_by rst_156_25_n);
       rxFifo[i] <- mkFIFOF(clocked_by rx_clk[i], reset_by rx_rst[i]);

       rule receive;
          let v <- toGet(rxFifo[i]).get;
          case(i)
             0: mac.p0_xgmii.rx_data(v);
             1: mac.p1_xgmii.rx_data(v);
             2: mac.p2_xgmii.rx_data(v);
             3: mac.p3_xgmii.rx_data(v);
          endcase
       endrule
    end

    for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
       rule transmit;
          case(i)
             0: txFifo[0].enq(mac.p0_xgmii.tx_data);
             1: txFifo[1].enq(mac.p1_xgmii.tx_data);
             2: txFifo[2].enq(mac.p2_xgmii.tx_data);
             3: txFifo[3].enq(mac.p3_xgmii.tx_data);
          endcase
       endrule
    end

    function Put#(PacketDataT#(Bit#(64))) mtx(Integer i) = stream_out[i].tx;
    function Get#(PacketDataT#(Bit#(64))) mrx(Integer i) = stream_in[i].rx;

    interface tx = map(toPipeOut, txFifo);
    interface rx = map(toPipeIn, rxFifo);
    interface packet_tx = map(mtx, genVector);
    interface packet_rx = map(mrx, genVector);
endmodule

endpackage: EthMac
