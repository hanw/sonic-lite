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
import ClientServer::*;
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
import MatchTable::*;
import MatchTableTypes::*;

import AlteraExtra::*;
import AlteraEthPhy::*;
import EthMac::*;
import ALTERA_SI570_WRAPPER          ::*;
import ALTERA_EDGE_DETECTOR_WRAPPER  ::*;
import ConnectalClocks::*;
import LedController::*;
import Leds::*;
import PushButtonController::*;

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
   method Action matchTableResponse(Bit#(32) key, Bit#(32) value);
endinterface

interface P4TopRequest;
   method Action sonic_read_version();
   method Action writePacketData(Vector#(2, Bit#(64)) data, Bit#(1) sop, Bit#(1) eop);
   method Action readPacketBuffer(Bit#(16) addr);
   method Action writePacketBuffer(Bit#(16) addr, Bit#(64) data);

   method Action matchTableRequest(Bit#(32) key, Bit#(32) value, Bit#(32) op);

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

`ifndef BSIM
   B2C iclock_50 <- mkB2C();
   B2C1 iclock_644 <- mkB2C1();
//   B2C iclock_pcie <- mkB2C();

   Vector#(4, PushButtonController) buttons <- replicateM(mkPushButtonController(iclock_50.c, clocked_by iclock_50.c, reset_by iclock_50.r));

   Reset rst_644   <- mkResetInverter(iclock_50.r, clocked_by iclock_644.c);
   Reset rst_644_n <- mkAsyncReset(2, iclock_50.r, iclock_644.c);
   // PLL Input:   SFP REFCLK from SI570
   // PLL Output:  156.25MHz
   // PLL Reset:   Active High, must invert default Reset
   PLL156 pll156 <- mkPLL156(iclock_644.c, rst_644, clocked_by iclock_644.c, reset_by rst_644);
   Clock clk_156_25 = pll156.outclk_0;
   Reset rst_156   <- mkResetInverter(iclock_50.r, clocked_by clk_156_25);
   Reset rst_156_n <- mkAsyncReset(1, rst_156, clk_156_25);
   Si570Wrap si570 <- mkSi570Wrap(iclock_50.c, iclock_50.r, clocked_by iclock_50.c, reset_by iclock_50.r);
   EdgeDetectorWrap edgedetect <- mkEdgeDetectorWrap(iclock_50.c, iclock_50.r, clocked_by iclock_50.c, reset_by iclock_50.r);

   rule si570_connections;
      let ifreq_mode = 3'b110;  //644.53125 MHZ
      si570.ifreq.mode(ifreq_mode);
      si570.istart.go(edgedetect.odebounce.out);
   endrule

   rule button_to_iclock50_r;
      iclock_50.inputreset(pack(buttons[0]));
   endrule

   rule button_to_si570;
      edgedetect.itrigger.in(pack(buttons[1]));
   endrule

//   Reset xcvr_reset_n <- mkAsyncReset(2, iclock_50.r, eth.ifcs.clk_xcvr[0]);

//   LedController pci_led <- mkLedController(False, clocked_by iclock_pcie.c, reset_by iclock_pcie.r);
//   LedController eth_tx_led <- mkLedController(False, clocked_by clk_156_25, reset_by rst_156_n);
//   LedController eth_rx_led <- mkLedController(False, clocked_by eth.ifcs.clk_xcvr[0], reset_by xcvr_reset_n);
   LedController sfp_led <- mkLedController(False, clocked_by iclock_644.c, reset_by rst_644_n);

//   rule led_pcie;
//      pci_led.setPeriod(led_off, 500, led_on_max, 500);
//   endrule
//   rule led_eth_tx;
//      eth_tx_led.setPeriod(led_off, 500, led_on_max, 500);
//   endrule
//   rule led_eth_rx;
//      eth_rx_led.setPeriod(led_off, 500, led_on_max, 500);
//   endrule
   rule led_sfp;
      sfp_led.setPeriod(led_off, 500, led_on_max, 500);
   endrule

   Vector#(4, LedController) led_xcvr_ <- replicateM(mkLedController(False, clocked_by iclock_50.c, reset_by iclock_50.r));
   Led#(4) led_xcvr = combineLeds(led_xcvr_);

   rule led_xcvr_ready;
      for (Integer i = 0; i<4; i=i+1) begin
         led_xcvr_[i].setPeriod(led_off, 500, led_on_max, 500);
      end
   endrule

//   EthPhyIfc phy <- mkAlteraEthPhy(clk_50_b4a_buf.outclk, iclock_644.c, clk_156_25, iclock_50.r, clocked_by clk_156_25, reset_by rst_156_n);
//   Clock xgmii_rx_clk = phy.rx_clkout;
//   EthMacIfc mac <- mkEthMac(clk_50_b4a_buf.outclk, clk_156_25, replicate(xgmii_rx_clk), rst_156_n, clocked_by clk_156_25, reset_by rst_156_n);
//   mapM(uncurry(mkConnection), zip(mac.tx, phy.tx));
//   mapM(uncurry(mkConnection), zip(phy.rx, mac.rx));

`endif

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
  
   /* Match Table Functionalities */
   function RequestType makeRequest(Bit#(32) key, Bit#(32) value, Operation op);
       return RequestType {
           key : key,
           value : value,
           addrIdx : 0,
           op : op
       };
   endfunction

   Server#(RequestType, ResponseType) matchTable <- mkMatchTable();

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
//   SharedBuffer#(12, 128, 1) buff <- mkSharedBuffer(vec(dmaClient), vec(dmaWriteClient), memServerIndication.ifc, mmuIndication.ifc);

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

   rule matchTableRes;
       let res <- matchTable.response.get;
       indication.matchTableResponse(res.key, res.value);
   endrule

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

      method Action matchTableRequest(Bit#(32) key, Bit#(32) value, Bit#(32) op);
        if (op == 0)
            matchTable.request.put(makeRequest(key, value, GET));
        else if (op == 1)
            matchTable.request.put(makeRequest(key, value, PUT));
        else if (op == 2)
            matchTable.request.put(makeRequest(key, value, UPDATE));
        else if (op == 3)
            matchTable.request.put(makeRequest(key, value, REMOVE));
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
`ifndef BSIM
      method Action osc_50(Bit#(1) b3d, Bit#(1) b4a, Bit#(1) b4d, Bit#(1) b7a, Bit#(1) b7d, Bit#(1) b8a, Bit#(1) b8d);
         iclock_50.inputclock(b4a);
      endmethod
      method Action sfp(Bit#(1) refclk);
         iclock_644.inputclock(refclk);
      endmethod
      method Action buttons(Bit#(4) v);
         for (Integer i=0; i<valueOf(NumPorts); i=i+1) begin
            buttons[i].ifc.button(v[i]);
         end
      endmethod
//      method Action serial_rx(Bit#(NumPorts) data);
//         phy.serial.rx(data);
//      endmethod
//      method serial_tx_data = phy.serial.tx;
//      method led0 = pci_led.ifc.out;
//      method led1 = eth_tx_led.ifc.out;
//      method led2 = eth_rx_led.ifc.out;
      method led3 = sfp_led.ifc.out;
      method led_bracket = led_xcvr.out;
      interface sfpctrl = (interface SFPCtrl;
         method Action los (Bit#(NumPorts) v); endmethod
         method Action mod0_presnt_n(Bit#(NumPorts) v); endmethod
         method ratesel0 = pack(replicate(1'b1));
         method ratesel1 = pack(replicate(1'b1));
         method txdisable = pack(replicate(1'b0));
         method Action txfault(Bit#(NumPorts) v); endmethod
      endinterface);
      interface deleteme_unused_clock = iclock_50.c;
      interface deleteme_unused_reset = iclock_50.r;
      interface deleteme_unused_clock2 = defaultClock;
      interface deleteme_unused_clock3 = clk_156_25;
`endif
   endinterface
endmodule
