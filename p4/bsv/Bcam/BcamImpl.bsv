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

import FIFO::*;
import FIFOF::*;
import Clocks::*;
import DefaultValue::*;
import GetPut::*;
import ClientServer::*;
import ALTERA_BCAM_WRAPPER::*;

interface Bcam#(type addr_t, type data_t);
   interface Put#(Tuple2#(addr_t, data_t)) writeServer;
   interface Server#(data_t, Maybe#(addr_t)) readServer;
endinterface

module mkBcamVerilog(Bcam#(addr_t, data_t))
   provisos (Bits#(addr_t, addr_sz)
            ,Bits#(data_t, data_sz)
            ,Eq#(addr_t)
            ,Div#(data_sz, 9, pwid)
            ,Mul#(pwid, 9, data_sz)
            ,Add#(cdep, 9, addr_sz)
            ,Literal#(data_t)
            ,Literal#(addr_t));

   Clock defaultClock <- exposeCurrentClock();
   Reset defaultReset <- exposeCurrentReset();
   Reset defaultResetN <- mkResetInverter(defaultReset, clocked_by defaultClock);

   Bcam_Config bcamCfg = defaultValue;
   bcamCfg.cdep=valueOf(cdep);
   bcamCfg.pwid=valueOf(pwid);
   bcamCfg.pipe=0;
   BcamWrap#(addr_t, data_t) bcamWrap <- mkBcamWrap(bcamCfg, clocked_by defaultClock, reset_by defaultResetN);

   FIFO#(Maybe#(addr_t)) readFifo <- mkFIFO;
   FIFO#(data_t) readReqFifo <- mkFIFO;
   //FIFOF#(void) readRespFifo <- mkFIFOF;
   FIFO#(Tuple2#(addr_t, data_t)) writeReqFifo <- mkFIFO;

   Wire#(Bool) writeEnable <- mkDWire(False);
   Wire#(addr_t) writeAddr <- mkDWire(0);
   Wire#(data_t) writeData <- mkDWire(0);
   Wire#(data_t) readData <- mkDWire(0);

   rule writeBcam;
      let v <- toGet(writeReqFifo).get;
      writeAddr <= tpl_1(v);
      writeData <= tpl_2(v);
      writeEnable <= True;
   endrule

   rule readBcam;
      let v <- toGet(readReqFifo).get;
      readData <= v;
   endrule

   rule doReadResp;// (readRespFifo.notEmpty);
      if (bcamWrap.isMatch) begin
         readFifo.enq(tagged Valid bcamWrap.mAddr);
         //readRespFifo.deq;
      end
      else begin
         readFifo.enq(tagged Invalid);
      end
   endrule

   rule assignVerilog;
      bcamWrap.wAddr(writeAddr);
      bcamWrap.wPatt(writeData);
      bcamWrap.wEnb(writeEnable);
      bcamWrap.mPatt(readData);
   endrule

   interface Server readServer;
      interface Put request;
         method Action put(data_t data);
            readReqFifo.enq(data);
            //readRespFifo.enq(?);
         endmethod
      endinterface
      interface Get response = toGet(readFifo);
   endinterface

   interface Put writeServer = toPut(writeReqFifo);
endmodule
