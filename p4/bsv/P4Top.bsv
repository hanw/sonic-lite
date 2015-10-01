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

import BRAMFIFO::*;
import BuildVector::*;
import Clocks::*;
import DefaultValue::*;
import FIFO::*;
import FIFOF::*;
import GetPut::*;
import Vector::*;
import Connectable::*;
import StmtFSM::*;
import Pipe::*;
import HostInterface::*;
import MemTypes::*;
import MemReadEngine::*;
import MemWriteEngine::*;
import MemServerIndication::*;
import MMUIndication::*;

import Ethernet::*;
import IngressPipeline::*;
import PacketBuffer::*;
import Parser::*;
import Types::*;
import SharedBuff::*;
import `PinTypeInclude::*;

typedef TDiv#(DataBusWidth, 32) WordsPerBeat;

interface P4TopIndication;
   method Action sonic_read_version_resp(Bit#(32) version);
endinterface

interface P4TopRequest;
   method Action sonic_read_version();
   method Action writePacketData(Vector#(2, Bit#(64)) data, Bit#(1) sop, Bit#(1) eop);
   method Action readPacketBuffer(Bit#(16) addr);
   method Action writePacketBuffer(Bit#(16) addr, Bit#(64) data);

   method Action port_mapping_add_entry(Bit#(32) table_name, MatchInput_port_mapping match_key);
   method Action port_mapping_set_default_action(Bit#(32) table_name);
   method Action port_mapping_delete_entry(Bit#(32) table_name, Bit#(32) id);
   method Action port_mapping_modify_entry(Bit#(32) table_name, Bit#(32) id, ActionInput_port_mapping actions);
   method Action bd_add_entry(Bit#(32) table_name, MatchInput_bd match_key);
   method Action bd_set_default_action(Bit#(32) table_name);
   method Action bd_delete_entry(Bit#(32) table_name, Bit#(32) id);
   method Action bd_modify_entry(Bit#(32) table_name, Bit#(32) id, ActionInput_bd actions);
   method Action ipv4_fib_add_entry(Bit#(32) table_name, MatchInput_ipv4_fib match_key);
   method Action ipv4_fib_set_default_action(Bit#(32) table_name);
   method Action ipv4_fib_delete_entry(Bit#(32) table_name, Bit#(32) id);
   method Action ipv4_fib_modify_entry(Bit#(32) table_name, Bit#(32) id, ActionInput_ipv4_fib actions);
   method Action ipv4_fib_lpm_add_entry(Bit#(32) table_name, MatchInput_ipv4_fib_lpm match_key);
   method Action ipv4_fib_lpm_set_default_action(Bit#(32) table_name);
   method Action ipv4_fib_lpm_delete_entry(Bit#(32) table_name, Bit#(32) id);
   method Action ipv4_fib_lpm_modify_entry(Bit#(32) table_name, Bit#(32) id, ActionInput_ipv4_fib_lpm actions);
   method Action nexthop_add_entry(Bit#(32) table_name, MatchInput_nexthop match_key);
   method Action nexthop_set_default_action(Bit#(32) table_name);
   method Action nexthop_delete_entry(Bit#(32) table_name, Bit#(32) id);
   method Action nexthop_modify_entry(Bit#(32) table_name, Bit#(32) id, ActionInput_nexthop actions);
   method Action rewrite_mac_add_entry(Bit#(32) table_name, MatchInput_rewrite_mac match_key);
   method Action rewrite_mac_set_default_action(Bit#(32) table_name);
   method Action rewrite_mac_delete_entry(Bit#(32) table_name, Bit#(32) id);
   method Action rewrite_mac_modify_entry(Bit#(32) table_name, Bit#(32) id, ActionInput_rewrite_mac actions);
endinterface

interface P4Top;
   interface P4TopRequest request;
   interface `PinType pins;
endinterface

