
CONNECTAL=`pwd`/../../connectal/
set -x
set -e
$CONNECTAL/generated/scripts/importbvi.py -o ALTERA_PCIE_TB_WRAPPER.bsv -I PcieTbWrap -P PcieTbWrap \
    -r pin_perst -r npor -r reset_status \
    -c refclk -c coreclkout_hip \
    -f serdes -f pld -f dl -f ev128 -f ev1 -f hotrst -f l2 -f current \
    -f derr -f lane -f ltssm -f reconfig \
    -f tx_cred -f tx_par -f tx_s -f txd -f txe -f txc -f txm -f txs -f tx\
    -f tx_cred -f rx_par -f rx_s -f rxd -f rxr -f rxe -f rxp -f rxs -f rxv -f rx\
	-f cfg_par \
    -f eidle -f power -f phy \
    -f int_s -f cpl -f tl -f pm_e -f pme -f pm \
    -f simu -f sim \
    -f test_in \
    ../../connectal/out/vsim/synthesis/altera_pcie_testbench.v

    #-f rxdata -f rxpolarity -f rxdatak -f rxelecidle -f rxstatus -f rxvalid \
    #-f txdata -f tx_cred -f tx_out -f txcompl -f txdatak -f txdetectrx -f txelecidle -f txdeemph -f txmargin -f txswing \


