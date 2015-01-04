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
`include "asim/provides/avalon.bsh"
 
import FIFO::*;
import FIFOF::*;
import ClientServer::*;
import StmtFSM::*;
import GetPut::*;
import CBus::*;
import Clocks::*;

interface AvalonSlaveWires#(numeric type address_width, numeric type data_width);
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
  
interface AvalonSlave#(numeric type address_width, numeric type data_width);
  interface AvalonSlaveWires#(address_width,data_width) slaveWires;
  interface Client#(AvalonRequest#(address_width,data_width), Bit#(data_width)) busClient;
endinterface

module mkAvalonSlave#(Clock asicClock, Reset asicReset) (AvalonSlave#(address_width,data_width));
  Clock clock <- exposeCurrentClock;
  Reset reset <- exposeCurrentReset;
  AvalonSlave#(address_width,data_width) m;

  if(asicClock == clock && asicReset == reset)
    begin
      m <- mkAvalonSlaveSingleDomain;
    end 
  else
    begin
      m <- mkAvalonSlaveDualDomain(asicClock,asicReset);
    end
  return m;
endmodule

module mkAvalonSlaveSingleDomain (AvalonSlave#(address_width,data_width));
  RWire#(Bit#(1)) readInValue <- mkRWire;
  RWire#(Bit#(1)) writeInValue <- mkRWire;
  RWire#(Bit#(address_width)) addressInValue <- mkRWire;
  RWire#(Bit#(data_width)) readdataOutValue <- mkRWire;
  RWire#(Bit#(data_width)) writedataInValue <- mkRWire;
  PulseWire putResponseCalled <- mkPulseWire;

  // In avalon read/write asserted for a single cycle unless 
  // waitreq also asserted.
  
  FIFOF#(AvalonRequest#(address_width,data_width)) reqFifo <- mkFIFOF;

  rule produceRequest;
    //Reads and writes are assumed not to occur simultaneously.  
    if(fromMaybe(0,readInValue.wget) == 1) 
      begin
       debug(avalonDebug,$display("AvalonSlave Side Read Req addr: %h", fromMaybe(0,addressInValue.wget())));
       reqFifo.enq(AvalonRequest{addr: fromMaybe(0,addressInValue.wget()),
                                 data: ?, 
                                 command: Read});
      end  
    else if(fromMaybe(0,writeInValue.wget) == 1) 
      begin
       debug(avalonDebug,$display("AvalonSlave Side Write Req: addr: %h data: %h", fromMaybe(0,addressInValue.wget()), fromMaybe(0,writedataInValue.wget())));
       reqFifo.enq(AvalonRequest{addr: fromMaybe(0,addressInValue.wget()),
                                 data: fromMaybe(0,writedataInValue.wget()), 
                                 command: Write});
      end  
  endrule

  interface AvalonSlaveWires slaveWires;

    method Action read(Bit#(1) readIn);
      readInValue.wset(readIn);  
    endmethod

    method Action write(Bit#(1) writeIn);
      writeInValue.wset(writeIn);  
    endmethod

    method Action address(Bit#(address_width) addressIn);
      addressInValue.wset(addressIn);  
    endmethod

    method Bit#(data_width) readdata();  
      return fromMaybe(0,readdataOutValue.wget);
    endmethod

    method Action writedata(Bit#(data_width) writedataValue);
      writedataInValue.wset(writedataValue);
    endmethod

    method Bit#(1) waitrequest();
      return (reqFifo.notFull)?0:1;
    endmethod

    method Bit#(1) readdatavalid();
      return (putResponseCalled)?1:0;
    endmethod

  endinterface


 interface Client busClient;
   interface Get request;
     method ActionValue#(AvalonRequest#(address_width,data_width)) get();
       reqFifo.deq;
       return reqFifo.first;
     endmethod
   endinterface 

   interface Put response;
     method Action put(Bit#(data_width) data);
       debug(avalonDebug,$display("Avalon Slave Resp"));
       readdataOutValue.wset(data);
       putResponseCalled.send;
     endmethod
   endinterface
 endinterface
endmodule


interface AvalonSlaveDriverCBusWrapper#(numeric type address_width, numeric type data_width);
  method Action putBusRequest(CBusCommand isWrite, Bit#(address_width) addr, Bit#(data_width) data);
  method ActionValue#(Bit#(data_width)) getBusResponse();
endinterface

// This function converts a CBus request to a Avalon request.  It also handles the null resp from the avalon
module mkAvalonSlaveDriverCBusWrapper#(Server#(AvalonRequest#(address_width,data_width),Bit#(data_width)) server) (AvalonSlaveDriverCBusWrapper#(address_width,data_width));
  FIFOF#(CBusCommand) commandFIFO <- mkSizedFIFOF(50); // have to story many requests.
  let lastAddr <- mkRegU;
  Reg#(Bit#(32)) reqs  <- mkReg(0);
  Reg#(Bit#(32)) resps <- mkReg(0);
  Reg#(Bit#(32)) drops <- mkReg(0);
  Reg#(Bit#(10)) counter <- mkReg(0);  

  rule fifoFull (!commandFIFO.notFull);
    $display("Warning: Avalon CBUS command fifo full");
  endrule

  rule stats;
   counter <= counter + 1;
   if(counter == 0)
     begin
       $display("CBus Wrapper stats: reqs %d resps %d drops %d lastAddr %h commandFIFO: %s", reqs, resps, drops,lastAddr,fifofState(commandFIFO));
     end
  endrule   

  rule deqNullResp(commandFIFO.first == cBusWrite);
    commandFIFO.deq;
    drops <= drops + 1;
    debug(avalonDebug,$display("Avalon CBus Wrapper Driver Null response drop"));   
    let data <- server.response.get;
  endrule

  method Action putBusRequest(CBusCommand isWrite, Bit#(address_width) addr, Bit#(data_width) data);
  AvalonRequest#(address_width,data_width) req = AvalonRequest{addr: addr,
                                                  data: data,
                                                  command: (isWrite == Read)?Read:Write};
    lastAddr <= addr;
    debug(avalonDebug,$display("Avalon CBus Wrapper Null putBusRequest addr: %h data: %h", addr, data));   
    server.request.put(req);
    reqs <= reqs + 1;
    commandFIFO.enq(isWrite);
  endmethod

  method ActionValue#(Bit#(data_width)) getBusResponse() if(commandFIFO.first == cBusRead);
    commandFIFO.deq; 
    resps <= resps + 1;  
    debug(avalonDebug,$display("Avalon Cbus Wrapper returning a response"));   
    let data <- server.response.get;
    return data;
  endmethod
endmodule



// This is a simple driver for the Avalon slave.  This might at somepoint serve as a starting point for an 
// Avalon master
module mkAvalonSlaveDriver#(AvalonSlaveWires#(address_width,data_width) slaveWires) (Server#(AvalonRequest#(address_width,data_width),Bit#(data_width)));
  FIFOF#(AvalonRequest#(address_width,data_width)) reqFIFO <- mkFIFOF;
  FIFOF#(Bit#(data_width)) respFIFO <- mkFIFOF;
  
  Reg#(Bit#(address_width)) addr <- mkReg(0); 
  Reg#(Bit#(data_width)) data <- mkReg(0);
  Reg#(Bit#(1)) read <- mkReg(0);
  Reg#(Bit#(1)) write <- mkReg(0);
  Reg#(Bit#(1)) readdatavalid <- mkReg(0);
  Reg#(Bit#(data_width)) readdata <- mkReg(0);
  PulseWire readpulse <- mkPulseWire;
  PulseWire writepulse <- mkPulseWire;

  rule setRead(readpulse);
    read <= 1;
  endrule

  rule clearRead(!readpulse);
    read <= 0;
  endrule

  rule setWrite(writepulse);
    write <= 1;
  endrule

  rule clearWrite(!writepulse);
    write <= 0;
  endrule

  rule setData (slaveWires.readdatavalid == 1);
    readdata <= slaveWires.readdata;                     
  endrule

  rule grabReaddatavalid;
   readdatavalid <= slaveWires.readdatavalid;
  endrule


  rule drivePinsRead;
    slaveWires.read(read);
  endrule

  rule drivePinsWrite;
    slaveWires.write(write);   
  endrule

  rule drivePinsAddr;
    slaveWires.address(addr);
  endrule 

  rule drivePinsData;
    slaveWires.writedata(data);
  endrule 

  Stmt readStmt = seq
                 addr <= reqFIFO.first.addr;
                 await(slaveWires.waitrequest==0);                   
                 readpulse.send;
                 await(readdatavalid == 1);                   
                 action
                   debug(avalonDebug,$display("Avalaon Master Drive enq resp addr: %h data: %h", addr, data));
                   respFIFO.enq(readdata);
                 endaction
                 reqFIFO.deq; 
              endseq;


  Stmt writeStmt = seq                
                 debug(avalonDebug,$display("Avalon Master issues write: addr: %h data: %h",reqFIFO.first.addr,reqFIFO.first.data));
                 addr <= reqFIFO.first.addr;
                 data <= reqFIFO.first.data;
                 await(slaveWires.waitrequest==0);
                 writepulse.send;
                 respFIFO.enq(?);
                 reqFIFO.deq; 
               endseq;

  FSM readFSM <- mkFSM(readStmt);
  FSM writeFSM <- mkFSM(writeStmt);

  rule usefulAssertion1 (readdatavalid == 1);
    if(!writeFSM.done)
      begin
        $display("Warning Why are we asserting readdatavalid during write?");
        $finish;
      end                   
  endrule

  rule startRead(readFSM.done && writeFSM.done && reqFIFO.first.command == Read);
    debug(avalonDebug,$display("Avalon Master starts Read FSM: addr: %h ",reqFIFO.first.addr));
    readFSM.start;
  endrule

  rule startWrite(readFSM.done && writeFSM.done && reqFIFO.first.command == Write);
    debug(avalonDebug,$display("Avalon Master starts Write FSM: addr: %h data: %h",reqFIFO.first.addr,reqFIFO.first.data));
    writeFSM.start;
  endrule

  interface Put request;
    method Action put(AvalonRequest#(address_width,data_width) req);    
      reqFIFO.enq(req);
      debug(avalonDebug,$display("Avalon Master receives request: addr: %h data: %h", req.addr, req.data));
    endmethod
  endinterface 

  interface Get response = fifoToGet(fifofToFifo(respFIFO));
 
endmodule

// Should we be using regs?
module mkAvalonSlaveDualDomain#(Clock asicClock, Reset asicReset) (AvalonSlave#(address_width,data_width));
  RWire#(Bit#(1)) readInValue <- mkRWire;
  RWire#(Bit#(1)) writeInValue <- mkRWire;
  RWire#(Bit#(address_width)) addressInValue <- mkRWire;
  RWire#(Bit#(data_width)) readdataOutValue <- mkRWire;
  RWire#(Bit#(data_width)) writedataInValue <- mkRWire;
  PulseWire putResponseCalled <- mkPulseWire;
  
  // In avalon read/write asserted for a single cycle unless 
  // waitreq also asserted.
  
  SyncFIFOIfc#(AvalonRequest#(address_width,data_width)) reqFIFO <- mkSyncFIFOFromCC(2,asicClock);
  SyncFIFOIfc#(Bit#(data_width)) respFIFO <- mkSyncFIFOToCC(2,asicClock,asicReset);
  FIFOF#(Bit#(0)) tokenFIFO <- mkSizedFIFOF(2);

  rule driveWait(!tokenFIFO.notFull && avalonDebug) ;
    $display("Warning avalon is driving wait due to token...");
  endrule

  rule driveWait2(!reqFIFO.notFull && avalonDebug) ;
    $display("Warning avalon is driving wait due to req");
  endrule

  rule driveWait3(avalonDebug);
    $display("Warning avalon req: addr:%h data:%h",reqFIFO.first.addr,reqFIFO.first.data);
  endrule

  rule produceRequest;
    //Reads and writes are assumed not to occur simultaneously.  
    if(fromMaybe(0,readInValue.wget) == 1) 
      begin
       debug(avalonDebug,$display("Avalon Slave Side Read Req: addr: %h", fromMaybe(0,addressInValue.wget())));
       tokenFIFO.enq(?);
       reqFIFO.enq(AvalonRequest{addr: fromMaybe(0,addressInValue.wget()),
                                 data: ?, 
                                 command: Read});
      end  
    else if(fromMaybe(0,writeInValue.wget) == 1) 
      begin // We are dropping data here.... need to ensure that reqFIFO has room
       debug(avalonDebug,$display("DualAvalonSlave Side Write Req"));
  
       reqFIFO.enq(AvalonRequest{addr: fromMaybe(0,addressInValue.wget()),
                                 data: fromMaybe(0,writedataInValue.wget()), 
                                 command: Write});
      end  
  endrule

  rule produceResponse;
    debug(avalonDebug,$display("Avalon Slave Resp"));
    respFIFO.deq;
    tokenFIFO.deq;
    readdataOutValue.wset(respFIFO.first); // could register these.
    putResponseCalled.send;
  endrule

  interface AvalonSlaveWires slaveWires;

    method Action read(Bit#(1) readIn);
      readInValue.wset(readIn);  
    endmethod

    method Action write(Bit#(1) writeIn);
      writeInValue.wset(writeIn);  
    endmethod

    method Action address(Bit#(address_width) addressIn);
      addressInValue.wset(addressIn);  
    endmethod

    method Bit#(data_width) readdata();  
      return fromMaybe(0,readdataOutValue.wget);
    endmethod

    method Action writedata(Bit#(data_width) writedataValue);
      writedataInValue.wset(writedataValue);
    endmethod

    method Bit#(1) waitrequest();
      return (tokenFIFO.notFull && reqFIFO.notFull)?0:1; 
    endmethod

    method Bit#(1) readdatavalid();
      return (putResponseCalled)?1:0;
    endmethod

  endinterface

 interface Client busClient;
   interface Get request;
     method ActionValue#(AvalonRequest#(address_width,data_width)) get();
       reqFIFO.deq;
       return reqFIFO.first;
     endmethod
   endinterface 

   interface Put response;
     method Action put(Bit#(data_width) data);
       debug(avalonDebug,$display("Avalon Slave Resp"));
       respFIFO.enq(data);
     endmethod
   endinterface
 endinterface

endmodule

