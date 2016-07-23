// Copyright (c) 2016 Cornell University.

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

import BUtils::*;
import ClientServer::*;
import Connectable::*;
import CBus::*;
import ConfigReg::*;
import DbgDefs::*;
import DefaultValue::*;
import Ethernet::*;
import EthMac::*;
import GetPut::*;
import FIFOF::*;
import MemMgmt::*;
import MemTypes::*;
import MIMO::*;
import Pipe::*;
import PacketBuffer::*;
import PrintTrace::*;
import StoreAndForward::*;
import SpecialFIFOs::*;
import SharedBuff::*;

import `DEPARSER::*;
import `TYPEDEF::*;

interface HeaderSerializer;
   interface PktWriteServer writeServer;
   interface PktWriteClient writeClient;
   method Action set_verbosity(int verbosity);
endinterface

typedef TDiv#(PktDataWidth, 8) MaskWidth;
typedef TLog#(PktDataWidth) DataSize;
typedef TLog#(TDiv#(PktDataWidth, 8)) MaskSize;

module mkHeaderSerializer(HeaderSerializer);
   Reg#(int) cf_verbosity <- mkConfigRegU;
   function Action dbg3(Fmt msg);
      action
         if (cf_verbosity > 3) begin
            $display("(%0d) ", $time, msg);
         end
      endaction
   endfunction
   FIFOF#(EtherData) data_in_ff <- printTimedTraceM("serializer in", mkFIFOF);
   FIFOF#(EtherData) data_out_ff <- printTimedTraceM("serializer out", mkFIFOF);
   Reg#(Bool) sop_buff <- mkReg(False);
   Reg#(Bool) eop_buff <- mkReg(False);
   Reg#(UInt#(TAdd#(MaskSize, 1))) prev_bytes <- mkReg(0);
   Reg#(UInt#(TAdd#(DataSize, 1))) prev_bits <- mkReg(0);

   let sop_this_cycle = data_in_ff.first.sop;
   let eop_this_cycle = data_in_ff.first.eop;
   let data_this_cycle = data_in_ff.first.data;
   let mask_this_cycle = data_in_ff.first.mask;

   Array#(Reg#(Bool)) inPacket <- mkCReg(2, False);
   Array#(Reg#(Bool)) startOfPacket <- mkCReg(2, False);
   Array#(Reg#(Bool)) endOfPacket <- mkCReg(2, False);
   Array#(Reg#(Bit#(PktDataWidth))) data_buff <- mkCReg(2, 0);
   Array#(Reg#(Bit#(MaskWidth))) mask_buff <- mkCReg(2, 0);
   Reg#(Bit#(PktDataWidth)) prev_data <- mkReg(0);
   Reg#(Bit#(MaskWidth)) prev_mask <- mkReg(0);
   Array#(Reg#(Bool)) new_data <- mkCReg(2, False);

   function Bit#(max) create_mask (LUInt#(max) count);
      Bit#(max) v = (1 << count) - 1;
      return v;
   endfunction

   rule rl_enqueue_stage1;
      data_in_ff.deq;
      if (sop_this_cycle) begin
         inPacket[0] <= True;
         startOfPacket[0] <= True;
      end
      if (eop_this_cycle) begin
         endOfPacket[0] <= True;
      end
      data_buff[0] <= data_this_cycle;
      mask_buff[0] <= mask_this_cycle;
      new_data[0] <= True;
      dbg3($format("*** stage1 %h %h %h %h", data_this_cycle, mask_this_cycle, sop_this_cycle, eop_this_cycle));
   endrule

   /*
   function Bit#(l) read_data (UInt#(8) lhs, UInt#(8) rhs)
      provisos (Add#(a__, l, 128));
      Bit#(l) ldata = truncate(data_buff[1]) << fromInteger(valueOf(l) - lhs);
      Bit#(l) rdata = truncate(prev_data >> fromInteger(valueOf(l) - rhs));
      Bit#(l) cdata = ldata | rdata;
      return cdata;
   endfunction
   */

   // function for computing bits received;

   // function for computing

   rule rl_enqueue_in_packet if (inPacket[1] && !endOfPacket[1] && new_data[1]);
      dbg3($format("mask size %d", countOnes(mask_buff[1])));
      let curr_bytes = countOnes(mask_buff[1]);
      UInt#(TAdd#(DataSize, 1)) curr_bits = cExtend(curr_bytes) << 3;
      let total_bytes = curr_bytes + cExtend(prev_bytes);
      if (total_bytes > 16) begin
         let data = data_buff[1] << prev_bits | prev_data; 
         let shift_in_bytes = 16 - prev_bytes;
         UInt#(TAdd#(DataSize, 1)) shift_in_bits = cExtend((16 - prev_bytes)) << 3;
         dbg3($format("prev_data %h prev_bytes %d additional data %h", prev_data, prev_bytes, data_buff[1] << prev_bits));
         let next_data = data_buff[1] >> shift_in_bits;
         let next_mask = mask_buff[1] >> shift_in_bytes;
         prev_data <= next_data;
         prev_mask <= next_mask;
         prev_bytes <= curr_bytes - shift_in_bytes;
         prev_bits <= curr_bits - shift_in_bits;
         startOfPacket[1] <= False;
         EtherData eth = defaultValue;
         eth.sop = startOfPacket[1];
         eth.eop = False;
         eth.mask = 'hffff;
         eth.data = data;
         data_out_ff.enq(eth);
      end
      else begin
         let data = (data_buff[1] << prev_bits) | prev_data;
         let mask = (mask_buff[1] << prev_bytes) | prev_mask;
         let offset_in_bytes = curr_bytes + prev_bytes;
         UInt#(TAdd#(DataSize, 1)) offset_in_bits = cExtend(offset_in_bytes) << 3;
         prev_data <= data;
         prev_mask <= mask;
         prev_bytes <= offset_in_bytes;
         prev_bits <= offset_in_bits;
         new_data[1] <= False;
         dbg3($format("2.GGoffset %d curr_bytes %d next_data %h next_mask %h", offset_in_bytes, curr_bytes, data, mask));
         dbg3($format("GG 2 out %h %h", data, mask));
      end
   endrule

   rule rl_enqueue_last_beat if (inPacket[1] && endOfPacket[1] && new_data[1]);
      let curr_bytes = countOnes(mask_buff[1]);
      UInt#(TAdd#(DataSize, 1)) curr_bits = cExtend(curr_bytes) << 3;
      let total_bytes = curr_bytes + cExtend(prev_bytes);
      dbg3($format("prev_bytes %d curr_bytes %d", prev_bytes, curr_bytes));
      if (total_bytes > 16) begin
         let data = data_buff[1] << prev_bits | prev_data; 
         let shift_in_bytes = 16 - prev_bytes;
         UInt#(TAdd#(DataSize, 1)) shift_in_bits = cExtend((16 - prev_bytes)) << 3;
         let next_data = data_buff[1] >> shift_in_bits;
         let next_mask = mask_buff[1] >> shift_in_bytes;
         prev_data <= next_data;
         prev_mask <= next_mask;
         prev_bytes <= curr_bytes - shift_in_bytes;
         prev_bits <= curr_bits - shift_in_bits;
         dbg3($format("GGlast beat, shift and save %h next bytes %d", data_buff[1], curr_bytes - shift_in_bytes));
         EtherData eth = defaultValue;
         eth.sop = False;
         eth.eop = False;
         eth.mask = 'hffff;
         eth.data = data;
         dbg3($format("GG out %h", data));
         data_out_ff.enq(eth);
      end
      else begin
         dbg3($format("GGlast beat, done %h", data_buff[1]));
         inPacket[1] <= False;
         new_data[1] <= False;
         EtherData eth = defaultValue;
         eth.sop = False;
         eth.eop = True;
         eth.mask = prev_mask;
         eth.data = prev_data;
         dbg3($format("GG out %h %h", prev_data, prev_mask));
         data_out_ff.enq(eth);
      end
   endrule

   interface PktWriteServer writeServer;
      interface writeData = toPut(data_in_ff);
   endinterface
   interface PktWriteClient writeClient;
      interface writeData = toGet(data_out_ff);
   endinterface
   method Action set_verbosity(int verbosity);
      cf_verbosity <= verbosity;
   endmethod
