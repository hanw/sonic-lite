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
S2H_INTERFACES=NullTestRequest:NullTest.request
H2S_INTERFACES=NullTest:NullTestIndication
BSVFILES=NullTest.bsv NullAPI.bsv
CPPFILES=test.cpp
CPPFILES += $(SONICDIR)/sw/lpcap.c

#######################################################
# DE5 Specific Settings
#######################################################
AUTOTOP = --interface pins:NullTest.pins
PIN_TYPE = DE5Pins
PIN_TYPE_INCLUDE = DE5Pins
PIN_BINDINGS ?= PCIE:PCIE OSC:OSC SFPA:SFPA SFPB:SFPB SFPC:SFPC SFPD:SFPD SFP:SFP LED:LED I2C:I2C
PINOUT_FILE = $(SONICDIR)/boards/de5.json

CONNECTALFLAGS += --verilog=$(SONICDIR)/hw/verilog/si570/
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/mac_10gbe.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/altera_xcvr_10gbaser_wrapper.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/pll_156/altera_pll_156.qip
#CONNECTALFLAGS += --chipscope=$(SONICDIR)/p4/examples/null/mac.stp
#CONNECTALFLAGS += -m $(P4FPGADIR)/bsv/AsymmetricBRAM/mem_model.c

#######################################################
# IP Generation Scripts
#######################################################
ifeq ($(BOARD), de5)
prebuild::
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t $(SONICDIR)/hw/scripts/generate-mac.tcl)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t $(SONICDIR)/hw/scripts/connectal-synth-phy.tcl)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t $(CONNECTALDIR)/scripts/connectal-synth-pll.tcl)
endif

#######################################################
# Default Rules
#######################################################
include $(SONICDIR)/p4/Makefile.common
include $(CONNECTALDIR)/Makefile.connectal
