########################################################
# Basic Environment Setup
########################################################
ifeq ($(DEV_ROOT), )
    $(error DEV_ROOT not defined)
endif
CONNECTALDIR?=$(DEV_ROOT)/connectal
SONICDIR?=$(DEV_ROOT)/sonic-lite/
P4FPGADIR?=$(DEV_ROOT)/sonic-lite/p4

########################################################
# Connectal Support
########################################################
S2H_INTERFACES=TestRequest:Test.request
H2S_INTERFACES=Test:TestIndication:host

BSVFILES=Test.bsv
CPPFILES=test.cpp

CONNECTALFLAGS += -I $(SONICDIR)/sw/
CPPFILES += $(SONICDIR)/sw/lpcap.c

#ifeq ($(BOARD), nfsume)
AUTOTOP = --interface pins:Test.pins
PIN_TYPE = NfsumePins
PIN_TYPE_INCLUDE = NfsumePins
PIN_BINDINGS ?= LED:LED SFP:SFP SFPA:SFPA SFPB:SFPB SFPC:SFPC SFPD:SFPD
PINOUT_FILE = $(SONICDIR)/boards/nfsume.json
CONNECTALFLAGS += -D XILINX_SYS_CLK -D IMPORT_HOSTIF
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/ten_gig_eth_mac_0/ten_gig_eth_mac_0.xci
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/ten_gig_eth_pcs_pma_shared/ten_gig_eth_pcs_pma_shared.xci
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/ten_gig_eth_pcs_pma_non_shared/ten_gig_eth_pcs_pma_non_shared.xci
CONNECTALFLAGS += --constraint=mac.xdc --implconstraint=mac.xdc
#CONNECTALFLAGS += -P mkConnectalTop

CONNECTALFLAGS += --bsvpath=$(SONICDIR)/hw/bsv
CONNECTALFLAGS += --bsvpath=$(SONICDIR)/hw/generated
CONNECTALFLAGS += -D NicVersion=$(shell printf "%d" 0x`git rev-parse --short=8 HEAD`)
CONNECTALFLAGS += -D DataBusWidth=128
CONNECTALFLAGS += --bscflags="-show-range-conflict +RTS -K46777216 -RTS -demote-errors G0066:G0045 -suppress-warnings G0046:G0020:S0015:S0080:S0039 -steps-max-intervals 20"
#endif

prebuild::
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) vivado -notrace -mode batch -source $(SONICDIR)/hw/scripts/generate-mac.tcl)
ifneq ($(BOARD), xsim)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) vivado -notrace -mode batch -source $(SONICDIR)/hw/scripts/connectal-synth-phy.tcl)
endif

# Test sequence:
# make build.xsim # to generate 10G mac simulation sourcej
# make sim        # to compile simulation library
# make build.xsim # to link properly
sim:
	vivado -mode batch -source xsim_export.tcl
	cd xsim; ./xsimtop.sh

include $(CONNECTALDIR)/Makefile.connectal
