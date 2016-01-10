source "board.tcl"
source "$connectaldir/scripts/connectal-synth-ip.tcl"

#if {[info exists USE_ALTERA_SV_10G_PMA]} {
   fpgamake_altera_ipcore_qsys /home/kslee/sonic/sonic-lite/hw/qsys/sv_10g_pma.qsys 14.0 sv_10g_pma
#}
