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

import ClientServer::*;
import DbgTypes::*;
import Ethernet::*;
import FIFO::*;
import GetPut::*;
import PaxosTypes::*;
import ConnectalTypes::*;
import Register::*;

interface BasicBlockRole;
   interface BBServer prev_control_state;
   interface Client#(RoleRegRequest, RoleRegResponse) regClient;
endinterface

module mkBasicBlockRole(BasicBlockRole);
   let verbose = False;
   FIFO#(BBRequest) bb_role_request_fifo <- mkFIFO;
   FIFO#(BBResponse) bb_role_response_fifo <- mkFIFO;
   FIFO#(RoleRegRequest) reg_role_request_fifo <- mkFIFO;
   FIFO#(RoleRegResponse) reg_role_response_fifo <- mkFIFO;
   FIFO#(PacketInstance) curr_packet_fifo <- mkFIFO;

   rule bb_role;
      let v <- toGet(bb_role_request_fifo).get;
      case (v) matches
         tagged BBRoleRequest {pkt: .pkt}: begin
            RoleRegRequest req;
            req = RoleRegRequest {addr: 0, data: ?, write: False};
            reg_role_request_fifo.enq(req);
            if (verbose) $display("(%0d) RoleBB: request ", $time);
            curr_packet_fifo.enq(pkt);
         end
      endcase
   endrule

   rule reg_resp;
      let v <- toGet(reg_role_response_fifo).get;
      let pkt <- toGet(curr_packet_fifo).get;
      if (verbose) $display("(%0d) RoleBB: response %h", $time, v);
      BBResponse resp = tagged BBRoleResponse {pkt: pkt, role: unpack(v.data)};
      bb_role_response_fifo.enq(resp);
   endrule

   interface prev_control_state = (interface BBServer;
      interface request = toPut(bb_role_request_fifo);
      interface response = toGet(bb_role_response_fifo);
   endinterface);
   interface regClient = (interface Client#(RoleRegRequest, RoleRegResponse);
      interface request = toGet(reg_role_request_fifo);
      interface response = toPut(reg_role_response_fifo);
   endinterface);
endmodule

interface RoleTable;
   interface BBClient next_control_state_0;
endinterface

module mkRoleTable#(MetadataClient md)(RoleTable);
   FIFO#(BBRequest) outReqFifo <- mkFIFO;
   FIFO#(BBResponse) inRespFifo <- mkFIFO;
   FIFO#(PacketInstance) currPacketFifo <- mkFIFO;
   FIFO#(MetadataT) currMetadataFifo <- mkFIFO;

   rule tableLookupRequest;
      let v <- md.request.get;
      case (v) matches
         tagged RoleLookupRequest {pkt: .pkt, meta: .meta}: begin
            BBRequest req;
            req = tagged BBRoleRequest {pkt: pkt};
            $display("(%0d) Role: table lookup request", $time);
            outReqFifo.enq(req);
            currPacketFifo.enq(pkt);
            currMetadataFifo.enq(meta);
         end
      endcase
   endrule

   rule readRoleResp;
      let v <- toGet(inRespFifo).get;
      let meta <- toGet(currMetadataFifo).get;
      let pkt <- toGet(currPacketFifo).get;
      if (v matches tagged BBRoleResponse {pkt: .pkt, role: .role}) begin
         $display("(%0d) Role: BB response role=%h", $time, role);
         meta.switch_metadata$role = tagged Valid role;
      end
      MetadataResponse resp = tagged RoleResponse { pkt: pkt, meta: meta};
      md.response.put(resp);
   endrule
   interface next_control_state_0 = (interface BBClient;
      interface request = toGet(outReqFifo);
      interface response = toPut(inRespFifo);
   endinterface);
endmodule
