package Tb;

import GetPut::*;
import ClientServer::*;
import StmtFSM::*;
import FIFO::*;
import Pipe::*;

import PriorityEncoder::*;
import Ram9b::*;
import TcamTypes::*;
import Tcam::*;

function Stmt testSeq(TernaryCam#(256, 9) dut,
                      String dut_name);
    return seq
        noAction;
        action
            dut.writeServer.put(TcamWriteReq{addr:'h1, data:'h0, mask:'h1ff});
        endaction
//        delay(600);
//        action
//            dut.writeServer.put(TcamWriteReq{addr:'h2, data:'h0, mask:'h1ff});
//        endaction
//        delay(600);
//        action
//            dut.writeServer.put(TcamWriteReq{addr:'h3, data:'h0, mask:'h1ff});
//        endaction
//        delay(600);
//        action
//            dut.writeServer.put(TcamWriteReq{addr:'h4, data:'h0, mask:'h1ff});
//        endaction
        delay(600);
        action
            dut.readServer.request.put('h0);
        endaction
        delay(10);
        action
            let v <- dut.readServer.response.get;
            $display("read result=%x", fromMaybe(?,v));
        endaction
        delay(100);
   endseq;
endfunction

(* synthesize *)
module mkTb (Empty);
   TernaryCam#(256, 9) tcam <- mkTernaryCam();
   mkAutoFSM(testSeq(tcam, "tcam"));
endmodule: mkTb

endpackage: Tb
