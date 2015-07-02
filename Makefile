ROOTDIR=$(realpath .)
CONNECTALDIR?=$(ROOTDIR)/../connectal/
IPDIR?=$(ROOTDIR)/../fpgamake-cache/$(shell basename `/bin/pwd`)/
DTOP?=$(ROOTDIR)

S2H_INTERFACES=SonicUserRequest:SonicUser.request
H2S_INTERFACES=SonicUser:SonicUserIndication
AUTOTOP= --interface pins:SonicUser.dtp
BSVFILES=hw/bsv/SonicUser.bsv
CPPFILES=sw/testlog.cpp
NUMBER_OF_MASTERS =0
PIN_BINDINGS?=PCIE:PCIE LED:LED OSC:OSC SFPA:SFPA SFPB:SFPB SFPC:SFPC SFPD:SFPD SFP:SFP I2C:CLOCK BUTTON:BUTTON SW:SW

QUARTUS_SH=$(shell which quartus_sh)

PIN_TYPE = DtpIfc
EXPORT_TYPE = PinsTopIfc
CONNECTALFLAGS += --bscflags="-p +:$(DTOP)/hw/lib/bsv:$(DTOP)/hw/bsv:$(DTOP)/hw/generated"
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/altera_mac/altera_mac.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/pll_156/altera_pll_156.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/sv_10g_pma/sv_10g_pma.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/altera_clkctrl/altera_clkctrl.qip
CONNECTALFLAGS += --verilog=$(DTOP)/hw/verilog/si570/
#CONNECTALFLAGS += --chipscope=$(DTOP)/hw/stp/rx_debug.stp
CONNECTALFLAGS += --tcl=$(DTOP)/boards/de5_extra.qsf
CONNECTALFLAGS += --bscflags="+RTS -K46777216 -RTS -demote-errors G0066:G0045 -suppress-warnings G0046:G0020:S0015:S0080:S0039 -steps-max-intervals 20"
CONNECTALFLAGS += -D DtpVersion=$(shell date +"%y%m%d%H%M")

.PHONY: vsim
#default build DTP
DTP=1

ifneq (, $(DTP))
ifneq (, $(SIM))
CONNECTALFLAGS += --pinfo=boards/dtp_sim.json
else
CONNECTALFLAGS += --pinfo=boards/dtp_synth.json
endif
endif

prebuild::
ifneq (, $(QUARTUS_SH))
ifneq (, $(DTP))
ifneq (, $(SIM))
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) $(QUARTUS_SH) -t $(DTOP)/hw/scripts/connectal-simu-pcietb.tcl)
endif
	echo $(DTP)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) $(QUARTUS_SH) -t $(CONNECTALDIR)/scripts/connectal-synth-pll.tcl)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) $(QUARTUS_SH) -t ../hw/scripts/connectal-synth-mac.tcl)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) $(QUARTUS_SH) -t ../hw/scripts/connectal-synth-eth.tcl)
endif
endif

vsim: gen.vsim prebuild
	make -C $@ vsim

include $(CONNECTALDIR)/Makefile.connectal
