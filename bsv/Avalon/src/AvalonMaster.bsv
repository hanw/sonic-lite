/*
Copyright (c) 2009 MIT, Kermin Fleming

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

Author: Kermin Fleming
*/

`include "asim/provides/fifo_utils.bsh"
`include "asim/provides/c_bus_utils.bsh"
`include "asim/provides/debug_utils.bsh"
`include "asim/provides/register_mapper.bsh"

import FIFO::*;
import FIFOF::*;
import ClientServer::*;
import StmtFSM::*;
import GetPut::*;
import CBus::*;
import Clocks::*;



interface AvalonMasterWires#(numeric type address_width, numeric type data_width);
  (* always_ready, always_enabled, prefix="", result="read" *) 
  method Bit#(1) read();
  
  (* always_ready, always_enabled, prefix="", result="write" *) 
  method Bit#(1) write();

  (* always_ready, always_enabled, prefix="", result="address" *) 
  method Bit#(address_width) address();

  (* always_ready, always_enabled, prefix="", result="writedata" *) 
  method Bit#(data_width) writedata();  

  (* always_ready, always_enabled, prefix="", result="readdata" *) 
  method Action readdata(Bit#(data_width) readdata);

  (* always_ready, always_enabled, prefix="", result="waitrequest" *) 
  method Action waitrequest(Bit#(1) waitrequest);

  (* always_ready, always_enabled, prefix="", result="readdatavalid" *) 
  method Action readdatavalid(Bit#(1) readdatavalid);
  	 
endinterface

// the inverse of the master wires
interface AvalonMasterInverseWires#(numeric type address_width, numeric type data_width);
  (* always_ready, always_enabled, prefix="", result="read" *) 
  method Action read(Bit#(1) read);
  
  (* always_ready, always_enabled, prefix="", result="write" *) 
  method Action write(Bit#(1) write);

  (* always_ready, always_enabled, prefix="", result="address" *) 
  method Action address(Bit#(address_width) address);

  (* always_ready, always_enabled, prefix="", result="writedata" *) 
  method Action writedata(Bit#(data_width) writedata);  

  (* always_ready, always_enabled, prefix="", result="readdata" *) 
  method Bit#(data_width) readdata();

  (* always_ready, always_enabled, prefix="", result="waitrequest" *) 
  method Bit#(1) waitrequest();

  (* always_ready, always_enabled, prefix="", result="readdatavalid" *) 
  method Bit#(1) readdatavalid();
  	 
endinterface


// busServer will only has a response for read command but not write command
interface AvalonMaster#(numeric type address_width, numeric type data_width);
  interface AvalonMasterWires#(address_width,data_width) masterWires;
  interface Server#(AvalonRequest#(address_width,data_width), Bit#(data_width)) busServer;
endinterface

module mkAvalonMaster (AvalonMaster#(address_width,data_width));
  Clock clock <- exposeCurrentClock;
  Reset reset <- exposeCurrentReset;
  AvalonMaster#(address_width,data_width) m;


  m <- mkAvalonMasterDualDomain(clock,reset);

  return m;
endmodule

typedef enum {
  Idle,
  ReadReq,
  WriteReq	
} MasterStates deriving (Bits,Eq);


// This is a simple driver for the Avalon slave.  This might at somepoint serve as a starting point for an 
// Avalon master
module mkAvalonMasterDualDomain#(Clock asicClock, Reset asicReset) (AvalonMaster#(address_width,data_width));

  SyncFIFOIfc#(AvalonRequest#(address_width,data_width)) reqFIFO <- mkSyncFIFOToCC(2,asicClock,asicReset);
  SyncFIFOIfc#(Bit#(data_width)) respFIFO <- mkSyncFIFOFromCC(2,asicClock);
  SyncFIFOIfc#(Bit#(0)) tokenFIFO <- mkSyncFIFOFromCC(2,asicClock);
  
  Reg#(Bit#(address_width)) addr <- mkReg(0); 
  Reg#(Bit#(data_width)) dataOut <- mkReg(0);
  Reg#(Bit#(1)) readReg <- mkReg(0);
  Reg#(Bit#(1)) writeReg <- mkReg(0);
  Reg#(Bit#(data_width)) readdataIn <- mkRegU;
  Reg#(Bit#(1)) readdatavalidIn <- mkReg(0);
  PulseWire waitrequestIn <- mkPulseWire;
  Reg#(MasterStates) state <- mkReg(Idle);

  rule start(state == Idle);
    reqFIFO.deq;
    if(reqFIFO.first.command == Write)
      begin
        writeReg <= 1;
        readReg <= 0;
        dataOut <= reqFIFO.first.data;
        addr <= reqFIFO.first.addr;
        state <= WriteReq;
      end
    else //handle Read
      begin
        tokenFIFO.enq(0);
        writeReg <= 0;
        readReg <= 1;
        dataOut <= 0;
        addr <= reqFIFO.first.addr;
        state <= ReadReq;
      end
  endrule

  rule handleReq((state == ReadReq || state == WriteReq) && !waitrequestIn);
    state <= Idle;
    readReg <= 0;
    writeReg <= 0;
  endrule

  rule handleResp(readdatavalidIn == 1);
    respFIFO.enq(readdataIn);
  endrule

  interface AvalonMasterWires masterWires;

    method Bit#(1) read();
      return readReg;
    endmethod
  
    method Bit#(1) write();
      return writeReg;
    endmethod

    method Bit#(address_width) address();
      return addr;
    endmethod

    method Bit#(data_width) writedata();  
      return dataOut;
    endmethod

    method Action readdata(Bit#(data_width) readdataNew);
      readdataIn <= readdataNew;
    endmethod

    method Action waitrequest(Bit#(1) waitrequestNew);
      if(waitrequestNew == 1)
        begin
          waitrequestIn.send;
        end
    endmethod

    method Action readdatavalid(Bit#(1) readdatavalidNew);
      readdatavalidIn <= readdatavalidNew;
    endmethod
  	 
  endinterface


  interface Server busServer;
    interface Put request;
      method Action put(AvalonRequest#(address_width,data_width) req);    
        reqFIFO.enq(req);
        debug(avalonDebug,$display("Avalon Master receives request: addr: %h data: %h", req.addr, req.data));
      endmethod
    endinterface

    interface Get response;
      method ActionValue#(Bit#(data_width)) get();
        respFIFO.deq;
        tokenFIFO.deq;
        return respFIFO.first;
      endmethod
    endinterface
  endinterface
endmodule



