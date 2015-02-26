source "board.tcl"

proc fpgamake_altera_sim_ipcore {core_name core_version ip_name params} {
    global ipdir boardname partname

    exec -ignorestderr -- ip-generate \
            --project-directory=$ipdir/$boardname                            \
            --output-directory=$ipdir/$boardname/synthesis                   \
            --file-set=SIM_VERILOG                                           \
            --report-file=html:$ipdir/$boardname/$ip_name.html               \
            --report-file=sopcinfo:$ipdir/$boardname/$ip_name.sopcinfo       \
            --report-file=cmp:$ipdir/$boardname/$ip_name.cmp                 \
            --report-file=qip:$ipdir/$boardname/synthesis/$ip_name.qip       \
            --report-file=svd:$ipdir/$boardname/synthesis/$ip_name.svd       \
            --report-file=regmap:$ipdir/$boardname/synthesis/$ip_name.regmap \
            --report-file=xml:$ipdir/$boardname/$ip_name.xml                 \
            --system-info=DEVICE_FAMILY=StratixV                             \
            --system-info=DEVICE=$partname                                   \
            --system-info=DEVICE_SPEEDGRADE=2_H2                             \
            {*}$params                                                       \
            --component-name=$core_name                                      \
            --output-name=$ip_name
}

proc create_altera_pcietb {core_name core_version ip_name} {
 	set params [ dict create ]
	#dict set params enable_pll                    0

	set component_parameters {}
	foreach item [dict keys $params] {
		set val [dict get $params $item]
		lappend component_parameters --component-parameter=$item=$val
	}
    fpgamake_altera_sim_ipcore $core_name $core_version $ip_name $component_parameters
}

create_altera_pcietb altera_pcie_tbed 14.0 altera_pcie_testbench
