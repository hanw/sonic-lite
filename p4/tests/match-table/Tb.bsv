package Tb;

import GetPut::*;
import ClientServer::*;
import StmtFSM::*;
import FIFO::*;
import Pipe::*;
import MatchTable::*;
import MatchTableTypes::*;

function Stmt testSeq(MatchTable dut,
                      String dut_name);
   return seq
      action
         ActionSpec_t act = ActionSpec_t{action_ops: 'h2};
         MatchSpec_t mat = MatchSpec_t{data:'h2, param: act};
         dut.add_entry.put(mat);
      endaction
      delay(20);
      action
         dut.readPort.request.put('h3);
      endaction
      delay(20);
      action
         dut.lookupPort.request.put('h1);
      endaction
      delay(20);
   endseq;
endfunction

(* synthesize *)
module mkTb (Empty);
   MatchTable match_table <- mkMatchTable();
   mkAutoFSM(testSeq(match_table, "match table"));
endmodule: mkTb

endpackage: Tb
