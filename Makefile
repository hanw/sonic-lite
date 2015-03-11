
CONNECTALDIR?=../connectal
DTOP?=../sonic-lite
S2H_INTERFACES=SimpleRequest:Simple.request
H2S_INTERFACES=SimpleRequest:Simple
#INTERFACES=Simple
BSVFILES=hw/bsv/LedTop.bsv hw/Simple.bsv hw/lib/bsv/Scrambler.bsv hw/bsv/libs/AvalonStreaming.bsv
CPPFILES=sw/testsimple.cpp
NUMBER_OF_MASTERS =0
PIN_BINDINGS?=-b PCIE:PCIE -b LED:LED -b OSC:OSC -b SFPA:SFPA -b SFPB:SFPB -b SFPC:SFPC -b SFPD:SFPD -b SFP:SFP -b DDR3A:DDR3A -b RZQ:RZQ

PIN_TYPE = NetTopIfc
#CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/altera_mac.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/altera_xcvr_reset_control_wrapper.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/altera_xcvr_native_sv_wrapper.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/altera_xgbe_pma_reconfig_wrapper.qip
CONNECTALFLAGS += --xci=$(DTOP)/verilog/pll/altera_clkctrl/synthesis/altera_clkctrl.qip
CONNECTALFLAGS += --chipscope=$(DTOP)/hw/portal.stp

# Supported Platforms:
# {vendor}_{platform}=1
ALTERA_SIM_vsim=1
ALTERA_SYNTH_de5=1

.PHONY: vsim

ifeq ($(ALTERA_SIM_$(BOARD)), 1)
CONNECTALFLAGS += --pinfo=boards/sim.json
CONNECTALFLAGS += --bscflags="+RTS -K46777216 -RTS -demote-errors G0066:G0045 -suppress-warnings G0046:G0020:S0015:S0080:S0039"
endif
ifeq ($(ALTERA_SYNTH_$(BOARD)), 1)
CONNECTALFLAGS += --pinfo=boards/synth.json
endif

#PORTAL_DUMP_MAP="Simple"

prebuild::
ifeq ($(ALTERA_SIM_$(BOARD)), 1)
#	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t ../scripts/connectal-synth-pll.tcl)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t $(DTOP)/hw/scripts/connectal-simu-pcietb.tcl)
endif
ifeq ($(ALTERA_SYNTH_$(BOARD)), 1)
	#(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t $(CONNECTALDIR)/scripts/connectal-synth-pll.tcl)
	#(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t ../scripts/connectal-synth-mac.tcl)
endif

#BSV_VERILOG_FILES+=$(PCIE_TBED_VERILOG_FILES)

vsim: gen.vsim prebuild
	make -C $@ vsim

boards-de5:
	make -C boards/de5 program

include $(CONNECTALDIR)/Makefile.connectal
