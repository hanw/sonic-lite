source "board.tcl"
source "$connectaldir/scripts/connectal-synth-ip.tcl"

proc create_altera_10gber_phy {channels} {
	set core_name {altera_xcvr_10gbaser}
	set core_version {14.0}
	set ip_name {altera_xcvr_10gbaser_wrapper}

	dict set params device_family "Stratix V"
	dict set params num_channels $channels
	dict set params operation_mode "duplex"
	dict set params external_pma_ctrl_config 0
	dict set params control_pin_out 0
	dict set params recovered_clk_out 0
	dict set params pll_locked_out 0
	dict set params gui_pll_type CMU
	dict set params ref_clk_freq "644.53125 MHz"
	dict set params pma_mode 40
	dict set params starting_channel_number 0
	dict set params sys_clk_in_hz 150000000
	dict set params rx_use_coreclk 0
	dict set params gui_embedded_reset 1
	dict set params latadj 0
	dict set params high_precision_latadj 1
	dict set params tx_termination "OCT_100_OHMS"
	dict set params tx_vod_selection 7
	dict set params tx_preemp_pretap 0
	dict set params tx_preemp_pretap_inv 0
	dict set params tx_preemp_tap_1 15
	dict set params tx_preemp_tap_2 0
	dict set params tx_preemp_tap_2_inv 0
	dict set params rx_common_mode "0.82v"
	dict set params rx_termination "OCT_100_OHMS"
	dict set params rx_eq_dc_gain 0
	dict set params rx_eq_ctrl 0
	dict set params mgmt_clk_in_hz 150000000

	set component_parameters {}
	foreach item [dict keys $params] {
		set val [dict get $params $item]
		lappend component_parameters --component-parameter=$item=$val
	}
	connectal_altera_synth_ip $core_name $core_version $ip_name $component_parameters
}

if {[info exists NUMBER_OF_10G_PORTS]} {
   if {[info exists USE_ALTERA_10GBASER]} {
       create_altera_10gber_phy $NUMBER_OF_10G_PORTS
   }
}
