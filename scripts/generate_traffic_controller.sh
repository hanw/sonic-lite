
CONNECTAL=`pwd`/../../connectal/

set -x
set -e
$CONNECTAL/generated/scripts/importbvi.py -o ALTERA_TRAFFIC_CONTROLLER_WRAPPER.bsv -I TrafficCtrlWrap -P TrafficCtrlWrap \
    -r reset_n -c clk_in \
    -f avl_mm -f avl_st_tx -f avl_st_rx \
    -f mac_rx -f stop -f mon \
    ../verilog/traffic_controller/avalon_st_traffic_controller.v

