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
import PriorityEncoderEfficient::*;
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
        delay(100);
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
   endseq;
endfunction

function Stmt testSeq2(PEnc#(1024) dut,
                      String dut_name);
    return seq
      noAction;
      action
         dut.oht.put(1024'h0001);
      endaction
        delay(10);
      action
         let v <- dut.vld.get;
         let b <- dut.bin.get;
         $display("read v=%x, b=%x", v, b);
      endaction
      action
         dut.oht.put(1024'h0002);
      endaction
        delay(10);
      action
         let v <- dut.vld.get;
         let b <- dut.bin.get;
         $display("read v=%x, b=%x", v, b);
      endaction
      action
         dut.oht.put(1024'h0004);
      endaction
        delay(10);
      action
         let v <- dut.vld.get;
         let b <- dut.bin.get;
         $display("read v=%x, b=%x", v, b);
      endaction
      action
         dut.oht.put(1024'h0008);
      endaction
        delay(10);
      action
         let v <- dut.vld.get;
         let b <- dut.bin.get;
         $display("read v=%x, b=%x", v, b);
      endaction
      action
         dut.oht.put(1024'h0010);
      endaction
        delay(10);
      action
         let v <- dut.vld.get;
         let b <- dut.bin.get;
         $display("read v=%x, b=%x", v, b);
      endaction
      action
         dut.oht.put(1024'h0020);
      endaction
        delay(10);
      action
         let v <- dut.vld.get;
         let b <- dut.bin.get;
         $display("read v=%x, b=%x", v, b);
      endaction
      action
         dut.oht.put(1024'h0040);
      endaction
        delay(10);
      action
         let v <- dut.vld.get;
         let b <- dut.bin.get;
         $display("read v=%x, b=%x", v, b);
      endaction
      action
         dut.oht.put(1024'h0080);
      endaction
        delay(10);
      action
         let v <- dut.vld.get;
         let b <- dut.bin.get;
         $display("read v=%x, b=%x", v, b);
      endaction
      action
         dut.oht.put(1024'h0100);
      endaction
        delay(10);
      action
         let v <- dut.vld.get;
         let b <- dut.bin.get;
         $display("read v=%x, b=%x", v, b);
      endaction
      action
         dut.oht.put(1024'h0200);
      endaction
        delay(10);
      action
         let v <- dut.vld.get;
         let b <- dut.bin.get;
         $display("read v=%x, b=%x", v, b);
      endaction
      action
         dut.oht.put(1024'h0400);
      endaction
        delay(10);
      action
         let v <- dut.vld.get;
         let b <- dut.bin.get;
         $display("read v=%x, b=%x", v, b);
      endaction
      action
         dut.oht.put(1024'h0800);
      endaction
        delay(10);
      action
         let v <- dut.vld.get;
         let b <- dut.bin.get;
         $display("read v=%x, b=%x", v, b);
      endaction
      action
         dut.oht.put(1024'h1000);
      endaction
        delay(10);
      action
         let v <- dut.vld.get;
         let b <- dut.bin.get;
         $display("read v=%x, b=%x", v, b);
      endaction
      action
         dut.oht.put(1024'h2000);
      endaction
        delay(10);
      action
         let v <- dut.vld.get;
         let b <- dut.bin.get;
         $display("read v=%x, b=%x", v, b);
      endaction
      action
         dut.oht.put(1024'h4000);
      endaction
        delay(10);
      action
         let v <- dut.vld.get;
         let b <- dut.bin.get;
         $display("read v=%x, b=%x", v, b);
      endaction
      action
         dut.oht.put(1024'h8000);
      endaction
        delay(10);
      action
         let v <- dut.vld.get;
         let b <- dut.bin.get;
         $display("read v=%x, b=%x", v, b);
      endaction
   endseq;
endfunction

(* synthesize *)
module mkTb (Empty);

   BinaryCam#(1024, 9) bcam <- mkBinaryCam_1024_9();
   //PEnc#(1024) pe <- mkPriorityEncoder();

   mkAutoFSM(testSeq(bcam, "bcam"));
   //mkAutoFSM(testSeq2(pe, "pe"));

endmodule: mkTb

endpackage: Tb
