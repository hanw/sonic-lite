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

import ConnectalConfig::*;
import MatchTable::*;
import HostInterface::*;
import GetPut::*;

// NfSume specific
import NfsumePins::*;
`include "ConnectalProjectConfig.bsv"

interface BcamTestRequest;
   method Action read_version();
   method Action add_entry(Bit#(36)key, Bit#(32)value);
endinterface

interface BcamTestTop;
   interface BcamTestRequest request;
   interface `PinType pins;
endinterface

interface BcamTestIndication;
   method Action read_version_resp(Bit#(32) v);
endinterface

module mkBcamTestTop#(HostInterface host, BcamTestIndication indication)(BcamTestTop);
   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

//   Clock mgmtClock = host.tsys_clk_200mhz_buf;
//   Reset mgmtReset <- mkSyncReset(2, defaultReset, mgmtClock);
//   EthPhyIfc phys <- mkXilinxEthPhy(mgmtClock);
//   Clock txClock = phys.tx_clkout;
//   Reset txReset <- mkSyncReset(2, defaultReset, txClock);
//   Clock rxClock = txClock;
//   Reset rxReset = txReset;

//   NfsumeLeds leds <- mkNfsumeLeds(mgmtClock, txClock);

   MatchTable#(0, 256, 36, 32) matchTable <- mkMatchTable("test");

   interface BcamTestRequest request;
      method Action add_entry(Bit#(36)key, Bit#(32)value);
         matchTable.add_entry.put(tuple2(key, value));
      endmethod
      method Action read_version();
         indication.read_version_resp(32'h01020304);
      endmethod
   endinterface

//   interface pins = mkNfsumePins(defaultClock, phys, leds, sfpctrl);
endmodule



