#
CONNECTAL=`pwd`/../../connectal/

set -x
set -e
$CONNECTAL/generated/scripts/importbvi.py -o ALTERA_SI570_WRAPPER.bsv -I Si570Wrap -P Si570Wrap \
    -c iCLK -r iRST_n \
    -f iStart -f iFREQ -f oController -f I2C -f oREAD -f oSI570 \
    ../verilog/si570/si570_controller.v

$CONNECTAL/generated/scripts/importbvi.py -o ALTERA_EDGE_DETECTOR_WRAPPER.bsv -I EdgeDetectorWrap -P EdgeDetectorWrap \
    -c iCLK -r iRST_n \
    -f iTrigger -f oFall -f oRis -f oDebounce\
    ../verilog/si570/edge_detector.v

