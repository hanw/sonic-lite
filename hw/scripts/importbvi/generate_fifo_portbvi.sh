#
CONNECTAL=`pwd`/../../../connectal/

set -x
set -e
$CONNECTAL/generated/scripts/importbvi.py -o ../generated/DTP_DCFIFO_WRAPPER.bsv -I DtpDCFifoWrap -P DtpDCFifoWrap \
    -c rdclk -c wrclk -r aclr \
    ../verilog/asyncfifo/fifo.v

