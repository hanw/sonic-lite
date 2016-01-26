DEV_ROOT ?= $(HOME)
CONNECTALDIR ?= $(DEV_ROOT)/connectal
SONICDIR ?= $(DEV_ROOT)/sonic-lite
S2H_INTERFACES = SchedulerTopRequest:SchedulerTop.request
H2S_INTERFACES = SchedulerTop:SchedulerTopIndication
BSVFILES = $(SONICDIR)/scheduler/bsv/hw/SchedulerTop.bsv
CPPFILES = $(SONICDIR)/scheduler/cpp/test_hw.cpp

CONNECTALFLAGS += -D DataBusWidth=128
CONNECTALFLAGS += -D NUMBER_OF_ALTERA_PORTS=3
CONNECTALFLAGS += --bsvpath=$(CONNECTALDIR)/bsv
CONNECTALFLAGS += --bsvpath=$(SONICDIR)/hw/bsv/
CONNECTALFLAGS += --bsvpath=$(SONICDIR)/hw/generated/
CONNECTALFLAGS += -D NicVersion=$(shell printf "%d" 0x`git rev-parse --short=8 HEAD`)
CONNECTALFLAGS += -D PcieHostIF
CONNECTALFLAGS += -D BYTE_ENABLES
FPGAMAKE_CONNECTALFLAGS += -P mkPcieHostTop
CONNECTALFLAGS += -I $(SONICDIR)/sw/

#######################################################
# DE5 Specific Settings
# #######################################################
AUTOTOP = --interface pins:SchedulerTop.pins
PIN_TYPE = DE5Pins
PIN_TYPE_INCLUDE = DE5Pins
PIN_BINDINGS ?= PCIE:PCIE OSC:OSC SFPA:SFPA SFPB:SFPB SFPC:SFPC SFPD:SFPD SFP:SFP LED:LED I2C:I2C
PINOUT_FILE = de5.json

CONNECTALFLAGS += --nocache
CONNECTALFLAGS += --verilog=$(SONICDIR)/hw/verilog/si570/
CONNECTALFLAGS += --verilog=$(SONICDIR)/hw/verilog/
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/mac_10gbe.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/altera_xcvr_10gbaser_wrapper.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/pll_156/altera_pll_156.qip
CONNECTALFLAGS += --tcl=$(SONICDIR)/boards/de5_extra.qsf
CONNECTALFLAGS += --tcl=constraint.sdc
CONNECTALFLAGS += --constraint=constraint.sdc
CONNECTALFLAGS += --implconstraint=constraint.sdc
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/sv_10g_pma/sv_10g_pma.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/altera_clkctrl/altera_clkctrl.qip

#CONNECTALFLAGS += --chipscope=$(SONICDIR)/scheduler/debug.stp

CONNECTALFLAGS += -D HW_DE5

CONNECTALFLAGS += --bscflags="-show-range-conflict +RTS -K46777216 -RTS -demote-errors G0066:G0045 -suppress-warnings G0046:G0020:S0015:S0080:S0039 -steps-max-intervals 20"

ifeq ($(BOARD), vsim)
CONNECTALFLAGS += --verilog $(IPDIR)/$(BOARD)/simulation/mac_10gbe
endif

prebuild::
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t $(SONICDIR)/hw/scripts/generate-mac.tcl)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t $(SONICDIR)/hw/scripts/connectal-synth-phy.tcl)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t $(CONNECTALDIR)/scripts/connectal-synth-pll.tcl)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) $(QUARTUS_SH) -t $(SONICDIR)/hw/scripts/connectal-synth-pma.tcl)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) $(QUARTUS_SH) -t $(SONICDIR)/hw/scripts/connectal-synth-misc.tcl)

include $(SONICDIR)/p4/Makefile.common
include $(CONNECTALDIR)/Makefile.connectal
