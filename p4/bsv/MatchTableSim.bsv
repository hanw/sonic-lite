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

import FIFO::*;
import FIFOF::*;
import GetPut::*;
import ClientServer::*;
import StmtFSM::*;
import Vector::*;
import DefaultValue::*;
import BRAM::*;
import FShow::*;
import Pipe::*;
import Bcam::*;
import BcamTypes::*;

import "BDPI" function ActionValue#(Bit#(10)) matchtable_read_dmac(Bit#(54) dstAddr);
import "BDPI" function Action matchtable_write_dmac(Bit#(54) dstAddr, Bit#(10) data);
import "BDPI" function ActionValue#(Bit#(2)) matchtable_read_acceptor(Bit#(18) msgtype);
import "BDPI" function Action matchtable_write_acceptor(Bit#(18) msgtype, Bit#(2) data);
import "BDPI" function ActionValue#(Bit#(1)) matchtable_read_sequence(Bit#(18) msgtype);
import "BDPI" function Action matchtable_write_sequence(Bit#(18) msgtype, Bit#(1) data);

instance MatchTableSim#(54, 10);
   function ActionValue#(Bit#(10)) matchtable_read(Bit#(54) key);
   actionvalue
      let v <- matchtable_read_dmac(key);
      return v;
   endactionvalue
   endfunction
   function Action matchtable_write(Bit#(54) key, Bit#(10) data);
   action
      $display("(%0d) matchtable write dmac %h %h", $time, key, data);
      matchtable_write_dmac(key, data);
      $display("(%0d) matchtable write dmac done", $time);
   endaction
   endfunction
endinstance

instance MatchTableSim#(18, 1);
   function ActionValue#(Bit#(1)) matchtable_read(Bit#(18) key);
   actionvalue
      let v <- matchtable_read_sequence(key);
      return v;
   endactionvalue
   endfunction
   function Action matchtable_write(Bit#(18) key, Bit#(1) data);
   action
      matchtable_write_sequence(key, data);
   endaction
   endfunction
endinstance

instance MatchTableSim#(18, 2);
   function ActionValue#(Bit#(2)) matchtable_read(Bit#(18) key);
   actionvalue
      let v <- matchtable_read_acceptor(key);
      return v;
   endactionvalue
   endfunction
   function Action matchtable_write(Bit#(18) key, Bit#(2) data);
   action
      $display("(%0d) matchtable write acceptor %h %h", $time, key, data);
      matchtable_write_acceptor(key, data);
      $display("(%0d) matchtable write acceptor done", $time);
   endaction
   endfunction
endinstance