//module mkP4Top#(Clock derivedClock, Reset derivedReset, P4TopIndication indication)(P4Top);
module mkP4Top#(P4TopIndication indication)(P4Top);
   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

   let verbose = True;
   Reg#(Cycle_t) cycle <- mkReg(defaultValue);
   rule every1 if (verbose);
      cycle.cnt <= cycle.cnt + 1;
   endrule

   Reg#(Standard_metadata_t) standard_metadata <- mkReg(defaultValue);
   Reg#(Ingress_metadata_t) ingress_metadata <- mkReg(defaultValue);

   PacketBuffer rxPktBuff <- mkPacketBuffer();
   Parser parser <- mkParser();
   Pipeline_port_mapping ingress_port_mapping <- mkIngressPipeline_port_mapping();

   // read client interface
   FIFO#(MemRequest) reqFifo <-mkSizedFIFO(4);
   FIFO#(MemData#(DataBusWidth)) dataFifo <- mkSizedFIFO(32);
   MemReadClient#(DataBusWidth) dmaClient = (interface MemReadClient;
      interface Get readReq = toGet(reqFifo);
      interface Put readData = toPut(dataFifo);
   endinterface);

   // write client interface
   FIFO#(MemRequest) writeReqFifo <- mkSizedFIFO(4);
   FIFO#(MemData#(DataBusWidth)) writeDataFifo <- mkSizedFIFO(32);
   FIFO#(Bit#(MemTagSize)) writeDoneFifo <- mkSizedFIFO(4);
   MemWriteClient#(DataBusWidth) dmaWriteClient = (interface MemWriteClient;
      interface Get writeReq = toGet(writeReqFifo);
      interface Get writeData = toGet(writeDataFifo);
      interface Put writeDone = toPut(writeDoneFifo);
   endinterface);

   MemServerIndicationOutput memServerIndication <- mkMemServerIndicationOutput;
   MMUIndicationOutput mmuIndication <- mkMMUIndicationOutput;
   SharedBuffer#(16, 128, 1) buff <- mkSharedBuffer(vec(dmaClient), vec(dmaWriteClient), memServerIndication.ifc, mmuIndication.ifc);

   Reg#(Bit#(EtherLen)) pktLen <- mkReg(0);
   Reg#(Bit#(9)) rAddr_wires <- mkReg(0);

   rule packetParseStart;
      let pktLen <- rxPktBuff.readServer.readLen.get;
      rxPktBuff.readServer.readReq.put(EtherReq{len: truncate(pktLen)});
      if (verbose) $display(fshow(cycle) + fshow(" read packt ") + fshow(pktLen));
   endrule

   rule packetParseInProgress;
      let v <- rxPktBuff.readServer.readData.get;
      if (verbose) $display(fshow(cycle) + fshow(" load packet ") + fshow(v));
      parser.frameIn.enq(v);
      if (v.eop) begin
         if (verbose) $display(fshow(cycle) + fshow(" eop."));
      end
   endrule

   rule matchTableStart;
      let v <- toGet(parser.parseDone).get;
      $display("Parse Done");
      parser.parserReset();
   endrule

   rule forwardPayload;
      let v <- toGet(parser.payloadOut).get;
   endrule

   rule readData;
      let v <- toGet(dataFifo).get;
      $display("%d: Received data %x", cycle, v.data);
   endrule

   rule writeDone;
      let v <- toGet(writeDoneFifo).get;
      $display("%d: Write done", cycle);
   endrule
   //mkConnection(parser.phvOut, ingress_port_mapping.phvIn);

   interface P4TopRequest request;
      method Action sonic_read_version();
         let v= `NicVersion;
         indication.sonic_read_version_resp(v);
      endmethod
      method Action writePacketData(Vector#(2, Bit#(64)) data, Bit#(1) sop, Bit#(1) eop);
         EtherData beat = defaultValue;
         beat.data = pack(reverse(data));
         beat.sop = unpack(sop);
         beat.eop = unpack(eop);
         rxPktBuff.writeServer.writeData.put(beat);
      endmethod

      method Action readPacketBuffer(Bit#(16) addr);
         Bit#(ByteEnableSize) firstbe = 'hff;
         Bit#(ByteEnableSize) lastbe = 'hff;
         reqFifo.enq(MemRequest {sglId: 0, offset: 0, burstLen: 16, tag:0, firstbe: firstbe, lastbe: lastbe});
      endmethod

      method Action writePacketBuffer(Bit#(16) addr, Bit#(64) data);
         Bit#(ByteEnableSize) firstbe = 'hff;
         Bit#(ByteEnableSize) lastbe = 'hff;
         writeReqFifo.enq(MemRequest {sglId:0, offset:0, burstLen:16, tag:0, firstbe: firstbe, lastbe: lastbe});

         function Bit#(32) plusi(Integer i); return fromInteger(i); endfunction
         Vector#(WordsPerBeat, Bit#(32)) v = genWith(plusi);
         writeDataFifo.enq(MemData {data: pack(v), tag:0, last:True});
      endmethod
      // Generate fixed standard set of API function
      // In software, we should hide the details of match table different behind api
      // expose thrift-server to software to take advantage of existing thrift infra.
      // expose raw connectal cpp generated interface to test application.

      method Action port_mapping_add_entry(Bit#(32) table_name, MatchInput_port_mapping match_key);
         // write entries to table.
         // queue read flow_id
      endmethod

      method Action port_mapping_set_default_action(Bit#(32) table_name);
         // write default action to action engine
      endmethod

      method Action port_mapping_delete_entry(Bit#(32) table_name, Bit#(32) flow_id);
         // invalidate entries in table
      endmethod

      method Action port_mapping_modify_entry(Bit#(32) table_name, Bit#(32) flow_id, ActionInput_port_mapping actions);
         // enqueue match key
      endmethod

      method Action bd_add_entry(Bit#(32) table_name, MatchInput_bd match_key);
         // write entries to table.
         // queue read flow_id
      endmethod

      method Action bd_set_default_action(Bit#(32) table_name);
         // write default action to action engine
      endmethod

      method Action bd_delete_entry(Bit#(32) table_name, Bit#(32) flow_id);
         // invalidate entries in table
      endmethod

      method Action bd_modify_entry(Bit#(32) table_name, Bit#(32) flow_id, ActionInput_bd actions);
         // enqueue match key
      endmethod

      method Action ipv4_fib_add_entry(Bit#(32) table_name, MatchInput_ipv4_fib match_key);
         // write entries to table.
         // queue read flow_id
      endmethod

      method Action ipv4_fib_set_default_action(Bit#(32) table_name);
         // write default action to action engine
      endmethod

      method Action ipv4_fib_delete_entry(Bit#(32) table_name, Bit#(32) flow_id);
         // invalidate entries in table
      endmethod

      method Action ipv4_fib_modify_entry(Bit#(32) table_name, Bit#(32) flow_id, ActionInput_ipv4_fib actions);
         // enqueue match key
      endmethod

      method Action ipv4_fib_lpm_add_entry(Bit#(32) table_name, MatchInput_ipv4_fib_lpm match_key);
         // write entries to table.
         // queue read flow_id
      endmethod

      method Action ipv4_fib_lpm_set_default_action(Bit#(32) table_name);
         // write default action to action engine
      endmethod

      method Action ipv4_fib_lpm_delete_entry(Bit#(32) table_name, Bit#(32) flow_id);
         // invalidate entries in table
      endmethod

      method Action ipv4_fib_lpm_modify_entry(Bit#(32) table_name, Bit#(32) flow_id, ActionInput_ipv4_fib_lpm actions);
         // enqueue match key
      endmethod

      method Action nexthop_add_entry(Bit#(32) table_name, MatchInput_nexthop match_key);
         // write entries to table.
         // queue read flow_id
      endmethod

      method Action nexthop_set_default_action(Bit#(32) table_name);
         // write default action to action engine
      endmethod

      method Action nexthop_delete_entry(Bit#(32) table_name, Bit#(32) flow_id);
         // invalidate entries in table
      endmethod

      method Action nexthop_modify_entry(Bit#(32) table_name, Bit#(32) flow_id, ActionInput_nexthop actions);
         // enqueue match key
      endmethod

      method Action rewrite_mac_add_entry(Bit#(32) table_name, MatchInput_rewrite_mac match_key);
         // write entries to table.
         // queue read flow_id
      endmethod

      method Action rewrite_mac_set_default_action(Bit#(32) table_name);
         // write default action to action engine
      endmethod

      method Action rewrite_mac_delete_entry(Bit#(32) table_name, Bit#(32) flow_id);
         // invalidate entries in table
      endmethod

      method Action rewrite_mac_modify_entry(Bit#(32) table_name, Bit#(32) flow_id, ActionInput_rewrite_mac actions);
         // enqueue match key
      endmethod

      // -- Internal of API depends on P4 program.
      // -- Use dispatcher to send table info to corresponding table.
      // -- Invalid table tag will result in error.
   endinterface
   interface `PinType pins;
      // Clocks
      interface deleteme_unused_clock = defaultClock;
      interface deleteme_unused_reset = defaultReset;

   endinterface
endmodule
