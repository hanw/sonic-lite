
// Copyright (c) 2014 Cornell University.

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

package Utils;

import FIFOF::*;
import Vector::*;

typedef 8'h07 Idle;
typedef 8'h55 Preamble;
typedef 8'hfb Start;
typedef 8'hd5 Sfd;
typedef 8'hfd Terminate;
typedef 8'hfe Error;
typedef 8'h9c Sequence;

typedef 8'd1  LocalFault;
typedef 8'd2  RemoteFault;

typedef 48'h010000c28001 PauseFrame;

typedef 2'd0  LINK_FAULT_OK;
typedef 2'd1  LINK_FAULT_LOCAL;
typedef 2'd2  LINK_FAULT_REMOTE;
typedef 1'b0  FAULT_SEQ_LOCAL;
typedef 1'b1  FAULT_SEQ_REMOTE;

typedef struct {
   Bit#(64) data;
   Bit#(8) ctrl;
} XgmiiTup deriving (Eq, Bits);

function alpha byteSwap(alpha w)
   provisos (Bits#(alpha, asz),
             Div#(asz, 8, avec),
             Bits#(Vector::Vector#(avec, Bit#(8)), asz));
   Vector#(avec, Bit#(8)) bytes = unpack(pack(w));
   return unpack(pack(reverse(bytes)));
endfunction

function Bool fifoNotEmpty(FIFOF#(a) fifo);
   return fifo.notEmpty();
endfunction

typeclass DefaultMask#(type t);
   t defaultMask;
endtypeclass

endpackage
