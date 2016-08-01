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

// Read-only Instruction Memory for packet processing CPU
// No MMU
// No Cache

import FIFOF::*;
import BRAM::*;
import CPU_Common::*;
import StringUtils::*;

interface IMem;
   interface Server#(IMemRequest, IMemResponse) serverA;
endinterface

module mkIMem#(String name)(IMem);
   BRAM1Port#(IMemAddr, IMemData) memory <- mkBRAM1Server(defaultValue);
   Array#(Reg#(Maybe#(IMemRequest))) crg_reqA <- mkCReg(2, tagged Invalid);

   Reg#(Bool) isInitialized <- mkReg(False);

   rule do_A if (crg_reqA[1] matches tagged Valid .a);
      let req = BRAMRequest {
         write : False,
         responseOnWrite: False,
         address : a.addr,
         datain : a.data};
      memory.portA.request.put (req);
   endrule

`ifdef SIMULATION
   Handle fp <- openFile(name, ReadMode);
   List#(Tuple2#(IMemAddr, IMemData)) entryList = tagged Nil;
   let readable <- hIsReadable(fp);
   if (readable) begin
      Bool isEOF <- hIsEOF(fp);
      while (!isEOF) begin
         let line <- hGetLine(fp);
         List#(String) parsedEntries = parseCSV(line);
         while (parsedEntries != tagged Nil) begin
            IMemAddr addr = fromInteger(hexStringToInteger(parsedEntries[0]));
            IMemData data = fromInteger(hexStringToInteger(parsedEntries[1]));
            parsedEntries = List::drop(2, parsedEntries);
            entryList = List::cons(tuple2(addr, data), entryList);
         end
         isEOF <- hIsEOF(fp);
      end
   end
   hClose(fp);

   Reg#(Bit#(10)) fsmIndex <- mkReg(0);

   rule do_init (fsmIndex < fromInteger(List::length(entryList)));
      $display("insert entry ", fromInteger(List::length(entryList)));
      IMemAddr addr = tpl_1(entryList[fsmIndex]);
      IMemData data = tpl_2(entryList[fsmIndex]);
      fsmIndex <= fsmIndex + 1;
      $display("finished insert entry ", fromInteger(List::length(entryList)));
   endrule

   rule finish_init(fsmIndex == fromInteger(List::length(entryList)));
      isInitialized <= True;
   endrule
`endif

   interface Server serverA;
      interface Put request;
         method Action put (request);
            crg_reqA[0] <= tagged Valid request;
         endmethod
      endinterface
      interface Get response;
         method ActionValue#(IMemResponse) get;
            let val <- memory.portA.response.get;
            IMemResponse response = ?;
            response.data = val;
            return response;
         endmethod
      endinterface
   endinterface
endmodule
