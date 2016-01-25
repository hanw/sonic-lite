#**************************************************************
# Set False Path
#**************************************************************

set_false_path  -from  [get_clocks {tile_0|lDtpTop_net|ports|phys|pma4_phy10g|xcvr_low_latency_phy_0|sv_xcvr_low_latency_phy_nr_inst|sv_xcvr_10g_custom_native_inst|sv_xcvr_native_insts[0].gen_bonded_group_native.sv_xcvr_native_inst|inst_sv_pma|rx_pma.sv_rx_pma_inst|rx_pmas[0].rx_pma.rx_pma_deser|clk33pcs}]  -to  [get_clocks {tile_0|lDtpTop_clocks_pll156|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
set_false_path  -from  [get_clocks {tile_0|lDtpTop_net|ports|phys|pma4_phy10g|xcvr_low_latency_phy_1|sv_xcvr_low_latency_phy_nr_inst|sv_xcvr_10g_custom_native_inst|sv_xcvr_native_insts[0].gen_bonded_group_native.sv_xcvr_native_inst|inst_sv_pma|rx_pma.sv_rx_pma_inst|rx_pmas[0].rx_pma.rx_pma_deser|clk33pcs}]  -to  [get_clocks {tile_0|lDtpTop_clocks_pll156|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
set_false_path  -from  [get_clocks {tile_0|lDtpTop_net|ports|phys|pma4_phy10g|xcvr_low_latency_phy_2|sv_xcvr_low_latency_phy_nr_inst|sv_xcvr_10g_custom_native_inst|sv_xcvr_native_insts[0].gen_bonded_group_native.sv_xcvr_native_inst|inst_sv_pma|rx_pma.sv_rx_pma_inst|rx_pmas[0].rx_pma.rx_pma_deser|clk33pcs}]  -to  [get_clocks {tile_0|lDtpTop_clocks_pll156|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
set_false_path  -from  [get_clocks {tile_0|lDtpTop_net|ports|phys|pma4_phy10g|xcvr_low_latency_phy_3|sv_xcvr_low_latency_phy_nr_inst|sv_xcvr_10g_custom_native_inst|sv_xcvr_native_insts[0].gen_bonded_group_native.sv_xcvr_native_inst|inst_sv_pma|rx_pma.sv_rx_pma_inst|rx_pmas[0].rx_pma.rx_pma_deser|clk33pcs}]  -to  [get_clocks {tile_0|lDtpTop_clocks_pll156|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
set_false_path  -from  [get_clocks {osc_50_b4a}]  -to  [get_clocks {tile_0|lDtpTop_clocks_pll156|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
set_false_path  -from  [get_clocks {host_pcieHostTop_ep7|pcie_ep_pcie|altera_pcie_sv_hip_ast_wrapper_inst|altpcie_hip_256_pipen1b|stratixv_hssi_gen3_pcie_hip|coreclkout}]  -to  [get_clocks {tile_0|lDtpTop_clocks_pll156|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
set_false_path  -from  [get_clocks {tile_0|lDtpTop_clocks_pll156|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]  -to  [get_clocks {tile_0|lDtpTop_net|ports|phys|pma4_phy10g|xcvr_low_latency_phy_0|sv_xcvr_low_latency_phy_nr_inst|sv_xcvr_10g_custom_native_inst|sv_xcvr_native_insts[0].gen_bonded_group_native.sv_xcvr_native_inst|inst_sv_pma|rx_pma.sv_rx_pma_inst|rx_pmas[0].rx_pma.rx_pma_deser|clk33pcs}]
set_false_path  -from  [get_clocks {tile_0|lDtpTop_clocks_pll156|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]  -to  [get_clocks {tile_0|lDtpTop_net|ports|phys|pma4_phy10g|xcvr_low_latency_phy_1|sv_xcvr_low_latency_phy_nr_inst|sv_xcvr_10g_custom_native_inst|sv_xcvr_native_insts[0].gen_bonded_group_native.sv_xcvr_native_inst|inst_sv_pma|rx_pma.sv_rx_pma_inst|rx_pmas[0].rx_pma.rx_pma_deser|clk33pcs}]
set_false_path  -from  [get_clocks {tile_0|lDtpTop_clocks_pll156|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]  -to  [get_clocks {tile_0|lDtpTop_net|ports|phys|pma4_phy10g|xcvr_low_latency_phy_2|sv_xcvr_low_latency_phy_nr_inst|sv_xcvr_10g_custom_native_inst|sv_xcvr_native_insts[0].gen_bonded_group_native.sv_xcvr_native_inst|inst_sv_pma|rx_pma.sv_rx_pma_inst|rx_pmas[0].rx_pma.rx_pma_deser|clk33pcs}]
set_false_path  -from  [get_clocks {tile_0|lDtpTop_clocks_pll156|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]  -to  [get_clocks {tile_0|lDtpTop_net|ports|phys|pma4_phy10g|xcvr_low_latency_phy_3|sv_xcvr_low_latency_phy_nr_inst|sv_xcvr_10g_custom_native_inst|sv_xcvr_native_insts[0].gen_bonded_group_native.sv_xcvr_native_inst|inst_sv_pma|rx_pma.sv_rx_pma_inst|rx_pmas[0].rx_pma.rx_pma_deser|clk33pcs}]
set_false_path  -from  [get_clocks {osc_50_b4a}]  -to  [get_clocks {tile_0|lDtpTop_net|ports|phys|pma4_phy10g|xcvr_low_latency_phy_3|sv_xcvr_low_latency_phy_nr_inst|sv_xcvr_10g_custom_native_inst|sv_xcvr_native_insts[0].gen_bonded_group_native.sv_xcvr_native_inst|inst_sv_pma|rx_pma.sv_rx_pma_inst|rx_pmas[0].rx_pma.rx_pma_deser|clk33pcs}]
set_false_path  -from  [get_clocks {osc_50_b4a}]  -to  [get_clocks {tile_0|lDtpTop_net|ports|phys|pma4_phy10g|xcvr_low_latency_phy_2|sv_xcvr_low_latency_phy_nr_inst|sv_xcvr_10g_custom_native_inst|sv_xcvr_native_insts[0].gen_bonded_group_native.sv_xcvr_native_inst|inst_sv_pma|rx_pma.sv_rx_pma_inst|rx_pmas[0].rx_pma.rx_pma_deser|clk33pcs}]
set_false_path  -from  [get_clocks {osc_50_b4a}]  -to  [get_clocks {tile_0|lDtpTop_net|ports|phys|pma4_phy10g|xcvr_low_latency_phy_0|sv_xcvr_low_latency_phy_nr_inst|sv_xcvr_10g_custom_native_inst|sv_xcvr_native_insts[0].gen_bonded_group_native.sv_xcvr_native_inst|inst_sv_pma|rx_pma.sv_rx_pma_inst|rx_pmas[0].rx_pma.rx_pma_deser|clk33pcs}]
set_false_path  -from  [get_clocks {osc_50_b4a}]  -to  [get_clocks {tile_0|lDtpTop_net|ports|phys|pma4_phy10g|xcvr_low_latency_phy_1|sv_xcvr_low_latency_phy_nr_inst|sv_xcvr_10g_custom_native_inst|sv_xcvr_native_insts[0].gen_bonded_group_native.sv_xcvr_native_inst|inst_sv_pma|rx_pma.sv_rx_pma_inst|rx_pmas[0].rx_pma.rx_pma_deser|clk33pcs}]
set_false_path  -from  [get_clocks {tile_0|lDtpTop_clocks_pll156|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]  -to  [get_clocks {host_pcieHostTop_ep7|pcie_ep_pcie|altera_pcie_sv_hip_ast_wrapper_inst|altpcie_hip_256_pipen1b|stratixv_hssi_gen3_pcie_hip|coreclkout}]
set_false_path  -from  [get_clocks {tile_0|lDtpTop_clocks_pll156|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]  -to  [get_clocks {osc_50_b4a}]
set_false_path -to [get_registers {*alt_xcvr_csr_common*csr_pll_locked*[2]*}]
set_false_path -to [get_registers {*alt_xcvr_csr_common*csr_rx_is_locked*[2]*}]
set_false_path -to [get_registers {*alt_xcvr_resync*sync_r[0]}]
set_false_path -from [get_registers {*altera_avalon_st_clock_crosser:*|in_data_buffer*}] -to [get_registers {*altera_avalon_st_clock_crosser:*|out_data_buffer*}]
set_false_path -to [get_keepers {*altera_std_synchronizer:*|din_s1}]
set_false_path -from [get_registers {*|in_wr_ptr_gray[*]}] -to [get_registers {*|altera_dcfifo_synchronizer_bundle:write_crosser|altera_std_synchronizer:sync[*].u|din_s1}]
set_false_path -from [get_registers {*|out_rd_ptr_gray[*]}] -to [get_registers {*|altera_dcfifo_synchronizer_bundle:read_crosser|altera_std_synchronizer:sync[*].u|din_s1}]
set_false_path -from [get_registers {*altera_jtag_src_crosser:*|sink_data_buffer*}] -to [get_registers {*altera_jtag_src_crosser:*|src_data*}]
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

