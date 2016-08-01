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

// A miniature RISC-V based CPU for packet processing
// No branch
// No memory load/store
// No floating point

import ClientServer::*;
import FIFOF::*;
import ISA_Defs::*;
import CPU_Common::*;

interface CPU;
   // interface to table
   // Rxe

   interface Client#(IMemRequest, IMemResponse) imem;
   // interface to metadata memory
   // Rxe
   // Txe
endinterface

(* synthesize *)
module mkCPU(CPU);

   Reg#(CPU_State) rg_cpu_state <- mkReg(CPU_STOPPED);
   Reg#(IMemAddr)     rg_pc        <- mkReg(0);

   // Generated registers
   // Reg#() reg_file <- mkBasicBlockRegFile(); // option 2: generate RegFile for each BasicBlock;

   // Commit to metadata memory; // to save resource consumed by metadata

   // Memory interface
   FIFOF#(IMemRequest)  imem_req_ff <- mkFIFOF;
   FIFOF#(IMemResponse) imem_rsp_ff <- mkFIFOF;

   Instr instr = imem_rsp_ff.first.data;
   Opcode opcode = instr_opcode (instr);
   let f3  = instr_funct3 (instr);
   let f7  = instr_funct7 (instr);
   let rd  = instr_rd (instr);
   let rs1 = instr_rs1 (instr);
   let rs2 = instr_rs2 (instr);

   let imm12_I = instr_imm12_I (instr);

   function Action succeed_and_next ();
      action
      // rg_pc = rg_pc + 4;
      endaction
   endfunction

   function Action error_and_trap ();
      action
      // rg_pc = 0;
      endaction
   endfunction

   function Reg_Data fn_read_reg_file (RegIdx idx);
      if (idx == 0) begin
         return 0;
      end
      else begin
         //reg_file.read(idx);
         return 0;
      end
   endfunction

   function Action fn_write_reg_file (RegIdx idx, Reg_Data vo);
      action
         if (idx != 0) begin
            // reg_file.write(idx);
         end
      endaction
   endfunction

   rule rl_fetch (rg_cpu_state == CPU_FETCH);
      let req = IMemRequest {
         command : READ,
         addr    : extend(rg_pc),
         data    : ? };
      imem_req_ff.enq(req);
      rg_cpu_state <= CPU_EXEC;
   endrule

   // Integer Register-Immediate
   rule rl_exec_op_IMM ((rg_cpu_state == CPU_EXEC) && (opcode == op_OP_IMM));
      Reg_Data v1 = fn_read_reg_file (rs1);
      Reg_Data iv2 = extend(unpack(imm12_I));
      Reg_Data v2 = unpack(pack(iv2));

      Bool illegal = False;
      Reg_Data vo = ?;

      if      (f3 == f3_ADDI) vo = pack(v1 + v2);
      else if (f3 == f3_ANDI) vo = pack(v1 & v2);
      else    illegal = True;

      if (! illegal) begin
         fn_write_reg_file (rd, vo);
      end
   endrule

   // Integer Register-Register
   rule rl_exec_op_OP ((rg_cpu_state == CPU_EXEC) && (opcode == op_OP));
      Reg_Data v1 = fn_read_reg_file (rs1);
      // operate on it
      // vo = compute;
      // write data back
      // fn_write_reg_file (idx, vo);
   endrule
endmodule
