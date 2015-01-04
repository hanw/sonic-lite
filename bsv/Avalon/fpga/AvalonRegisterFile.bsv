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

`include "asim/provides/register_mapper.bsh"

import RegFile::*;
import ClientServer::*;
import GetPut::*;

(*synthesize*)
module mkSmallAvalonRegisterFile (AvalonSlaveWires#(4,32));
  let m <- mkAvalonRegisterFile;
  return m;
endmodule

module mkAvalonRegisterFile (AvalonSlaveWires#(addr_size,data_size));
  Reset reset <- exposeCurrentReset;
  Clock clock <- exposeCurrentClock;
  AvalonSlave#(addr_size,data_size) avalonSlave <- mkAvalonSlave(clock, reset);
  RegFile#(Bit#(addr_size),Bit#(data_size)) regs <- mkRegFileFull();

  rule handleReqs;
    AvalonRequest#(addr_size,data_size) req <- avalonSlave.busClient.request.get;
    if(req.command == Write)
      begin
        regs.upd(req.addr,req.data);
      end
    else
      begin
         avalonSlave.busClient.response.put(regs.sub(req.addr));
      end
  endrule

  return avalonSlave.slaveWires;

endmodule