DEV_ROOT ?= $(HOME)/dev/
CONNECTAL_DIR ?= $(DEV_ROOT)/connectal
SONIC_DIR ?= $(DEV_ROOT)/sonic-lite
IPDIR=$(DEV_ROOT)/fpgamake-cache/$(shell basename `/bin/pwd`)/
S2H_INTERFACES = TestRequest:Test.request
H2S_INTERFACES = Test:TestIndication
BSVFILES = Test.bsv
CPPFILES = test.cpp

CONNECTALFLAGS += -D DataBusWidth=128
CONNECTALFLAGS += --bsvpath=$(CONNECTAL_DIR)/bsv
CONNECTALFLAGS += --bsvpath=$(SONIC_DIR)/hw/lib/bsv
CONNECTALFLAGS += --bsvpath=$(SONIC_DIR)/hw/bsv/
CONNECTALFLAGS += --bsvpath=$(SONIC_DIR)/hw/generated/

CONNECTALFLAGS += -I $(SONIC_DIR)/sw/

ifeq ($(BOARD), vsim)
CONNECTALFLAGS += --verilog $(IPDIR)/$(BOARD)/simulation/mac_10gbe
CONNECTALFLAGS += --verilog $(IPDIR)/$(BOARD)/simulation/altera_xcvr_10gbaser_wrapper
CONNECTALFLAGS += --modelsim $(IPDIR)/$(BOARD)/simulation/altera_xcvr_10gbaser_wrapper/submodules/alt_xcvr_csr_common_h.sv
CONNECTALFLAGS += --modelsim $(IPDIR)/$(BOARD)/simulation/altera_xcvr_10gbaser_wrapper/submodules/altera_xcvr_functions.sv
CONNECTALFLAGS += --modelsim $(IPDIR)/$(BOARD)/simulation/altera_xcvr_10gbaser_wrapper/submodules/alt_xcvr_csr_selector.sv
endif

ifeq ($(BOARD), de5)
AUTOTOP = --interface pins:Test.pins
PIN_TYPE = DE5Pins
PIN_TYPE_INCLUDE = DE5Pins
PIN_BINDINGS ?= PCIE:PCIE OSC:OSC SFPA:SFPA SFPB:SFPB SFPC:SFPC SFPD:SFPD SFP:SFP LED:LED I2C:CLOCK
PINOUT_FILE = de5.json
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/mac_10gbe.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/altera_xcvr_10gbaser_wrapper.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/pll_156/altera_pll_156.qip
CONNECTALFLAGS += -D DEBUG_ETH

CONNECTALFLAGS += --verilog=$(SONIC_DIR)/hw/verilog/si570/
endif

prebuild::
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t $(SONIC_DIR)/hw/scripts/generate-mac.tcl)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t $(SONIC_DIR)/hw/scripts/connectal-synth-phy.tcl)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) $(QUARTUS_SH) -t $(CONNECTALDIR)/scripts/connectal-synth-pll.tcl)

include $(CONNECTAL_DIR)/Makefile.connectal
