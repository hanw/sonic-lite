#
CONNECTAL=`pwd`/../../connectal/

set -x
set -e
$CONNECTAL/generated/scripts/importbvi.py -o DTP_GLOBAL_TIMESTAMP_WRAPPER.bsv -I DtpGlobalWrap -P DtpGlobalWrap \
    -c clock -r reset \
    -f timestamp \
    ../verilog/timestamp/global_timestamp.sv

