
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

package Ethernet;

import DefaultValue          ::*;
import Connectable           ::*;

`ifdef NUMBER_OF_10G_PORTS
typedef `NUMBER_OF_10G_PORTS NumPorts;
`else
typedef 4 NumPorts;
`endif

typedef 64 AVALON_DATA_WIDTH;
typedef 8  SYMBOL_SIZE;
typedef TLog#(AVALON_DATA_WIDTH) AVALON_EMPTY_WIDTH;

typedef struct {
   Bool                    sop;
   Bool                    eop;
   Bit#(1)                 err;
   Bit#(3)                 empty; //FIXME: use TLog and shift
   Bit#(dataT_width)       data;
   Bool                    valid;
} PacketData#(numeric type dataT_width) deriving (Bits, Eq);

typedef struct {
   Bit#(8)  data;
   Bit#(1)  control;
} XGMII_LANES deriving (Bits);

//typedef struct {
//   Vector#(8, Bit#(8)) data;
//   Vector#(8, Bit#(1)) control;
//} XGMII deriving (Bits);

instance DefaultValue#(PacketData#(n));
   defaultValue = 
   PacketData {
      sop : False,
      eop : False,
      err : 0,
      empty : 0,
      data : 0,
      valid : False
      };
endinstance

(* always_ready, always_enabled *)
interface XGMII_RX_PCS;                               // PCS provides to MAC
   method Bit#(72) rx_dc;
endinterface

(* always_ready, always_enabled *)
interface XGMII_TX_PCS;                               // PCS provides to MAC
   method Action tx_dc (Bit#(72) v);
endinterface

(* always_ready, always_enabled *)
interface XGMII_PCS; // top of PCS facing MAC
   interface XGMII_RX_PCS rx;
   interface XGMII_TX_PCS tx;
endinterface

(* always_ready, always_enabled *)
interface XGMII_RX_MAC;                               // MAC provides to PCS
   method Action rx_dc (Bit#(72) v);
endinterface

(* always_ready, always_enabled *)
interface XGMII_TX_MAC;                               // MAC provides to PCS
   method Bit#(72) tx_dc;
endinterface

(* always_ready, always_enabled *)
interface XGMII_MAC; // bottom of MAC facing PCS
   (* prefix = "" *)
   interface XGMII_RX_MAC rx;
   (* prefix = "" *)
   interface XGMII_TX_MAC tx;
endinterface

(* always_ready, always_enabled *)
interface XCVR_RX_PCS;                                // PCS provides to PMA
   method Action rx_ready ( (* port = "rx_ready" *)  Bit#(1) v);
   method Action rx_clkout( (* port = "rx_clkout" *) Bit#(1) v);
   method Action rx_data  ( (* port = "rx_data" *)   Bit#(40) v);
endinterface

(* always_ready, always_enabled *)
interface XCVR_TX_PCS;                                // PCS provides to PMA
   method Action tx_ready ( (* port = "tx_ready" *)  Bit#(1) v);
   method Action tx_clkout( (* port = "tx_clkout" *) Bit#(1) v);
   (* prefix = "", result = "tx_data" *)
   method Bit#(40) tx_data;
endinterface

(* always_ready, always_enabled *)
interface XCVR_PCS;  // bottom of PCS facing PMA
   (* prefix = "" *)
   interface XCVR_RX_PCS rx;
   (* prefix = "" *)
   interface XCVR_TX_PCS tx;
endinterface

//(* always_ready, always_enabled *)
//interface XCVR_RX_PMA;                                // PMA provides to PCS
//   (* prefix = "", result = "rx_ready" *)
//   method Bit#(1) rx_ready;
//   (* prefix = "", result = "rx_clkout" *)
////   method Bit#(1) rx_clkout;
//   method Bit#(1) rx_clkout;
//   (* prefix = "", result = "rx_data" *)
//   method Bit#(40) rx_data;
//endinterface
//
//(* always_ready, always_enabled *)
//interface XCVR_TX_PMA;                                // PMA provides to PCS
//   method Bit#(1) tx_ready;
////   method Bit#(1) tx_clkout;
//   method Bit#(1) tx_clkout;
//   (* prefix = "" *)
//   method Action tx_data( (* port = "tx_data" *) Bit#(40) v);
//endinterface

//(* always_ready, always_enabled *)
//interface XCVR_PMA; // top of PMA facing PCS
//   method Bool tx_ready;
//   method Clock tx_clkout;
//   method Action tx_data(Bit#(40) v);
//   method Bool rx_ready;
//   method Clock rx_clkout;
//   method Bit#(40) rx_data;
//endinterface

//instance Connectable#(XGMII_MAC, XGMII_PCS);
//   module mkConnection#(XGMII_MAC mac, XGMII_PCS pcs)(Empty);
//      rule connect_mac_pcs;
//         mac.rx.rx_dc(pcs.rx.rx_dc);
//         pcs.tx.tx_dc(mac.tx.tx_dc);
//      endrule
//   endmodule
//endinstance
//instance Connectable#(XGMII_PCS, XGMII_MAC);
//   module mkConnection#(XGMII_PCS pcs, XGMII_MAC mac)(Empty);
//      mkConnection(mac, pcs);
//   endmodule
//endinstance

//instance Connectable#(XCVR_PMA, XCVR_PCS);
//   module mkConnection#(XCVR_PMA pma, XCVR_PCS pcs)(Empty);
//      rule connect_pma_pcs;
//         pcs.rx.rx_data(pma.rx.rx_data);
//         pcs.rx.rx_clkout(pma.rx.rx_clkout);
//         pcs.tx.tx_clkout(pma.tx.tx_clkout);
//         pcs.tx.tx_ready(pma.tx.tx_ready);
//         pcs.rx.rx_ready(pma.rx.rx_ready);
//         pma.tx.tx_data(pcs.tx.tx_data);
//      endrule
//   endmodule
//endinstance
//instance Connectable#(XCVR_PCS, XCVR_PMA);
//   module mkConnection#(XCVR_PCS pcs, XCVR_PMA pma)(Empty);
//      mkConnection(pma, pcs);
//   endmodule
//endinstance

interface SerialIfc;
   (* prefix = "" , result = "tx_data" *)
   method Bit#(1) tx;
   (* prefix = "" *)
   method Action  rx ( (* port="rx_data" *) Bit#(1) v);
endinterface

interface LoopbackIfc;
   method Action lpbk_en(Bool en);
endinterface

endpackage: Ethernet
