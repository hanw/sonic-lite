
CONNECTAL=`pwd`/../../connectal/

set -x
set -e
$CONNECTAL/generated/scripts/importbvi.py -o ALTERA_ETH_PORT_WRAPPER.bsv -I EthPortWrap -P EthPortWrap \
    -r rst_in -c clk_in \
    -f xcvr -f xgmii -f export \
    -f ctrl -f counter -f init -f sync -f endec \
    ../verilog/port/sonic_single_port.sv

