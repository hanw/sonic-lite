## Generated SDC file "/home/hwang/dev/sonic-lite/p4/examples/memory/mkPcieTop.out.sdc"

## Copyright (C) 1991-2014 Altera Corporation. All rights reserved.
## Your use of Altera Corporation's design tools, logic functions 
## and other software and tools, and its AMPP partner logic 
## functions, and any output files from any of the foregoing 
## (including device programming or simulation files), and any 
## associated documentation or information are expressly subject 
## to the terms and conditions of the Altera Program License 
## Subscription Agreement, the Altera Quartus II License Agreement,
## the Altera MegaCore Function License Agreement, or other 
## applicable license agreement, including, without limitation, 
## that your use is for the sole purpose of programming logic 
## devices manufactured by Altera and sold by Altera or its 
## authorized distributors.  Please refer to the applicable 
## agreement for further details.


## VENDOR  "Altera"
## PROGRAM "Quartus II"
## VERSION "Version 14.0.0 Build 200 06/17/2014 SJ Full Version"

## DATE    "Wed Jan 13 08:56:06 2016"

##
## DEVICE  "5SGXEA7N2F45C2"
##


#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3


#**************************************************************
# Set False Path
#**************************************************************

set_false_path  -from  [get_clocks {host_pcieHostTop_ep7|pcie_ep_pcie|altera_pcie_sv_hip_ast_wrapper_inst|altpcie_hip_256_pipen1b|stratixv_hssi_gen3_pcie_hip|coreclkout}]  -to  [get_clocks {tile_0|lMemoryTest_clocks_pll156|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
set_false_path  -from  [get_clocks {tile_0|lMemoryTest_clocks_pll156|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]  -to  [get_clocks {host_pcieHostTop_ep7|pcie_ep_pcie|altera_pcie_sv_hip_ast_wrapper_inst|altpcie_hip_256_pipen1b|stratixv_hssi_gen3_pcie_hip|coreclkout}]
set_false_path  -from  [get_clocks {host_pcieHostTop_ep7|pcie_ep_pcie|altera_pcie_sv_hip_ast_wrapper_inst|altpcie_hip_256_pipen1b|stratixv_hssi_gen3_pcie_hip|coreclkout}]  -to  [get_clocks {sfp_refclk}]
set_false_path -to [get_registers {*alt_xcvr_resync*sync_r[0]}]
set_false_path -to [get_keepers {*altera_std_synchronizer:*|din_s1}]
set_false_path -from [get_registers {*|in_wr_ptr_gray[*]}] -to [get_registers {*|altera_dcfifo_synchronizer_bundle:write_crosser|altera_std_synchronizer:sync[*].u|din_s1}]
set_false_path -from [get_registers {*|out_rd_ptr_gray[*]}] -to [get_registers {*|altera_dcfifo_synchronizer_bundle:read_crosser|altera_std_synchronizer:sync[*].u|din_s1}]
set_false_path -from [get_pins -compatibility_mode {*stratixv_hssi_gen3_pcie_hip|testinhip[*]}] 
set_false_path -from [get_pins -compatibility_mode {*stratixv_hssi_gen3_pcie_hip|testin1hip[*]}] 
set_false_path -from [get_registers {*sv_xcvr_pipe_native*}] -to [get_registers {*altpcie_rs_serdes|*}]
set_false_path -to [get_registers {*altpcie_rs_serdes|tx_cal_busy_r[0]}]
set_false_path -to [get_registers {*altpcie_rs_serdes|rx_cal_busy_r[0]}]
set_false_path -hold -from [get_keepers {*|alt_xcvr_reconfig_basic:basic|sv_xcvr_reconfig_basic:s5|pif_interface_sel}] 
set_false_path -to [get_pins -nocase -compatibility_mode {*|alt_rst_sync_uq1|altera_reset_synchronizer_int_chain*|clrn}]

#**************************************************************
# Set Multicycle Path
#**************************************************************

