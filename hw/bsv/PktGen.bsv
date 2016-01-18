
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
    method Action clear();
endinterface

module mkPktGen(PktGen)
   provisos (Div#(`DataBusWidth, 8, bytesPerBeat)
            ,Log#(bytesPerBeat, beatShift));

    Reg#(Bit#(32)) traceLen <- mkReg(0);
    Reg#(Bit#(32)) count <- mkReg(0);
    Reg#(Bit#(32)) iteration <- mkReg(0);
    Reg#(Bit#(32)) total_ipg <- mkReg(0);
    Reg#(Bool) started <- mkReg(False);
    Reg#(Bool) halt <- mkReg(False);
    Reg#(Bool) idle <- mkReg(False);
    Reg#(Bit#(32)) curr_ipg <- mkReg(0);

    FIFO#(EtherData) outgoing_fifo <- mkFIFO();
    PacketBuffer buff <- mkPacketBuffer();

    rule fetch_packet if (started && !halt && !idle);
        let pktLen <- buff.readServer.readLen.get;
        buff.readServer.readReq.put(EtherReq{len:pktLen});
        $display("Pktgen:: fetch_packet");
    endrule

    rule enqueue_packet if (started && !halt && !idle);
        let data <- buff.readServer.readData.get;
        buff.writeServer.writeData.put(data);
        outgoing_fifo.enq(data);
        if (data.eop) begin
            count <= count + 1;
            idle <= True;
            curr_ipg <= 0;
            $display("Pktgen:: eop %h %h %h %h %h", halt, idle, started, curr_ipg, total_ipg);
        end
    endrule

    rule terminate if (started && (count >= iteration));
        halt <= True;
    endrule

    rule gen_ipg if ((curr_ipg < total_ipg + fromInteger(valueOf(MinimumIPG))) && idle);
        curr_ipg <= curr_ipg + fromInteger(valueOf(bytesPerBeat));
        $display("Pktgen:: ipg = %d", curr_ipg);
    endrule

    rule next_packet if ((curr_ipg >= total_ipg + fromInteger(valueOf(MinimumIPG))));
        EtherData v = defaultValue;
        idle <= False;
        curr_ipg <= 0;
    endrule

    interface PktWriteServer writeServer;
        interface Put writeData;
            method Action put (EtherData d);
                buff.writeServer.writeData.put(d);
                if (d.eop) begin
                    traceLen <= traceLen + 1;
                end
            endmethod
        endinterface
    endinterface
    interface PktWriteClient writeClient;
        interface Get writeData = toGet(outgoing_fifo);
    endinterface
    method Action clear();
    endmethod
    method Action start(Bit#(32) iter, Bit#(32) ipg) if (!started);
        started <= True;
        halt <= False;
        total_ipg <= ipg;
        iteration <= iter;
        $display("Pktgen:: start %h %h", iter, ipg);
    endmethod
    method Action stop() if (started);
        started <= False;
    endmethod
endmodule

