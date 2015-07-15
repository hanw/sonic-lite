
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

import FIFO ::*;
import FIFOF ::*;
import SpecialFIFOs ::*;
import Vector ::*;
import Arith ::*;
import BuildVector::*;
import Pipe ::*;
import GetPut ::*;
import ClientServer::*;
import MemTypes::*;
import MemreadEngine::*;
import MemwriteEngine::*;
import HostInterface::*;

//interface SonicIfc;
//endinterface

typedef TDiv#(DataBusWidth,32) DataBusWords;

interface SonicUserRequest;
   method Action sonic_read_version();
   method Action startRead(Bit#(32) pointer, Bit#(32) numBytes, Bit#(32) burstLen, Bit#(32) iterCnt);
   method Action startWrite(Bit#(32) pointer, Bit#(32) offset, Bit#(32) numWords, Bit#(32) burstLen, Bit#(32) iterCnt);
   method Action getStateDbg();
endinterface

interface SonicUserIndication;
   method Action sonic_read_version_resp(Bit#(32) version);
   method Action readDone(Bit#(32) mismatchCnt);
   method Action started(Bit#(32) numWords);
   method Action reportStateDbg(Bit#(32) wrCnt, Bit#(32) srcGen);
   method Action writeDone(Bit#(32) v);
endinterface

interface SonicUser;
   interface SonicUserRequest request;
   interface Vector#(1, MemWriteClient#(DataBusWidth)) dmaWriteClient;
   interface Vector#(1, MemReadClient#(DataBusWidth)) dmaReadClient;
//   interface SonicIfc sonicifc;
endinterface

typedef 12 NumOutstandingRequests;
typedef TMul#(NumOutstandingRequests, TMul#(32, 4)) BufferSizeBytes;
module mkSonicUser#(SonicUserIndication indication)(SonicUser);
   Clock defaultClock <- exposeCurrentClock();

// DMA Rd
   Reg#(SGLId)           pointer <- mkReg(0);
   Reg#(Bit#(32))       numBytes <- mkReg(0);
   Reg#(Bit#(BurstLenSize)) burstLenBytes <- mkReg(0);
   Reg#(Bit#(32))  itersToFinish <- mkReg(0);
   Reg#(Bit#(32))   itersToStart <- mkReg(0);
   Reg#(Bit#(32))      bytesRead <- mkReg(0);
   Reg#(Bit#(32)) mismatchCounts <- mkReg(0);
   MemreadEngine#(DataBusWidth,NumOutstandingRequests,1)        re <- mkMemreadEngineBuff(valueOf(BufferSizeBytes));
   FIFO#(Bit#(32)) checkDoneFifo <- mkFIFO();

   rule start (itersToStart > 0);
      $display("Test: request.put");
      re.readServers[0].request.put(MemengineCmd{sglId:pointer, base:0, len:numBytes, burstLen:burstLenBytes});
      itersToStart <= itersToStart-1;
   endrule

   Reg#(Bit#(DataBusWidth)) vReg <- mkReg(0);
   Reg#(Bit#(DataBusWidth)) vExpectedReg <- mkReg(0);
   Reg#(Bool)               validReg <- mkReg(False);
   Reg#(Bit#(32))           bytesToRead <- mkReg(0);
   Reg#(Bool)               lastReg <- mkReg(False);
   rule check;
      // first pipeline stage
      if (re.dataPipes[0].notEmpty()) begin
	 let v <- toGet(re.dataPipes[0]).get;
	 let rval = bytesRead/4;
	 function Bit#(32) expectedVal(Integer i); return rval+fromInteger(i); endfunction
	 let expectedV = pack(genWith(expectedVal));
	 vReg <= v;
	 vExpectedReg <= expectedV;
	 validReg <= True;
	 let next_bytesRead = bytesRead + fromInteger(valueOf(DataBusWidth))/8;
	 let next_bytesToRead = bytesToRead - fromInteger(valueOf(DataBusWidth))/8;
	 let last = (bytesToRead <= fromInteger(valueOf(DataBusWidth))/8);
	 //$display("check next_bytesRead=%d next_bytesToRead=%d last=%d", next_bytesRead, next_bytesToRead, last);
	 if (last) begin
	    next_bytesRead = 0;
	    next_bytesToRead = numBytes;
	 end
	 lastReg <= last;
	 bytesRead <= next_bytesRead;
	 bytesToRead <= next_bytesToRead;
      end
      else begin
	 validReg <= False;
      end

      // second pipeline stage
      if (validReg) begin
	 let v = vReg;
	 let expectedV = vExpectedReg;
	 let misMatch = v != expectedV;
	 mismatchCounts <= mismatchCounts + (misMatch ? 1 : 0);
	 //$display("Test: check new=%x numBytes=%x bytesRead=%x misMatch=%x read=%x expect=%x", new_bytesRead, numBytes, bytesRead, misMatch, v, expectedV);
	 if (lastReg) begin
	    checkDoneFifo.enq(mismatchCounts);
	 end
      end
   endrule

   rule finish if (itersToFinish > 0);
      $display("Test: response.get itersToFinish %x", itersToFinish);
      let mc <- toGet(checkDoneFifo).get();
      let rv <- re.readServers[0].response.get;
      if (itersToFinish == 1) begin
	 indication.readDone(mismatchCounts);
      end
      itersToFinish <= itersToFinish - 1;
   endrule

// DMA Wr
   Reg#(SGLId)     wrPointer <- mkReg(0);
   Reg#(Bit#(32)) wrNumWords <- mkReg(0);
   Reg#(Bit#(32)) wrBurstLen <- mkReg(0);
   FIFOF#(void)         wrCf <- mkSizedFIFOF(1);

   Vector#(NumberOfMasters, Reg#(Bit#(32)))        wrSrcGens <- replicateM(mkReg(0));
   Reg#(Bit#(32))                                writeOffset <- mkReg(0);
   Reg#(Bit#(32))                                  wrIterCnt <- mkReg(0);
   Vector#(NumberOfMasters, Reg#(Bit#(32)))       wrIterCnts <- replicateM(mkReg(0));
   Vector#(NumberOfMasters, FIFOF#(void))              wrCfs <- replicateM(mkSizedFIFOF(1));
   Vector#(NumberOfMasters, FIFOF#(Bool))        finishFifos <- replicateM(mkFIFOF);
   MemwriteEngine#(DataBusWidth,2,NumberOfMasters)        we <- mkMemwriteEngine;
   Bit#(MemOffsetSize) chunk = (extend(wrNumWords)/fromInteger(valueOf(NumberOfMasters)))*4;

   for(Integer i = 0; i < valueOf(NumberOfMasters); i=i+1) begin
      rule wrstart (wrIterCnts[i] > 0);
	 we.writeServers[i].request.put(MemengineCmd{tag:0, sglId:wrPointer, base:extend(writeOffset)+(fromInteger(i)*chunk), len:truncate(chunk), burstLen:truncate(wrBurstLen*4)});
	 Bit#(32) srcGen = (writeOffset/4)+(fromInteger(i)*truncate(chunk/4));
	 wrSrcGens[i] <= srcGen;
	 $display("start %d/%d, %h 0x%x %h", i, valueOf(NumberOfMasters), srcGen, wrIterCnts[i], writeOffset);
	 wrCfs[i].enq(?);
	 wrIterCnts[i] <= wrIterCnts[i]-1;
      endrule
      rule wrfinish;
	 $display("finish %d 0x%x", i, wrIterCnts[i]);
	 let rv <- we.writeServers[i].response.get;
	 finishFifos[i].enq(rv);
      endrule
      rule src if (wrCfs[i].notEmpty);
	 Vector#(DataBusWords, Bit#(32)) v;
	 for (Integer j = 0; j < valueOf(DataBusWords); j = j + 1)
	    v[j] = wrSrcGens[i]+fromInteger(j);
	 we.dataPipes[i].enq(pack(v));
	 let new_srcGen = wrSrcGens[i]+fromInteger(valueOf(DataBusWords));
	 wrSrcGens[i] <= new_srcGen;
	 if(new_srcGen == (writeOffset/4)+(fromInteger(i+1)*truncate(chunk/4)))
	    wrCfs[i].deq;
      endrule
   end

   PipeOut#(Vector#(NumberOfMasters, Bool)) finishPipe <- mkJoinVector(id, map(toPipeOut, finishFifos));
   PipeOut#(Bool) finishReducePipe <- mkReducePipe(uncurry(booland), finishPipe);

   rule indicate_finish;
      let rv <- toGet(finishReducePipe).get();
      if (wrIterCnt == 1) begin
	 wrCf.deq;
	 indication.writeDone(0);
      end
      wrIterCnt <= wrIterCnt - 1;
   endrule

   interface dmaWriteClient = vec(we.dmaClient);
   interface dmaReadClient = vec(re.dmaClient);
   interface SonicUserRequest request;
      method Action sonic_read_version();
         let v = `SonicVersion; //Defined in Makefile as time of compilation.
         indication.sonic_read_version_resp(v);
      endmethod
      method Action startRead(Bit#(32) rp, Bit#(32) nb, Bit#(32) bl, Bit#(32) ic) if (itersToStart == 0 && itersToFinish == 0);
         $display("start read");
	 pointer <= rp;
	 numBytes  <= nb;
	 bytesToRead <= nb;
	 burstLenBytes  <= truncate(bl);
	 itersToFinish <= ic;
	 itersToStart <= ic;
	 mismatchCounts <= 0;
	 bytesRead <= 0;
      endmethod
      method Action startWrite(Bit#(32) wp, Bit#(32) off, Bit#(32) nw, Bit#(32) bl, Bit#(32) ic);
	  $display("startWrite pointer=%d offset=%d numWords=%h burstLen=%d iterCnt=%d", wrPointer, off, nw, bl, ic);
	  indication.started(nw);
	  wrPointer   <= wp;
	  wrCf.enq(?);
	  wrNumWords  <= nw;
	  wrBurstLen  <= bl;
	  wrIterCnt   <= ic;
	  writeOffset <= off*4;
	  for(Integer i = 0; i < valueOf(NumberOfMasters); i=i+1)
	     wrIterCnts[i] <= ic;
       endmethod
   endinterface
endmodule
