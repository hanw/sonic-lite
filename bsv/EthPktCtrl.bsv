
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

package EthPktCtrl;

import Clocks::*;
import GetPut::*;
import FIFOF::*;
import AvalonStreaming::*;
import Avalon2ClientServer::*;
import ALTERA_TRAFFIC_CONTROLLER_WRAPPER::*;

typedef 64 DataWidth;
typedef UInt#(32) AvalonWordT;

(* always_ready, always_enabled *)
interface EthPktCtrlIfc;
   interface AvalonPacketStreamSourcePhysicalIfc#(DataWidth) aso;
   interface AvalonPacketStreamSinkPhysicalIfc#(DataWidth) asi;
   interface AvalonSlaveIfc#(24) avs;
endinterface

(* synthesize *)
module mkEthPktCtrl#(Clock clk_156_25, Reset rst_156_25) (EthPktCtrlIfc);

   Clock defaultClock <- exposeCurrentClock;
   Reset defaultReset <- exposeCurrentReset;

   TrafficCtrlWrap pkt_gencap <- mkTrafficCtrlWrap(clk_156_25, rst_156_25, rst_156_25);

   interface AvalonPacketStreamSinkPhysicalIfc asi;
      method Bool stream_in_ready;
         return unpack(pkt_gencap.avl_st_rx.rdy);
      endmethod

      method Action stream_in(Bit#(DataWidth) data, Bool valid, Bool startofpacket, Bool endofpacket);
         pkt_gencap.avl_st_rx.sop(pack(startofpacket));
         pkt_gencap.avl_st_rx.eop(pack(endofpacket));
         pkt_gencap.avl_st_rx.val(pack(valid));
         pkt_gencap.avl_st_rx.data(pack(data));
      endmethod
   endinterface

   interface AvalonPacketStreamSourcePhysicalIfc aso;
      method Action stream_out(Bool ready);
         pkt_gencap.avl_st_tx.rdy(pack(ready));
      endmethod

      method Bit#(DataWidth) stream_out_data;
         return unpack(pkt_gencap.avl_st_tx.data);
      endmethod

      method Bool stream_out_valid;
         return unpack(pkt_gencap.avl_st_tx.val);
      endmethod

      method Bool stream_out_startofpacket;
         return unpack(pkt_gencap.avl_st_tx.sop);
      endmethod

      method Bool stream_out_endofpacket;
         return unpack(pkt_gencap.avl_st_tx.eop);
      endmethod
   endinterface

   interface AvalonSlaveIfc avs;
      method Action s0(UInt#(24) address, AvalonWordT writedata,
         Bool write, Bool read);
         pkt_gencap.avl_mm.baddress(pack(address));
         pkt_gencap.avl_mm.read(pack(read));
         pkt_gencap.avl_mm.write(pack(write));
         pkt_gencap.avl_mm.writedata(pack(writedata));
      endmethod

      method AvalonWordT s0_readdata;
         return unpack(pkt_gencap.avl_mm.readdata);
      endmethod

      method Bool s0_waitrequest;
         return unpack(pkt_gencap.avl_mm.waitrequest);
      endmethod
   endinterface
endmodule: mkEthPktCtrl
endpackage: EthPktCtrl
