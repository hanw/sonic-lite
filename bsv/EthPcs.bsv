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

package EthPcs;

import Clocks                  ::*;
import Vector                  ::*;
import Ethernet                ::*;

import ALTERA_ETH_PORT_WRAPPER       ::*;
import DTP_GLOBAL_TIMESTAMP_WRAPPER  ::*;

// TODO: implement encoding/decoding scrambling/descrambling in bsv.
`ifdef USE_4_CHANNELS
typedef 4 N_CHAN;
`elsif USE_2_CHANNELS
typedef 2 N_CHAN;
`endif

interface EthPcsIfc#(numeric type np);
   interface Vector#(np, XGMII_PCS) xgmii;
   interface Vector#(np, XCVR_PCS)  xcvr;
   interface Vector#(np, Vector#(32, Bit#(1)))  ctrl;
endinterface

(* synthesize *)
module mkEthPcs#(Clock clk_156_25, Reset rst_156_25)(EthPcsIfc#(N_CHAN));
   Clock defaultClock <- exposeCurrentClock;
   Reset defaultReset <- exposeCurrentReset;

   Vector#(4, EthPortWrap) pcs4 <- replicateM(mkEthPortWrap(clk_156_25, rst_156_25, rst_156_25));
   DtpGlobalWrap           dtpg <- mkDtpGlobalWrap(clk_156_25, rst_156_25, rst_156_25);

   rule cntrs;
      for (Integer i=0; i < valueOf(N_CHANNEL); i=i+1) begin
         pcs4[i].cntr.global_state(dtpg.timestamp.maximum);
      end
      dtpg.timestamp.p0(pcs4[0].cntr.local_state);
      dtpg.timestamp.p1(pcs4[1].cntr.local_state);
      dtpg.timestamp.p2(pcs4[2].cntr.local_state);
      dtpg.timestamp.p3(pcs4[3].cntr.local_state);
   endrule

   Vector#(N_CHAN, XGMII_PCS) xgmii_ifcs;
   for (Integer i=0; i < valueOf(N_CHAN); i=i+1) begin
      xgmii_ifcs[i] = interface XGMII_PCS;
      interface XGMII_RX_PCS rx;
         method Bit#(72) rx_dc;
            return pcs4[i].xgmii.rx_data;
         endmethod
      endinterface

      interface XGMII_TX_PCS tx;
         method Action tx_dc(Bit#(72) v);
            pcs4[i].xgmii.tx_data(v);
         endmethod
      endinterface
   endinterface;
   end

   Vector#(N_CHAN, XCVR_PCS) xcvr_ifcs;
   for (Integer i=0; i < valueOf(N_CHAN); i=i+1) begin
      xcvr_ifcs[i] = interface XCVR_PCS;
         interface XCVR_RX_PCS rx;
            method Action rx_ready(Bit#(1) v);
               pcs4[i].xcvr.rx_ready(v);
            endmethod
            method Action rx_clkout(Bit#(1) v);
               pcs4[i].xcvr.rx_clkout(v);
            endmethod
            method Action rx_data(Bit#(40) v);
               pcs4[i].xcvr.rx_datain(v);
            endmethod
         endinterface
         interface XCVR_TX_PCS tx;
            method Action tx_ready(Bit#(1) v);
               pcs4[i].xcvr.tx_ready(v);
            endmethod
            method Action tx_clkout(Bit#(1) v);
               pcs4[i].xcvr.tx_clkout(v);
            endmethod
            method Bit#(40) tx_data();
               return pcs4[i].xcvr.tx_dataout;
            endmethod
         endinterface
      endinterface;
   end

   Vector#(np, Vector#(32, Bit#(1))) ctrl_ifcs;
   for (Integer i=0; i < valueOf(N_CHAN); i=i+1) begin
      
   end

   interface xgmii = xgmii_ifcs;
   interface xcvr  = xcvr_ifcs;
endmodule
endpackage: EthPcs