endmodule

// Encapsulate Egress Pipeline, Tx Ring
interface TxChannel;
   interface MemReadClient#(`DataBusWidth) readClient;
   interface MemFreeClient freeClient;
   interface Server#(MetadataRequest, MetadataResponse) prev;
   interface Get#(PacketDataT#(64)) macTx;
   method TxChannelDbgRec read_debug_info;
   method DeparserPerfRec read_deparser_perf_info;
   method Action set_verbosity (int verbosity);
endinterface

module mkTxChannel#(Clock txClock, Reset txReset)(TxChannel);
   PacketBuffer pktBuff <- mkPacketBuffer();
   Deparser deparser <- mkDeparser();
   HeaderSerializer serializer <- mkHeaderSerializer();
   StoreAndFwdFromMemToRing egress <- mkStoreAndFwdFromMemToRing();
   StoreAndFwdFromRingToMac ringToMac <- mkStoreAndFwdFromRingToMac(txClock, txReset);
   //MemWriteConverter

   mkConnection(egress.writeClient, deparser.writeServer);
   mkConnection(deparser.writeClient, serializer.writeServer); 
   mkConnection(serializer.writeClient, pktBuff.writeServer);
   mkConnection(ringToMac.readClient, pktBuff.readServer);

   interface macTx = ringToMac.macTx;
   interface readClient = egress.readClient;
   interface freeClient = egress.free;
   interface prev = (interface Server#(MetadataRequest, MetadataResponse);
      interface request = (interface Put;
         method Action put (MetadataRequest req);
            let meta = req.meta;
            let pkt = req.pkt;
            $display("(%0d) Event: ", $time, fshow(req));
            egress.eventPktSend.enq(pkt);
            deparser.metadata.enq(meta);
         endmethod
      endinterface);
   endinterface);
   method TxChannelDbgRec read_debug_info;
      return TxChannelDbgRec {
         egressCount : 0,
         pktBuff: pktBuff.dbg
         };
   endmethod
   method read_deparser_perf_info = deparser.read_perf_info;
   method Action set_verbosity (int verbosity);
      //deparser.set_verbosity(verbosity);
      serializer.set_verbosity(verbosity);
   endmethod
endmodule

