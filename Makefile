
CONNECTALDIR?=../connectal
DTOP?=../sonic-lite
S2H_INTERFACES=SonicUserRequest:SonicUser.request
H2S_INTERFACES=SonicUser:SonicUserRequest
#AUTOTOP=--importfiles NetTop
AUTOTOP=--importfiles PinsTop
#AUTOTOP=--importfiles EthSonicPma
#INTERFACES=SonicUser
BSVFILES=hw/bsv/LedTop.bsv hw/SonicUser.bsv hw/lib/bsv/Scrambler.bsv hw/bsv/libs/AvalonStreaming.bsv hw/generated/ALTERA_SI570_WRAPPER.bsv
CPPFILES=sw/testdelay.cpp
NUMBER_OF_MASTERS =0
#PIN_BINDINGS?=-b PCIE:PCIE -b LED:LED -b OSC:OSC -b SFPA:SFPA -b SFPB:SFPB -b SFPC:SFPC -b SFPD:SFPD -b SFP:SFP -b DDR3A:DDR3A -b RZQ:RZQ
PIN_BINDINGS?=-b PCIE:PCIE -b LED:LED -b OSC:OSC -b SFPA:SFPA -b SFPB:SFPB -b SFPC:SFPC -b SFPD:SFPD -b SFP:SFP -b I2C:CLOCK -b BUTTON:BUTTON -b SW:SW

#PIN_TYPE = NetTopIfc
PIN_TYPE = PinsTopIfc
#PIN_TYPE = Eth10GPhyTopIfc
#PIN_TYPE = EthSonicPmaTopIfc
#CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/altera_mac/altera_mac.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/altera_xcvr_reset_control_wrapper/altera_xcvr_reset_control_wrapper.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/altera_xcvr_native_sv_wrapper/altera_xcvr_native_sv_wrapper.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/altera_xgbe_pma_reconfig_wrapper/altera_xgbe_pma_reconfig_wrapper.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/pll_156/altera_pll_156.qip
#CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/pll_644/altera_pll_644.qip
#CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/sv_10g_phy/sv_10g_phy.qip
CONNECTALFLAGS += --xci=$(DTOP)/hw/verilog/pll/altera_clkctrl/synthesis/altera_clkctrl.qip
CONNECTALFLAGS += --verilog=$(DTOP)/hw/verilog/si570/
CONNECTALFLAGS += --verilog=$(CONNECTALDIR)/verilog/altera/
CONNECTALFLAGS += --chipscope=$(DTOP)/hw/net.stp

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
CONNECTALFLAGS += --bscflags="+RTS -K46777216 -RTS -demote-errors G0066:G0045 -suppress-warnings G0046:G0020:S0015:S0080:S0039 -steps-max-intervals 20"
endif

#PORTAL_DUMP_MAP="SonicUser"

prebuild::
ifeq ($(ALTERA_SIM_$(BOARD)), 1)
#	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t ../scripts/connectal-synth-pll.tcl)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t $(DTOP)/hw/scripts/connectal-simu-pcietb.tcl)
endif
ifeq ($(ALTERA_SYNTH_$(BOARD)), 1)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t $(CONNECTALDIR)/scripts/connectal-synth-pll.tcl)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t ../hw/scripts/connectal-synth-mac.tcl)
endif

#BSV_VERILOG_FILES+=$(PCIE_TBED_VERILOG_FILES)

vsim: gen.vsim prebuild
	make -C $@ vsim

boards-de5:
	make -C boards/de5 program

include $(CONNECTALDIR)/Makefile.connectal
