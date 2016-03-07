
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
typedef 10   PktAddrWidth;
typedef 128  PktDataWidth;
typedef 16   EtherLen;

// little endianess
typedef struct {
   Bool                    sop;
   Bool                    eop;
   Bit#(1)                 err;
   Bit#(3)                 empty; //FIXME: use TLog and shift
   Bit#(dataT_width)       data;
   Bool                    valid;
} PacketData#(numeric type dataT_width) deriving (Bits, Eq);
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
   interface Vector#(NumPorts, PipeOut#(PcsDbgRec)) tx_dbg;
   interface Vector#(NumPorts, PipeOut#(PcsDbgRec)) rx_dbg;
endinterface

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

typedef struct {
   Bit#(3)  e; //event
   Bit#(53) t; //timestamp
} DtpEvent deriving (Eq, Bits, FShow);

// Big-endianess
typedef struct {
   Bit#(PktDataWidth) data;
   Bit#(TDiv#(PktDataWidth, 8)) mask;
   Bool sop;
   Bool eop;
} EtherData deriving (Eq, Bits);
instance FShow#(EtherData);
   function Fmt fshow (EtherData v);
      return ($format("sop=%x ", v.sop)
              + $format("eop=%x ", v.eop)
              + $format("mask=%x ", v.mask)
              + $format("data=%x", v.data));
   endfunction
endinstance
instance DefaultValue#(EtherData);
   defaultValue =
   EtherData {
   data : 0,
   mask : 0,
   sop : False,
   eop : False
   };
endinstance

typedef struct {
   Bit#(EtherLen) len;
} EtherReq deriving (Eq, Bits);

typedef struct {
   Bit#(64) bytes;
   Bit#(64) starts;
   Bit#(64) ends;
   Bit#(64) errorframes;
   Bit#(64) frames;
} PcsDbgRec deriving (Bits, Eq);

// ===========================
// Shared Packet Memory Types
// ===========================
typedef 32 MaxNumPkts; // Maximum in-flight packet in pipeline
typedef Bit#(TLog#(MaxNumPkts)) PktId;
typedef struct {
   PktId id;
   Bit#(EtherLen) size;
} PacketInstance deriving(Bits, Eq);

endpackage: Ethernet
