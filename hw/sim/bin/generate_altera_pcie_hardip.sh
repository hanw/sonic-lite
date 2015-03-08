#
#
set -x
set -e
./importbvi.py -o PCIEWRAPPER.bsv -I PcieWrap -P PcieWrap \
    -r pcie_rstn_pin_perst -r pcie_rstn_npor -r reset_reset_n \
    -c clk_clk -c refclk_clk \
	-f hip_pipe -f hip_serial -f hip_ctrl \
    ../altera_pcie_sv/synthesis/altera_pcie_sv.v

    #-f rxdata -f rxpolarity -f rx_in -f rxdatak -f rxelecidle -f rxstatus -f rxvalid \
    #-f txdata -f tx_cred -f tx_out -f txcompl -f txdatak -f txdetectrx -f txelecidle -f txdeemph -f txmargin -f txswing \
