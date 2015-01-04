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

import AvalonSlave::*;
import AvalonRegisterFile::*;
import StmtFSM::*;



module mkAvalonTester (Empty);
  AvalonSlaveWires#(4,32) regs <- mkSmallAvalonRegisterFile;

  Reg#(Bit#(4)) addr <- mkReg(0); 
  Reg#(Bit#(32)) data <- mkReg(0);
  Reg#(Bit#(32)) expected <- mkReg(0);
  Reg#(Bit#(32)) received <- mkReg(0);
  Reg#(Bit#(1)) read <- mkReg(0);
  Reg#(Bit#(1)) write <- mkReg(0);

  Stmt s = seq
             for(data <= 0; data < 2048; data<=data+1)
               seq                
                 action
                   $display("Testbench issues write");
                   await(regs.waitrequest==0);
                   write <= 1;
                   expected <= data;
                 endaction
                 write <= 0;
                 action
                   $display("Testbench issues read");
                   await(regs.waitrequest==0);                   
                   read <= 1;
                 endaction
                 while(regs.readdatavalid==0)                   
                   action
                     $display("Testbench awaits read resp");
                     read <= 0;                   
                     received <= regs.readdata; 
                   endaction
                 action
                   read <= 0;                   
                   received <= regs.readdata; 
                 endaction
                 if(received != expected)
                   seq
                     $display("Expected: %d, Received: %d", received, expected);
                     $finish;
                   endseq
                 else
                   seq
                     $display("Expected: %d @ %d, Received: %d", received, addr, expected);
                   endseq
                 addr <= addr + 7;                  
               endseq
             $display("PASS");
             $finish; 
           endseq;

  FSM fsm <- mkFSM(s);

  rule drivePins;
    regs.read(read);
    regs.write(write);   
    regs.address(addr);
    regs.writedata(data);
  endrule   
 
 
  rule startFSM;
    fsm.start;
  endrule

endmodule


