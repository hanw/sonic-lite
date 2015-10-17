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
            Bit#(10) wAddr = 'h302;
            Bit#(9) wData = 'h24;
            $display("%t === %s write addr=%x data=%x",$time, dut_name, wAddr, wData);
            dut.writeServer.put(tuple2(wAddr, wData));
        endaction
        delay(100);
        action
            Bit#(9) rData = 'h24;
            $display("%t === %s read data=%x",$time, dut_name, rData);
            dut.readServer.request.put(rData);
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

   BinaryCam#(1024, 9) bcam <- mkBinaryCam();

   mkAutoFSM(testSeq(bcam, "bcam"));

endmodule: mkTb

endpackage: Tb
