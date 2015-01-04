#
CONNECTAL=`pwd`/../../connectal/

set -x
set -e
$CONNECTAL/generated/scripts/importbvi.py -o ALTERA_SI570_WRAPPER.bsv -I MacWrap -P MacWrap \
    -c iCLK -r iRST_n \
    -f iStart -f iFREQ -f oController -f I2C -f oREAD -f oSI570 \
    ../verilog/si570/si570_controller.v

