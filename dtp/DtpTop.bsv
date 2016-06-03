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

import Arith ::*;
import BuildVector::*;
import ClientServer::*;
import Clocks::*;
import ConfigCounter::*;
import Connectable::*;
import DefaultValue::*;
import FIFO ::*;
import FIFOF ::*;
import GetPut ::*;
import Gearbox ::*;
import Pipe ::*;
import SpecialFIFOs ::*;
import Vector ::*;
import ConnectalConfig::*;

import EthPhy::*;
import Ethernet::*;
import DtpController::*;
import MemTypes::*;
import MemReadEngine::*;
import MemWriteEngine::*;
import PacketBuffer::*;
import HostInterface::*;
import `PinTypeInclude::*;

import ConnectalClocks::*;
import ALTERA_SI570_WRAPPER::*;
import AlteraExtra::*;
import LedController::*;
import AlteraMacWrap::*;
import AlteraEthPhy::*;
import DE5Pins::*;

interface DtpTop;
   interface DtpRequest request;
   interface `PinType pins;
endinterface

module mkDtpTop#(DtpIndication indication)(DtpTop);
   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();

   De5Clocks clocks <- mkDe5Clocks();
   De5SfpCtrl#(4) sfpctrl <- mkDe5SfpCtrl();
   Clock txClock = clocks.clock_156_25;
   Clock phyClock = clocks.clock_644_53;
   Clock mgmtClock = clocks.clock_50;

   MakeResetIfc dummyReset <- mkResetSync(0, False, defaultClock);
   Reset txReset <- mkAsyncReset(2, defaultReset, txClock);
   Reset dummyTxReset <- mkAsyncReset(2, dummyReset.new_rst, txClock);
   Reset mgmtReset <- mkAsyncReset(2, defaultReset, mgmtClock);

   DtpController dtpCtrl <- mkDtpController(indication, txClock, dummyTxReset);
   Reset rst_api <- mkAsyncReset(2, dtpCtrl.ifc.rst, txClock);
   Reset dtp_rst <- mkResetEither(dummyTxReset, rst_api, clocked_by txClock);

   DtpPhyIfc dtpPhy <- mkEthPhy(mgmtClock, txClock, phyClock, clocked_by txClock, reset_by dtp_rst);

   for (Integer i = 0 ; i < 4 ; i = i+1) begin
      rule source;
         dtpPhy.phys.tx[i].put(72'h83c1e0f0783c1e0f07);
      endrule
      rule drain;
         let v <- dtpPhy.phys.rx[i].get;
      endrule
   end

   De5Leds leds <- mkDe5Leds(defaultClock, txClock, mgmtClock, phyClock);
   De5Buttons#(4) buttons <- mkDe5Buttons(clocked_by mgmtClock, reset_by mgmtReset);

   mkConnection(dtpPhy.api, dtpCtrl.ifc);

   interface request = dtpCtrl.request;
   interface pins = mkDE5Pins(defaultClock, defaultReset, clocks, dtpPhy.phys, leds, sfpctrl, buttons);
endmodule
