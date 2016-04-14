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

interface RoleTable;
   interface Client#(RoundRegRequest, RoundRegResponse) regAccess;
   method Action setRole(Bit#(32) role);
endinterface

module mkRoleTable#(MetadataClient md)(RoleTable);
   Reg#(Role) role <- mkReg(COORDINATOR);

   FIFO#(PacketInstance) currPacketFifo <- mkFIFO;

   rule tableLookupRequest;
      let v <- md.request.get;
      $display("(%0d) Role: table lookup request", $time);
      case (v) matches
         tagged RoleLookupRequest {pkt: .pkt, meta: .meta}: begin
            MetadataT t = meta;
            t.switch_metadata$role = tagged Valid role;
            MetadataResponse resp = tagged RoleResponse { pkt: pkt, meta: t};
            md.response.put(resp);
         end
      endcase
   endrule

   method Action setRole(Bit#(32) v);
      role <= unpack(truncate(v));
   endmethod
endmodule
