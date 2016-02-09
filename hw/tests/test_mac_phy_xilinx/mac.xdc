create_clock -name sfp_refclk_p -period 6.400 [get_ports {sfp_refclk_p}]

######################################################################################################
# TIMING CONSTRAINTS
######################################################################################################

set_false_path -from [get_clocks {sfp_refclk_p}] -to [get_clocks {userclk2}]
set_false_path -to [get_clocks {sfp_refclk_p}] -from [get_clocks {userclk2}]

set_false_path -through [get_nets {host_pcieHostTop_ep7/pcie_ep/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/cpllPDInst/*}]
set_false_path -through [get_nets {host_pcieHostTop_ep7/pcie_ep/inst/gt_top_i/pipe_wrapper_i/pipe_lane[1].gt_wrapper_i/cpllPDInst/*}]
set_false_path -through [get_nets {host_pcieHostTop_ep7/pcie_ep/inst/gt_top_i/pipe_wrapper_i/pipe_lane[2].gt_wrapper_i/cpllPDInst/*}]
set_false_path -through [get_nets {host_pcieHostTop_ep7/pcie_ep/inst/gt_top_i/pipe_wrapper_i/pipe_lane[3].gt_wrapper_i/cpllPDInst/*}]
set_false_path -through [get_nets {host_pcieHostTop_ep7/pcie_ep/inst/gt_top_i/pipe_wrapper_i/pipe_lane[4].gt_wrapper_i/cpllPDInst/*}]
set_false_path -through [get_nets {host_pcieHostTop_ep7/pcie_ep/inst/gt_top_i/pipe_wrapper_i/pipe_lane[5].gt_wrapper_i/cpllPDInst/*}]
set_false_path -through [get_nets {host_pcieHostTop_ep7/pcie_ep/inst/gt_top_i/pipe_wrapper_i/pipe_lane[6].gt_wrapper_i/cpllPDInst/*}]
set_false_path -through [get_nets {host_pcieHostTop_ep7/pcie_ep/inst/gt_top_i/pipe_wrapper_i/pipe_lane[7].gt_wrapper_i/cpllPDInst/*}]

