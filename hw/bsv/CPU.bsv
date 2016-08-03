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

import BUtils::*;
import ClientServer::*;
import ConfigReg::*;
import DefaultValue::*;
import Ethernet::*;
import FIFOF::*;
import GetPut::*;
import Pipe::*;
import TxRx::*;

import Utils::*;
import ISA_Defs::*;
import CPU_Common::*;
import UnionGenerated::*;

interface CPU;
   interface Server#(BBRequest, BBResponse) prev_control_state;
   interface Client#(IMemRequest, IMemResponse) imem_client;
   // interface to metadata memory
   method Action set_verbosity (int verbosity);
endinterface

//(* synthesize *)
module mkCPU#(List#(Reg#(Bit#(n))) ll)(CPU)
   provisos(Add#(a__, n, 64));

   Reg#(int) cf_verbosity <- mkConfigRegU;
   function Action dbprint(Integer level, Fmt msg);
      action
      if (cf_verbosity > fromInteger(level)) begin
         $display("(%0d) ", $time, msg);
      end
      endaction
   endfunction

   Reg#(CPU_State) rg_cpu_state <- mkReg(CPU_STOPPED);
   Reg#(IMemAddr)  rg_pc        <- mkReg(0);

   // Reg#() reg_file <- mkBasicBlockRegFile(); // option 2: generate RegFile for each BasicBlock;
   // Save result to ll

   // Table interface
   RX #(BBRequest) rx_prev_control_state <- mkRX;
   TX #(BBResponse) tx_prev_control_state <- mkTX;
   let rx_info_prev_control_state = rx_prev_control_state.u;
   let tx_info_prev_control_state = tx_prev_control_state.u;
   // Instruction Memory interface
   TX #(IMemRequest)  tx_imem_req <- mkTX;
   RX #(IMemResponse) rx_imem_rsp <- mkRX;
   let tx_info_imem_req = tx_imem_req.u;
   let rx_info_imem_rsp = rx_imem_rsp.u;

   Instr instr = rx_info_imem_rsp.first.data;
   Opcode opcode = instr_opcode (instr);
   let f3  = instr_funct3 (instr);
   let f7  = instr_funct7 (instr);
   let rd  = instr_rd (instr);
   let rs1 = instr_rs1 (instr);
   let rs2 = instr_rs2 (instr);

   let imm12_I = instr_imm12_I (instr);

   function Action succeed_and_next ();
      action
         rx_info_imem_rsp.deq;
         rg_pc <= rg_pc + 4;
      endaction
   endfunction

   function Action error_and_trap ();
      action
         rg_pc <= 0;
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

   rule rl_start (rg_cpu_state == CPU_STOPPED);
      dbprint(3, $format("run CPU"));
      let v = rx_info_prev_control_state.first;
      rx_info_prev_control_state.deq;
      // save v to a list of stuff;
      rg_cpu_state <= CPU_FETCH;
   endrule

   rule rl_fetch (rg_cpu_state == CPU_FETCH);
      dbprint(3, $format("Fetch"));
      let req = IMemRequest {
         command : READ,
         addr    : extend(rg_pc),
         data    : ? };
      tx_info_imem_req.enq(req);
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
      ll[v2] <= truncate(vo);
      dbprint(3, $format("OP_IMM ", fshow(f3), fshow(vo)));
      succeed_and_next();
   endrule

   // Integer Register-Register
   rule rl_exec_op_OP ((rg_cpu_state == CPU_EXEC) && (opcode == op_OP));
      Reg_Data v1 = fn_read_reg_file (rs1);
      dbprint(3, $format("OP ", fshow(f3)));
      succeed_and_next();
   endrule

   rule rl_exec_op_STORE ((rg_cpu_state == CPU_EXEC) && (opcode == op_STORE));
      Reg_Data v1 = fn_read_reg_file (rs1);
      Reg_Data iv2 = extend(unpack(imm12_I));
      Reg_Data v2 = unpack(pack(iv2));
      dbprint(3, $format("STORE ", fshow(f3)));
      succeed_and_next();
   endrule

   interface prev_control_state = toServer(rx_prev_control_state.e, tx_prev_control_state.e);
   interface imem_client = toClient(tx_imem_req.e, rx_imem_rsp.e);
   method Action set_verbosity(int verbosity);
      cf_verbosity <= verbosity;
   endmethod
endmodule
