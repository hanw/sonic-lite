source "board.tcl"
source "$connectaldir/scripts/connectal-synth-ip.tcl"

if {[info exists USE_ALTERA_MAC]} {
   fpgamake_altera_ipcore_qsys ../../hw/qsys/mac.qsys 14.0 altera_mac
}
