QUARTUS_SH=$(shell which quartus_sh)
ROOTDIR=$(realpath .)
CONNECTALDIR?=$(ROOTDIR)/../../connectal/
IPDIR?=$(ROOTDIR)/../../fpgamake-cache/$(shell basename `/bin/pwd`)/
PROJTOP?=$(ROOTDIR)

CONNECTALFLAGS += --bscflags="-p +:$(PROJTOP)/../hw/lib/bsv:$(PROJTOP)/../hw/bsv:$(PROJTOP)/../hw/generated"
CONNECTALFLAGS += --bscflags="+RTS -K46777216 -RTS -demote-errors G0066:G0045 -suppress-warnings G0046:G0020:S0015:S0080:S0039 -steps-max-intervals 20"

S2H_INTERFACES=SonicUserRequest:SonicUser.request
H2S_INTERFACES=SonicUser:SonicUserIndication
MEM_INTERFACES=lSonicUser.dmaReadClient,nil
#AUTOTOP= --interface pins:SonicUser.sonicifc
BSVFILES=$(PROJTOP)/../hw/bsv/SonicUser.bsv
CPPFILES=$(PROJTOP)/../sw/test-sonic.cpp
NUMBER_OF_MASTERS=1
PIN_BINDINGS?=PCIE:PCIE LED:LED OSC:OSC SFPA:SFPA SFPB:SFPB SFPC:SFPC SFPD:SFPD SFP:SFP I2C:CLOCK BUTTON:BUTTON
#PIN_TYPE = SonicIfc
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/altera_mac/altera_mac.qip # To be removed.
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/pll_156/altera_pll_156.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/sv_10g_pma/sv_10g_pma.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/altera_clkctrl/altera_clkctrl.qip
CONNECTALFLAGS += --verilog=$(PROJTOP)/../hw/verilog/si570/
CONNECTALFLAGS += --tcl=$(PROJTOP)/../boards/de5_extra.qsf
CONNECTALFLAGS += -D SonicVersion=$(shell date +"%y%m%d%H%M")
CONNECTALFLAGS += -D PcieHostIF
CONNECTALFLAGS += -D DataBusWidth=128
CONNECTALFLAGS += --chipscope=$(PROJTOP)/../../sonic-debug/stp/memread.stp
CONNECTALFLAGS += --pinfo=$(PROJTOP)/../boards/sonic_synth.json

prebuild::
ifneq (, $(QUARTUS_SH))
ifneq (, $(BLUESIM))
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) $(QUARTUS_SH) -t $(CONNECTALDIR)/scripts/connectal-synth-pll.tcl)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) $(QUARTUS_SH) -t $(PROJTOP)/../hw/scripts/connectal-synth-mac.tcl) # To be removed.
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) $(QUARTUS_SH) -t $(PROJTOP)/../hw/scripts/connectal-synth-eth.tcl)
endif
endif

include $(CONNECTALDIR)/Makefile.connectal
