// Copyright (c) 2015 Cornell University.

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

import BuildVector::*;
import DefaultValue::*;
import FIFOF::*;
import GetPut::*;
import StmtFSM::*;
import SpecialFIFOs::*;
import Vector::*;

import Ethernet::*;
import Utilities::*;

interface Parser;
   method Action startParse();
   method Action enqPacketData(EtherData b);
endinterface

typedef struct {
   Bit#(48) dst_mac;
   Bit#(48) src_mac;
   Bit#(16) ethertype;
} HeaderType_eth deriving(Bits, Eq);

instance DefaultValue#(HeaderType_eth);
   defaultValue =
   HeaderType_eth {
   dst_mac : 0,
   src_mac : 0,
   ethertype : 0
   };
endinstance

typedef struct {
   Bit#(4) version;
   Bit#(4) ihl;
   Bit#(8) tos;
   Bit#(16) len;
   Bit#(16) id;
   Bit#(3) flags;
   Bit#(13) frag;
   Bit#(8) ttl;
   Bit#(8) proto;
   Bit#(16) chksum;
   Bit#(32) ip_src;
   Bit#(32) ip_dst;
} HeaderType_ip deriving(Bits, Eq);

instance DefaultValue#(HeaderType_ip);
   defaultValue =
   HeaderType_ip {
   version : 0,
   ihl : 0,
   tos : 0,
   len : 0,
   id : 0,
   flags : 0,
   frag : 0,
   ttl : 0,
   proto : 0,
   chksum : 0,
   ip_src : 0,
   ip_dst : 0
   };
endinstance

(* synthesize *)
module mkParser(Parser);

   Reg#(Bit#(32)) cycle <- mkReg(0);
   Reg#(Bool) notStarted <- mkReg(False);

   FIFOF#(Bit#(128)) data_fifo_in  <- mkSizedFIFOF(1);
   FIFOF#(Bit#(16))  mac_fifo_out <- mkSizedFIFOF(1);
   FIFOF#(Bit#(16))  ip_fifo_out <- mkSizedFIFOF(1);
   FIFOF#(Bit#(128)) fifo_start_ethernet <- mkSizedFIFOF(1);

   Reg#(HeaderType_eth) reg_eth <- mkReg(defaultValue);
   Reg#(HeaderType_ip)  reg_ip  <- mkReg(defaultValue);

   rule every;
      cycle <= cycle + 1;
   endrule

   // One Stmt that says it all
   Stmt parseSeq =
   seq
   // Actions are pipelined
   action // mac
      let data <- toGet(data_fifo_in).get;
      Vector#(128, Bit#(1)) dataVec = unpack(data);

      Vector#(48, Bit#(1)) dst_mac = takeAt(0, dataVec);
      Vector#(48, Bit#(1)) src_mac = takeAt(48, dataVec);
      Vector#(16, Bit#(1)) ethertype = takeAt(96, dataVec);
      Vector#(16, Bit#(1)) remains = takeAt(112, dataVec);

      HeaderType_eth eth = defaultValue;
      eth.dst_mac = byteSwap(pack(dst_mac));
      eth.src_mac = byteSwap(pack(src_mac));
      eth.ethertype = byteSwap(pack(ethertype));
      reg_eth <= eth;

      mac_fifo_out.enq(pack(remains));
   endaction
   action
      let data_mac <- toGet(mac_fifo_out).get;
      let data_ip <- toGet(data_fifo_in).get;
      Bit#(144) data = {data_ip, data_mac};
      Vector#(144, Bit#(1)) dataVec = unpack(data);

      Vector#(4, Bit#(1)) version = takeAt(0, dataVec);
      Vector#(4, Bit#(1)) ihl = takeAt(4, dataVec);
      Vector#(8, Bit#(1)) tos = takeAt(8, dataVec);
      Vector#(16, Bit#(1)) tlen = takeAt(16, dataVec);
      Vector#(16, Bit#(1)) id = takeAt(32, dataVec);
      Vector#(3, Bit#(1)) flags = takeAt(48, dataVec);
      Vector#(13, Bit#(1)) frag = takeAt(51, dataVec);
      Vector#(8, Bit#(1)) ttl = takeAt(64, dataVec);
      Vector#(8, Bit#(1)) proto = takeAt(72, dataVec);
      Vector#(16, Bit#(1)) chksum= takeAt(80, dataVec);
      Vector#(32, Bit#(1)) ip_src= takeAt(96, dataVec);
      Vector#(16, Bit#(1)) remains= takeAt(128, dataVec);

      HeaderType_ip ip = defaultValue;
      ip.ip_src = byteSwap(pack(ip_src));
      reg_ip.ip_src <= ip.ip_src;

      ip_fifo_out.enq(pack(remains));
   endaction
   action
      let data_ip <- toGet(ip_fifo_out).get;
      let data_ip2 <- toGet(data_fifo_in).get;
      Bit#(144) data = {data_ip2, data_ip};
      Vector#(144, Bit#(1)) dataVec = unpack(data);

      Vector#(32, Bit#(1)) ip_dst = takeAt(0, dataVec);

      HeaderType_ip ip = defaultValue;
      ip.ip_dst = byteSwap(pack(ip_dst));

      reg_ip.ip_dst <= ip.ip_dst;
   endaction
   action
      $display("%d: extract dst mac %x", cycle, reg_eth.dst_mac);
      $display("%d: extract src mac %x", cycle, reg_eth.src_mac);
      $display("%d: extract type %x",    cycle, reg_eth.ethertype);
      $display("%d: extract src ip %x",  cycle, reg_ip.ip_src);
      $display("%d: extract dst ip %x",  cycle, reg_ip.ip_dst);
   endaction
   endseq;

   // control parsing FSM
   FSM parseFSM <- mkFSM(parseSeq);
   Once parseOnce <- mkOnce(parseFSM.start);

   rule parse_starts(notStarted);
      parseOnce.start;
      notStarted <= False;
   endrule

   method Action startParse();
      notStarted <= True;
   endmethod

   method Action enqPacketData(EtherData b);
      $display("enqueue packet data %x", b.data);
      data_fifo_in.enq(b.data);
   endmethod
endmodule

