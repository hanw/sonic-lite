#
CONNECTAL=`pwd`/../../../connectal/

set -x
set -e
#$CONNECTAL/generated/scripts/importbvi.py -o ALTERA_SI570_WRAPPER.bsv -I Si570Wrap -P Si570Wrap \
#    -c iCLK -r iRST_n \
#    -f iStart -f iFREQ -f oController -f I2C -f oREAD -f oSI570 \
#    ../verilog/si570/si570_controller.v
#
#$CONNECTAL/generated/scripts/importbvi.py -o ALTERA_EDGE_DETECTOR_WRAPPER.bsv -I EdgeDetectorWrap -P EdgeDetectorWrap \
#    -c iCLK -r iRST_n \
#    -f iTrigger -f oFall -f oRis -f oDebounce\
#    ../verilog/si570/edge_detector.v
#
#$CONNECTAL/generated/scripts/importbvi.py -o ALTERA_CLK_CTRL.bsv -I AltClkCtrl -P AltClkCtrl \
#    -c inclk -c outclk\
#    ../verilog/pll/altera_clkctrl/synthesis/altera_clkctrl.v

$CONNECTAL/generated/scripts/importbvi.py -o ALTERA_PLL_156.bsv -I PLL156 -P PLL156 \
    -c refclk -r rst -c outclk_0 \
    ../verilog/pll/pll_156/pll_156.v

$CONNECTAL/generated/scripts/importbvi.py -o ALTERA_PLL_644.bsv -I PLL644 -P PLL644 \
    -c refclk -r rst -c outclk_0 \
    ../verilog/pll/pll_644/pll_644.v

