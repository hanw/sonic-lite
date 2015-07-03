#default build DTP
DTP=1
SONIC=

QUARTUS_SH=$(shell which quartus_sh)
ROOTDIR=$(realpath .)
CONNECTALDIR?=$(ROOTDIR)/../connectal/
IPDIR?=$(ROOTDIR)/../fpgamake-cache/$(shell basename `/bin/pwd`)/
PROJTOP?=$(ROOTDIR)

CONNECTALFLAGS += --bscflags="-p +:$(PROJTOP)/hw/lib/bsv:$(PROJTOP)/hw/bsv:$(PROJTOP)/hw/generated"
CONNECTALFLAGS += --bscflags="+RTS -K46777216 -RTS -demote-errors G0066:G0045 -suppress-warnings G0046:G0020:S0015:S0080:S0039 -steps-max-intervals 20"

ifneq (, $(DTP))
S2H_INTERFACES=DtpUserRequest:DtpUser.request
H2S_INTERFACES=DtpUser:DtpUserIndication
AUTOTOP= --interface pins:DtpUser.dtp
BSVFILES=hw/bsv/DtpUser.bsv
CPPFILES=sw/test-dtp.cpp
NUMBER_OF_MASTERS =0
PIN_BINDINGS?=PCIE:PCIE LED:LED OSC:OSC SFPA:SFPA SFPB:SFPB SFPC:SFPC SFPD:SFPD SFP:SFP I2C:CLOCK BUTTON:BUTTON SW:SW
PIN_TYPE = DtpIfc
EXPORT_TYPE = PinsTopIfc
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/altera_mac/altera_mac.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/pll_156/altera_pll_156.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/sv_10g_pma/sv_10g_pma.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/altera_clkctrl/altera_clkctrl.qip
CONNECTALFLAGS += --verilog=$(PROJTOP)/hw/verilog/si570/
#CONNECTALFLAGS += --chipscope=$(PROJTOP)/hw/stp/rx_debug.stp
CONNECTALFLAGS += --tcl=$(PROJTOP)/boards/de5_extra.qsf
CONNECTALFLAGS += -D DtpVersion=$(shell date +"%y%m%d%H%M")
CONNECTALFLAGS += --pinfo=boards/dtp_synth.json
endif

ifneq (, $(SONIC))
S2H_INTERFACES=SonicUserRequest:SonicUser.request
H2S_INTERFACES=SonicUser:SonicUserIndication
MEM_INTERFACES=lSonicUser.dmaReadClient,nil
#AUTOTOP= --interface pins:SonicUser.dtp
BSVFILES=hw/bsv/SonicUser.bsv
CPPFILES=sw/test-sonic.cpp
NUMBER_OF_MASTERS=1
PIN_BINDINGS?=PCIE:PCIE LED:LED OSC:OSC SFPA:SFPA SFPB:SFPB SFPC:SFPC SFPD:SFPD SFP:SFP I2C:CLOCK BUTTON:BUTTON
#PIN_TYPE = DtpIfc
EXPORT_TYPE = PinsTopIfc
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/altera_mac/altera_mac.qip # To be removed.
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/pll_156/altera_pll_156.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/sv_10g_pma/sv_10g_pma.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/altera_clkctrl/altera_clkctrl.qip
CONNECTALFLAGS += --verilog=$(PROJTOP)/hw/verilog/si570/
CONNECTALFLAGS += --tcl=$(PROJTOP)/boards/de5_extra.qsf
CONNECTALFLAGS += -D SonicVersion=$(shell date +"%y%m%d%H%M")
CONNECTALFLAGS += --pinfo=boards/sonic_synth.json
endif

ifneq (, $(BLUESWITCH))
CONNECTALFLAGS += --pinfo=boards/blueswitch_synth.json
endif

prebuild::
ifneq (, $(QUARTUS_SH))
ifneq (, $(DTP))
	#(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) $(QUARTUS_SH) -t $(PROJTOP)/hw/scripts/connectal-simu-pcietb.tcl)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) $(QUARTUS_SH) -t $(CONNECTALDIR)/scripts/connectal-synth-pll.tcl)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) $(QUARTUS_SH) -t ../hw/scripts/connectal-synth-mac.tcl)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) $(QUARTUS_SH) -t ../hw/scripts/connectal-synth-eth.tcl)
endif
ifneq (, $(SONIC))
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) $(QUARTUS_SH) -t $(CONNECTALDIR)/scripts/connectal-synth-pll.tcl)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) $(QUARTUS_SH) -t ../hw/scripts/connectal-synth-mac.tcl) # To be removed.
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) $(QUARTUS_SH) -t ../hw/scripts/connectal-synth-eth.tcl)
endif
endif

include $(CONNECTALDIR)/Makefile.connectal
