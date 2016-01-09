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
S2H_INTERFACES=MemoryTestRequest:MemoryTest.request
H2S_INTERFACES=MemoryTest:MemoryTestIndication
BSVFILES=MemoryTest.bsv MemoryAPI.bsv
CPPFILES=test.cpp

#######################################################
# DE5 Specific Settings
#######################################################
#AUTOTOP = --interface pins:MemoryTest.pins
#PIN_TYPE = DE5Pins
#PIN_TYPE_INCLUDE = DE5Pins
#PIN_BINDINGS ?= PCIE:PCIE OSC:OSC SFPA:SFPA SFPB:SFPB SFPC:SFPC SFPD:SFPD SFP:SFP LED:LED I2C:CLOCK
#PINOUT_FILE = de5.json

CONNECTALFLAGS += --verilog=$(SONICDIR)/hw/verilog/si570/
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/mac_10gbe.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/altera_xcvr_10gbaser_wrapper.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/pll_156/altera_pll_156.qip
CONNECTALFLAGS += --tcl=$(SONICDIR)/boards/de5_extra.qsf

#######################################################
# IP Generation Scripts
#######################################################
#prebuild::
#	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t $(SONICDIR)/hw/scripts/generate-mac.tcl)
#	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t $(SONICDIR)/hw/scripts/connectal-synth-phy.tcl)
#	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t $(CONNECTALDIR)/scripts/connectal-synth-pll.tcl)

#######################################################
# Default Rules
#######################################################
include $(SONICDIR)/p4/Makefile.common
include $(CONNECTALDIR)/Makefile.connectal
