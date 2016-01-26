########################################################
# Basic Environment Setup
########################################################
ifeq ($(DEV_ROOT), )
    $(error DEV_ROOT not defined)
endif
CONNECTALDIR?=$(DEV_ROOT)/connectal
SONICDIR?=$(DEV_ROOT)/sonic-lite/
P4FPGADIR?=$(DEV_ROOT)/sonic-lite/p4
SCHEDDIR?=$(DEV_ROOT)/sonic-lite/scheduler

########################################################
# Connectal Support
########################################################
S2H_INTERFACES=MemoryTestRequest:MemoryTest.request

ifeq ($(DEBUG), )
H2S_INTERFACES=MemoryTest:MemoryTestIndication,MemServerIndication
else
H2S_INTERFACES=MemoryTest:MemoryTestIndication,MemServerIndication,MemMgmtIndication,MMUIndication
endif

BSVFILES=MemoryTest.bsv MemoryAPI.bsv $(SONICDIR)/hw/bsv/MemMgmt.bsv GenericMatchTable.bsv TdmPipeline.bsv TopTypes.bsv
CPPFILES=test.cpp

#######################################################
# DE5 Specific Settings
#######################################################
ifeq ($(BOARD), de5)
AUTOTOP = --interface pins:MemoryTest.pins
PIN_TYPE = DE5Pins
PIN_TYPE_INCLUDE = DE5Pins
PIN_BINDINGS ?= PCIE:PCIE OSC:OSC SFPA:SFPA SFPB:SFPB SFPC:SFPC SFPD:SFPD SFP:SFP LED:LED I2C:I2C
PINOUT_FILE = ../../../boards/de5.json
endif

CONNECTALFLAGS += --bsvpath=$(P4FPGADIR)/bsv
CONNECTALFLAGS += --bsvpath=$(P4FPGADIR)/bsv/Bcam
CONNECTALFLAGS += --bsvpath=$(P4FPGADIR)/bsv/AsymmetricBRAM
CONNECTALFLAGS += --verilog=$(SONICDIR)/hw/verilog/si570/
CONNECTALFLAGS += --verilog=$(P4FPGADIR)/bsv/AsymmetricBRAM/
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/mac_10gbe.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/altera_xcvr_10gbaser_wrapper.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/pll_156/altera_pll_156.qip
CONNECTALFLAGS += --tcl=constraint.sdc
CONNECTALFLAGS += --constraint=constraint.sdc
CONNECTALFLAGS += --implconstraint=constraint.sdc
CONNECTALFLAGS += -m $(P4FPGADIR)/bsv/AsymmetricBRAM/mem_model.c
CONNECTALFLAGS += --nocache
CONNECTALFLAGS += --chipscope=$(P4FPGADIR)/examples/tdm/debug.stp

CONNECTALFLAGS += -D BYTE_ENABLES

ifneq ($(DEBUG),)
CONNECTALFLAGS += -D DEBUG=1
endif

BURST_LEN_SIZE=12

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
run-small:
	(cd bluesim; ./bin/ubuntu.exe -p ../udp-small.pcap -a -s -r 9.8 -n $(N))

run-large:
	(cd bluesim; ./bin/ubuntu.exe -p ../udp-large.pcap -r 5.8 -n $(N))

run-mid:
	(cd bluesim; ./bin/ubuntu.exe -p ../udp-mid.pcap -a -s -r 5.8 -n $(N))

run-burst:
	(cd bluesim; ./bin/ubuntu.exe -p ../udp-burst.pcap)

run-sweep:
	(cd bluesim; ./bin/ubuntu.exe -p ../udp-sweep-small.pcap -r 5 -n $(N))

run-match:
	(cd bluesim; ./bin/ubuntu.exe -a 0 -d 0)

include $(SONICDIR)/p4/Makefile.common
include $(CONNECTALDIR)/Makefile.connectal
