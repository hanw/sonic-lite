package Tb;

import GetPut::*;
import ClientServer::*;
import StmtFSM::*;
import FIFO::*;
import Pipe::*;

// ----------------
// Imports for the design
import IdxVacRam::*;
import Setram::*;
import PriorityEncoder::*;
import Ram9b::*;
import BcamTypes::*;
import Bcam::*;

function Stmt testSeq(BinaryCam#(1024, 9) dut,
                      String dut_name);
    return seq
        noAction;
        action
            dut.writeServer.put(tuple2('h0, 'h0));
        endaction
        delay(100);
        action
            dut.writeServer.put(tuple2('h1, 'h1));
        endaction
        delay(100);
        action
            dut.writeServer.put(tuple2('h2, 'h2));
        endaction
        delay(100);
        action
            dut.writeServer.put(tuple2('h3, 'h3));
        endaction
        delay(100);
        action
            dut.writeServer.put(tuple2('h4, 'h4));
        endaction
        delay(100);
        action
            dut.writeServer.put(tuple2('h5, 'h5));
        endaction
        delay(10);
        action
            dut.readServer.request.put('h0);
        endaction
        delay(10);
        action
            let v <- dut.readServer.response.get;
            $display("read result=%x", fromMaybe(?,v));
        endaction
        delay(10);
        action
            dut.readServer.request.put('h1);
        endaction
        delay(10);
        action
            let v <- dut.readServer.response.get;
            $display("read result=%x", fromMaybe(?,v));
        endaction
        delay(10);
        action
            dut.readServer.request.put('h2);
        endaction
        delay(10);
        action
            let v <- dut.readServer.response.get;
            $display("read result=%x", fromMaybe(?,v));
        endaction
        delay(10);
        action
            dut.readServer.request.put('h3);
        endaction
        delay(10);
        action
            let v <- dut.readServer.response.get;
            $display("read result=%x", fromMaybe(?,v));
        endaction
        delay(10);
        action
            dut.readServer.request.put('h4);
        endaction
        delay(10);
        action
            let v <- dut.readServer.response.get;
            $display("read result=%x", fromMaybe(?,v));
        endaction
        delay(10);
        action
            dut.readServer.request.put('h5);
        endaction
        delay(10);
        action
            let v <- dut.readServer.response.get;
            $display("read result=%x", fromMaybe(?,v));
        endaction
   endseq;
endfunction

(* synthesize *)
module mkTb (Empty);

   BinaryCam#(1024, 9) bcam <- mkBinaryCamBSV();

   mkAutoFSM(testSeq(bcam, "bcam"));

endmodule: mkTb

endpackage: Tb
