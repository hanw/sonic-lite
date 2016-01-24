
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

import FIFO::*;
import FIFOF::*;
import DefaultValue::*;
import Vector::*;
import BuildVector::*;
import GetPut::*;
import ClientServer::*;
import Connectable::*;
import Clocks::*;
import Gearbox::*;
import Pipe::*;
import Ethernet::*;
import PacketBuffer::*;

typedef 1 MinimumIPG; // 1 beat == 16 bytes.

interface PktGen;
    interface PktWriteServer writeServer;
    interface PktWriteClient writeClient;
    method Action start(Bit#(32) iter, Bit#(32) ipg);
    method Action stop();
endinterface

module mkPktGen(PktGen)
   provisos (Div#(`DataBusWidth, 8, bytesPerBeat)
            ,Log#(bytesPerBeat, beatShift));

   Reg#(Bit#(32)) traceLen <- mkReg(0);
   Reg#(Bit#(32)) pktCount <- mkReg(0);
   Reg#(Bit#(32)) ipgCount <- mkReg(0);
   Reg#(Bool) idle <- mkReg(False);
   Reg#(Bit#(32)) currIPG <- mkReg(0);
   Reg#(Bool) started <- mkReg(False);

   FIFO#(EtherData) outgoing_fifo <- mkFIFO();
   PacketBuffer buff <- mkPacketBuffer();

   rule prepare_packet if (pktCount>0 && !idle);
      let pktLen <- buff.readServer.readLen.get;
      buff.readServer.readReq.put(EtherReq{len:pktLen});
      $display("Pktgen:: fetch_packet pktlen=%h", pktLen);
   endrule

   rule enqueue_packet if (pktCount>0 && !idle);
      let data <- buff.readServer.readData.get;
      buff.writeServer.writeData.put(data);
      outgoing_fifo.enq(data);

      if (data.eop) begin
         pktCount <= pktCount - 1;
         idle <= True;
         currIPG <= 0;
         $display("Pktgen:: eop %h %h %h %h", idle, started, currIPG, ipgCount);
      end
   endrule

   rule compute_idle if (pktCount>0 && idle);
      if (currIPG < ipgCount + fromInteger(valueOf(MinimumIPG))) begin
         currIPG <= currIPG + fromInteger(valueOf(bytesPerBeat));
         $display("Pktgen:: ipg = %d", currIPG);
      end
      else begin
         currIPG <= 0;
         idle <= False;
      end
   endrule

   // has to drain buffer at the end of packet generation
   rule cleanup if (pktCount==0 && traceLen>0 && started);
      let pktLen <- buff.readServer.readLen.get;
      buff.readServer.readReq.put(EtherReq{len: pktLen});
      $display("Pktgen:: drain buffer");
   endrule

   rule drainBufferPayload if (pktCount==0 && traceLen>0 && started);
      let data <- buff.readServer.readData.get;
      // do nothing
      $display("Pktgen:: drain buffer payload");
      if (data.eop) begin
         traceLen <= traceLen - 1;
      end
   endrule

   rule drainFinished if (pktCount==0 && traceLen==0 && started);
      started <= False;
   endrule

   interface PktWriteServer writeServer;
      interface Put writeData;
         method Action put (EtherData d);
            buff.writeServer.writeData.put(d);
            $display("Pktgen:: write data", fshow(d));
            if (d.eop) begin
               traceLen <= traceLen + 1;
            end
         endmethod
      endinterface
   endinterface
   interface PktWriteClient writeClient;
       interface Get writeData = toGet(outgoing_fifo);
   endinterface
   method Action start(Bit#(32) pc, Bit#(32) ipg) if (pktCount==0 && traceLen!=0);
      started <= True;
      ipgCount <= ipg;
      pktCount <= pc;
      $display("Pktgen:: start %h %h", pc, ipg);
   endmethod
endmodule

