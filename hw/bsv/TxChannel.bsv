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
typedef TAdd#(DataSize, 1) NumBits;
typedef TAdd#(MaskSize, 1) NumBytes;

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

   Array#(Reg#(Bool)) sop_buff <- mkCReg(3, False);
   Array#(Reg#(Bool)) eop_buff <- mkCReg(3, False);
   Array#(Reg#(Bit#(PktDataWidth))) data_buff <- mkCReg(3, 0);
   Array#(Reg#(Bit#(MaskWidth))) mask_buff <- mkCReg(3, 0);

   Reg#(Bit#(PktDataWidth)) data_buffered <- mkReg(0);
   Reg#(Bit#(MaskWidth)) mask_buffered <- mkReg(0);
   Reg#(UInt#(TAdd#(MaskSize, 1))) n_bytes_buffered <- mkReg(0);
   Reg#(UInt#(TAdd#(DataSize, 1))) n_bits_buffered <- mkReg(0);

   PulseWire w_send_full_frame <- mkPulseWire();
   PulseWire w_buffer_partial_frame <- mkPulseWire();

   rule rl_serialize_stage1;
      data_in_ff.deq;
      data_buff[0] <= data_in_ff.first.data;
      mask_buff[0] <= data_in_ff.first.mask;
      UInt#(NumBytes) n_bytes = countOnes(data_in_ff.first.mask);
      UInt#(NumBits) n_bits = cExtend(n_bytes) << 3;
      if (data_in_ff.first.sop) begin
         sop_buff[0] <= True;
      end
      if (data_in_ff.first.eop) begin
         eop_buff[0] <= True;
      end
      else begin
         if (n_bytes + n_bytes_buffered > fromInteger(valueOf(MaskWidth))) begin
            w_send_full_frame.send();
         end
         else begin
            w_buffer_partial_frame.send();
         end
      end
      dbg3($format("nbytes %d, nbits %d", n_bytes, n_bits));
   endrule

   function Action enqueue_output(UInt#(NumBytes) n_bytes);
      action
         UInt#(NumBits) n_bits = cExtend(n_bytes) << 3;
         let data = data_buff[1] << n_bits_buffered | data_buffered; 
         let n_bytes_used = fromInteger(valueOf(MaskWidth)) - n_bytes_buffered;
         UInt#(NumBits) n_bits_used = cExtend(n_bytes_used) << 3;
         data_buffered <= data_buff[1] >> n_bits_used;
         mask_buffered <= mask_buff[1] >> n_bytes_used;
         n_bytes_buffered <= n_bytes - n_bytes_used;
         n_bits_buffered <= n_bits - n_bits_used;
         let eth = EtherData {sop: sop_buff[1], eop: False, mask: 'hffff, data: data};
         data_out_ff.enq(eth);
         sop_buff[1] <= False;
      endaction
   endfunction

   (* mutually_exclusive = "rl_end_of_packet, rl_send_full_frame, rl_buffer_partial_frame" *)
   rule rl_end_of_packet if (eop_buff[1]);
      UInt#(NumBytes) n_bytes = countOnes(mask_buff[1]);
      if (n_bytes + n_bytes_buffered > fromInteger(valueOf(MaskWidth))) begin
         dbg3($format("send eop more %d %d", n_bytes, n_bytes_buffered));
         enqueue_output(n_bytes);
         mask_buff[1] <= mask_buff[1] >> 16;
      end
      else begin
         dbg3($format("send eop"));
         let eth = EtherData {sop: sop_buff[1], eop: eop_buff[1], mask: mask_buffered, data: data_buffered};
         data_out_ff.enq(eth);
         eop_buff[1] <= False;
      end
   endrule

   rule rl_send_full_frame if (w_send_full_frame);
      UInt#(NumBytes) n_bytes = countOnes(mask_buff[1]);
      enqueue_output(n_bytes);
   endrule

   rule rl_buffer_partial_frame (w_buffer_partial_frame);
      UInt#(NumBytes) n_bytes = countOnes(mask_buff[2]);
      let data = (data_buff[2] << n_bits_buffered) | data_buffered;
      let mask = (mask_buff[2] << n_bytes_buffered) | mask_buffered;
      let n_bytes_used = n_bytes + n_bytes_buffered;
      UInt#(NumBits) n_bits_used = cExtend(n_bytes_used) << 3;
      data_buffered <= data;
      mask_buffered <= mask;
      n_bytes_buffered <= n_bytes_used;
      n_bits_buffered <= n_bits_used;
      dbg3($format("store: bytes: %d, bits: %d", n_bytes_used, n_bits_used));
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
      deparser.set_verbosity(verbosity);
      serializer.set_verbosity(verbosity);
   endmethod
endmodule

