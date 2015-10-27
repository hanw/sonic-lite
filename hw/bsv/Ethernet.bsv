
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

import Vector ::*;
import DefaultValue          ::*;
import Connectable           ::*;
import Pipe                  ::*;

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

interface SerialIfc;
   (* prefix = "" , result = "tx_data" *)
   method Bit#(1) tx;
   (* prefix = "" *)
   method Action  rx ( (* port="rx_data" *) Bit#(1) v);
endinterface

interface LoopbackIfc;
   method Action lpbk_en(Bool en);
endinterface

interface SwitchIfc;
   method Action ena(Bool en);
endinterface

typedef struct {
   Bit#(53) ts_host;
   Bit#(53) ts_local_nic;
   Bit#(53) ts_global;
} LogUnit deriving (Bits);

interface DtpToPhyIfc;
   interface PipeOut#(Bit#(32)) delayOut;
   interface PipeOut#(Bit#(32)) stateOut;
   interface PipeOut#(Bit#(64)) jumpCount;
   interface PipeOut#(Bit#(53)) cLocalOut;
   interface PipeOut#(Bit#(53)) toHost;
   interface PipeIn#(Bit#(53))  fromHost;
   interface PipeIn#(Bit#(32))  interval;
   interface PipeOut#(Bit#(32)) dtpErrCnt;
endinterface

interface NetToConnectalIfc;
   interface PipeOut#(Bit#(128)) timestamp;
   interface PipeOut#(Bit#(53)) globalOut;
   interface PipeIn#(Bit#(1)) switchMode;
   interface Vector#(NumPorts, DtpToPhyIfc) phys;
endinterface

typedef struct {
   Bit#(3)  e; //event
   Bit#(53) t; //timestamp
} DtpEvent deriving (Eq, Bits, FShow);

typedef 12   PktAddrWidth;
typedef 128  PktDataWidth;
typedef 16   EtherLen;
typedef struct {
   Bool sop;
   Bool eop;
   Bit#(PktDataWidth) data;
} EtherData deriving (Eq, Bits);
instance FShow#(EtherData);
   function Fmt fshow (EtherData v);
      return ($format("sop=%x ", v.sop)
              + $format("eop=%x ", v.eop)
              + $format("data=%x", v.data));
   endfunction
endinstance

instance DefaultValue#(EtherData);
   defaultValue =
   EtherData {
   data : 0,
   sop : False,
   eop : False
   };
endinstance

typedef struct {
   Bit#(EtherLen) len;
} EtherReq deriving (Eq, Bits);

typedef struct {
   Bit#(PktAddrWidth) addr;
   EtherData          data;
} AddrTransRequest deriving (Eq, Bits);
instance FShow#(AddrTransRequest);
   function Fmt fshow (AddrTransRequest req);
      return ($format(" addr=0x%x ", req.addr)
              + $format(" data=0x%x ", req.data.data)
              + $format(" sop= %d ", req.data.sop)
              + $format(" eop= %d ", req.data.eop));
   endfunction
endinstance

interface SFPCtrl#(numeric type numPorts);
   method Action los(Bit#(numPorts) v);
   method Action mod0_presnt_n(Bit#(numPorts) v);
   // SCL/SDA not implemented
   method Bit#(numPorts) ratesel0();
   method Bit#(numPorts) ratesel1();
   method Bit#(numPorts) txdisable();
   method Action txfault(Bit#(numPorts) v);
endinterface

endpackage: Ethernet
