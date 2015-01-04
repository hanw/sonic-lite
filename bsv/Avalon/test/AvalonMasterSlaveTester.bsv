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

import GetPut::*;
import ClientServer::*;
import StmtFSM::*;

`include "asim/provides/register_mapper.bsh"
`include "asim/provides/avalon.bsh"


module mkHWOnlyApplication (Empty);
  Clock clock <- exposeCurrentClock;
  Reset reset <- exposeCurrentReset;
  AvalonSlaveWires#(4,32) regs <- mkSmallAvalonRegisterFile;
  AvalonMaster#(4,32) regDriver <- mkAvalonMaster;

  Reg#(Bit#(4)) addr <- mkReg(0); 
  Reg#(Bit#(32)) data <- mkReg(0);
  Reg#(Bit#(32)) expected <- mkReg(0);
  Reg#(Bit#(32)) received <- mkReg(0);
  Reg#(Bit#(1)) read <- mkReg(0);
  Reg#(Bit#(1)) write <- mkReg(0);

  Stmt s = seq
             for(data <= 0; data < 2048; data<=data+1)
               seq                
                 regDriver.busServer.request.put(AvalonRequest{addr:truncate(data), data: data, command: Write});
		 regDriver.busServer.request.put(AvalonRequest{addr:truncate(data), data: data, command: Read});
                 action
                    let in <- regDriver.busServer.response.get();
                    if(in != data) 
                      begin
                        $display("Got %h at %h, expected %h", in, data, data);
                        $finish;
                      end
                 endaction
               endseq
               $display("PASS");
               $finish;
           endseq;

  FSM fsm <- mkFSM(s);

  rule drivePinsFromSlave;
   regDriver.masterWires.readdata(regs.readdata);
   regDriver.masterWires.readdatavalid(regs.readdatavalid);
  endrule

  rule otherDriver;
    regDriver.masterWires.waitrequest(regs.waitrequest);
  endrule

  rule drivePinsToSlave;
    regs.read(regDriver.masterWires.read);
    regs.write(regDriver.masterWires.write);   
    regs.address(regDriver.masterWires.address);
    regs.writedata(regDriver.masterWires.writedata);
  endrule   
 
 
  rule startFSM;
    fsm.start;
  endrule

endmodule


