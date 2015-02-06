
/*
   /home/hwang/dev/sonic-lite/scripts/../../connectal//generated/scripts/importbvi.py
   -o
   ALTERA_PCIE_DMA_WRAP.bsv
   -I
   PcieDmaWrap
   -P
   PcieDmaWrap
   -c
   clk_mm_clk
   -r
   reset_mm_reset_n
   -c
   core_clk_clk
   -c
   clk_net_clk
   -r
   pcie_rstn_pin_perst
   -r
   pcie_rstn_npor
   -c
   pcie_clk_clk
   -f
   memory
   -f
   oct
   -f
   hip_serial
   -f
   net_avm
   ../../connectal/out/de5/synthesis/pcie_dma.v
*/

import Clocks::*;
import DefaultValue::*;
import XilinxCells::*;
import GetPut::*;

(* always_ready, always_enabled *)
(* always_ready, always_enabled *)
interface PciedmawrapCore;
    interface Clock     clk_clk;
endinterface
(* always_ready, always_enabled *)
interface PciedmawrapHip_serial;
    method Action      rx_in0(Bit#(1) v);
    method Action      rx_in1(Bit#(1) v);
    method Action      rx_in2(Bit#(1) v);
    method Action      rx_in3(Bit#(1) v);
    method Action      rx_in4(Bit#(1) v);
    method Action      rx_in5(Bit#(1) v);
    method Action      rx_in6(Bit#(1) v);
    method Action      rx_in7(Bit#(1) v);
    method Bit#(1)     tx_out0();
    method Bit#(1)     tx_out1();
    method Bit#(1)     tx_out2();
    method Bit#(1)     tx_out3();
    method Bit#(1)     tx_out4();
    method Bit#(1)     tx_out5();
    method Bit#(1)     tx_out6();
    method Bit#(1)     tx_out7();
endinterface
(* always_ready, always_enabled *)
interface PciedmawrapMemory;
    method Bit#(14)     mem_a();
    method Bit#(3)     mem_ba();
    method Bit#(1)     mem_cas_n();
    method Bit#(1)     mem_ck();
    method Bit#(1)     mem_ck_n();
    method Bit#(1)     mem_cke();
    method Bit#(1)     mem_cs_n();
    method Bit#(8)     mem_dm();
    interface Inout#(Bit#(64))     mem_dq;
    interface Inout#(Bit#(8))     mem_dqs;
    interface Inout#(Bit#(8))     mem_dqs_n;
    method Bit#(1)     mem_odt();
    method Bit#(1)     mem_ras_n();
    method Bit#(1)     mem_reset_n();
    method Bit#(1)     mem_we_n();
endinterface
(* always_ready, always_enabled *)
interface PciedmawrapNet_avm;
    method Bit#(26)     address();
    method Bit#(1)     burstcount();
    method Bit#(4)     byteenable();
    method Bit#(1)     debugaccess();
    method Bit#(1)     read();
    method Action      readdata(Bit#(32) v);
    method Action      readdatavalid(Bit#(1) v);
    method Action      waitrequest(Bit#(1) v);
    method Bit#(1)     write();
    method Bit#(32)     writedata();
endinterface
(* always_ready, always_enabled *)
interface PciedmawrapOct;
    method Action      rzqin(Bit#(1) v);
endinterface
(* always_ready, always_enabled *)
(* always_ready, always_enabled *)
(* always_ready, always_enabled *)
interface PcieDmaWrap;
    interface PciedmawrapCore     core;
    interface PciedmawrapHip_serial     hip_serial;
    interface PciedmawrapMemory     memory;
    interface PciedmawrapNet_avm     net_avm;
    interface PciedmawrapOct     oct;
endinterface
import "BVI" pcie_dma =
module mkPcieDmaWrap#(Clock clk_mm_clk, Clock clk_net_clk, Clock pcie_clk_clk, Reset clk_mm_clk_reset, Reset clk_net_clk_reset, Reset pcie_clk_clk_reset, Reset pcie_rstn_npor, Reset pcie_rstn_pin_perst, Reset reset_mm_reset_n)(PcieDmaWrap);
    default_clock clk();
    default_reset rst();
        input_clock clk_mm_clk(clk_mm_clk) = clk_mm_clk;
        input_reset clk_mm_clk_reset() = clk_mm_clk_reset; /* from clock*/
        input_clock clk_net_clk(clk_net_clk) = clk_net_clk;
        input_reset clk_net_clk_reset() = clk_net_clk_reset; /* from clock*/
        input_clock pcie_clk_clk(pcie_clk_clk) = pcie_clk_clk;
        input_reset pcie_clk_clk_reset() = pcie_clk_clk_reset; /* from clock*/
        input_reset pcie_rstn_npor(pcie_rstn_npor) = pcie_rstn_npor;
        input_reset pcie_rstn_pin_perst(pcie_rstn_pin_perst) = pcie_rstn_pin_perst;
        input_reset reset_mm_reset_n(reset_mm_reset_n) = reset_mm_reset_n;
    interface PciedmawrapCore     core;
        output_clock clk_clk(core_clk_clk);
    endinterface
    interface PciedmawrapHip_serial     hip_serial;
        method rx_in0(hip_serial_rx_in0) enable((*inhigh*) EN_hip_serial_rx_in0);
        method rx_in1(hip_serial_rx_in1) enable((*inhigh*) EN_hip_serial_rx_in1);
        method rx_in2(hip_serial_rx_in2) enable((*inhigh*) EN_hip_serial_rx_in2);
        method rx_in3(hip_serial_rx_in3) enable((*inhigh*) EN_hip_serial_rx_in3);
        method rx_in4(hip_serial_rx_in4) enable((*inhigh*) EN_hip_serial_rx_in4);
        method rx_in5(hip_serial_rx_in5) enable((*inhigh*) EN_hip_serial_rx_in5);
        method rx_in6(hip_serial_rx_in6) enable((*inhigh*) EN_hip_serial_rx_in6);
        method rx_in7(hip_serial_rx_in7) enable((*inhigh*) EN_hip_serial_rx_in7);
        method hip_serial_tx_out0 tx_out0();
        method hip_serial_tx_out1 tx_out1();
        method hip_serial_tx_out2 tx_out2();
        method hip_serial_tx_out3 tx_out3();
        method hip_serial_tx_out4 tx_out4();
        method hip_serial_tx_out5 tx_out5();
        method hip_serial_tx_out6 tx_out6();
        method hip_serial_tx_out7 tx_out7();
    endinterface
    interface PciedmawrapMemory     memory;
        method memory_mem_a mem_a();
        method memory_mem_ba mem_ba();
        method memory_mem_cas_n mem_cas_n();
        method memory_mem_ck mem_ck();
        method memory_mem_ck_n mem_ck_n();
        method memory_mem_cke mem_cke();
        method memory_mem_cs_n mem_cs_n();
        method memory_mem_dm mem_dm();
        ifc_inout mem_dq(memory_mem_dq) reset_by(no_reset);
        ifc_inout mem_dqs(memory_mem_dqs) reset_by(no_reset);
        ifc_inout mem_dqs_n(memory_mem_dqs_n) reset_by(no_reset);
        method memory_mem_odt mem_odt();
        method memory_mem_ras_n mem_ras_n();
        method memory_mem_reset_n mem_reset_n();
        method memory_mem_we_n mem_we_n();
    endinterface
    interface PciedmawrapNet_avm     net_avm;
        method net_avm_address address() clocked_by(clk_net_clk) reset_by(no_reset);
        method net_avm_burstcount burstcount() clocked_by(clk_net_clk) reset_by(no_reset);
        method net_avm_byteenable byteenable() clocked_by(clk_net_clk) reset_by(no_reset);
        method net_avm_debugaccess debugaccess() clocked_by(clk_net_clk) reset_by(no_reset);
        method net_avm_read read() clocked_by(clk_net_clk) reset_by(no_reset);
        method readdata(net_avm_readdata) enable((*inhigh*) EN_net_avm_readdata) clocked_by(clk_net_clk) reset_by(no_reset);
        method readdatavalid(net_avm_readdatavalid) enable((*inhigh*) EN_net_avm_readdatavalid) clocked_by(clk_net_clk) reset_by(no_reset);
        method waitrequest(net_avm_waitrequest) enable((*inhigh*) EN_net_avm_waitrequest) clocked_by(clk_net_clk) reset_by(no_reset);
        method net_avm_write write() clocked_by(clk_net_clk) reset_by(no_reset);
        method net_avm_writedata writedata() clocked_by(clk_net_clk) reset_by(no_reset);
    endinterface
    interface PciedmawrapOct     oct;
        method rzqin(oct_rzqin) enable((*inhigh*) EN_oct_rzqin);
    endinterface
    schedule (hip_serial.rx_in0, hip_serial.rx_in1, hip_serial.rx_in2, hip_serial.rx_in3, hip_serial.rx_in4, hip_serial.rx_in5, hip_serial.rx_in6, hip_serial.rx_in7, hip_serial.tx_out0, hip_serial.tx_out1, hip_serial.tx_out2, hip_serial.tx_out3, hip_serial.tx_out4, hip_serial.tx_out5, hip_serial.tx_out6, hip_serial.tx_out7, memory.mem_a, memory.mem_ba, memory.mem_cas_n, memory.mem_ck, memory.mem_ck_n, memory.mem_cke, memory.mem_cs_n, memory.mem_dm, memory.mem_odt, memory.mem_ras_n, memory.mem_reset_n, memory.mem_we_n, net_avm.address, net_avm.burstcount, net_avm.byteenable, net_avm.debugaccess, net_avm.read, net_avm.readdata, net_avm.readdatavalid, net_avm.waitrequest, net_avm.write, net_avm.writedata, oct.rzqin) CF (hip_serial.rx_in0, hip_serial.rx_in1, hip_serial.rx_in2, hip_serial.rx_in3, hip_serial.rx_in4, hip_serial.rx_in5, hip_serial.rx_in6, hip_serial.rx_in7, hip_serial.tx_out0, hip_serial.tx_out1, hip_serial.tx_out2, hip_serial.tx_out3, hip_serial.tx_out4, hip_serial.tx_out5, hip_serial.tx_out6, hip_serial.tx_out7, memory.mem_a, memory.mem_ba, memory.mem_cas_n, memory.mem_ck, memory.mem_ck_n, memory.mem_cke, memory.mem_cs_n, memory.mem_dm, memory.mem_odt, memory.mem_ras_n, memory.mem_reset_n, memory.mem_we_n, net_avm.address, net_avm.burstcount, net_avm.byteenable, net_avm.debugaccess, net_avm.read, net_avm.readdata, net_avm.readdatavalid, net_avm.waitrequest, net_avm.write, net_avm.writedata, oct.rzqin);
endmodule
