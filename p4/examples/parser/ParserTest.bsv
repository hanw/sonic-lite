package ParserTest;

import BuildVector::*;
import DefaultValue::*;
import GetPut::*;
import ClientServer::*;
import StmtFSM::*;
import FIFO::*;
import Pipe::*;
import Vector::*;
import ConnectalMemory::*;

import Ethernet::*;
import PacketBuffer::*;
import IPv4Parser::*;
import MemTypes::*;
import MemServerIndication::*;
import MMUIndication::*;

typedef 12 PktSize; // maximum 4096b
typedef TDiv#(`DataBusWidth, 32) WordsPerBeat;

interface ParserTestIndication;
   method Action read_version_resp(Bit#(32) version);
//   method Action parsed_ipv4_resp(Bit#(8) ttl);
//   method Action parsed_vlan_resp();
//   method Action parsed_ether_resp(Bit#(48) srcAddr, Bit#(48) dstAddr);
endinterface

interface ParserTestRequest;
   method Action read_version();
   method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
endinterface

interface ParserTest;
   interface ParserTestRequest request;
endinterface
module mkParserTest#(ParserTestIndication indication)(ParserTest);

   let verbose = True;

   PacketBuffer rxPktBuff <- mkPacketBuffer();
   Parser parser <- mkParser();

   rule packetParseStart;
      let pktLen <- rxPktBuff.readServer.readLen.get;
      rxPktBuff.readServer.readReq.put(EtherReq{len: truncate(pktLen)});
      if (verbose) $display(fshow(" read packt ") + fshow(pktLen));
   endrule

   rule packetParseInProgress;
      let v <- rxPktBuff.readServer.readData.get;
      if (verbose) $display(fshow(" load packet ") + fshow(v));
      parser.frameIn.enq(v);
      if (v.eop) begin
         if (verbose) $display(fshow(" eop."));
      end
   endrule

//   rule parser_out_ethernet_srcAddr;
//      let s <- toGet(parser.parsedOut_ethernet_srcAddr).get;
//      let d <- toGet(parser.parsedOut_ethernet_dstAddr).get;
//      indication.parsed_ether_resp(s,d);
//   endrule
//
//   rule parser_out_ip_ttl;
//      let v <- toGet(parser.parsedOut_ipv4_ttl).get;
//      indication.parsed_ipv4_resp(v);
//   endrule

   interface ParserTestRequest request;
      method Action read_version();
         let v= `NicVersion;
         $display("read version");
         indication.read_version_resp(v);
      endmethod
      method Action writePacketData(Vector#(2, Bit#(64)) data, Vector#(2, Bit#(8)) mask, Bit#(1) sop, Bit#(1) eop);
         EtherData beat = defaultValue;
         beat.data = pack(reverse(data));
         beat.mask = pack(reverse(mask));
         beat.sop = unpack(sop);
         beat.eop = unpack(eop);
         rxPktBuff.writeServer.writeData.put(beat);
      endmethod
   endinterface
endmodule: mkParserTest
endpackage: ParserTest
