DEV_ROOT ?= $(HOME)/
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
CONNECTALFLAGS += --systemverilog $(IPDIR)/$(BOARD)/simulation/mac_10gbe
endif

prebuild::
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t $(SONIC_DIR)/hw/scripts/generate-mac.tcl)

include $(CONNECTAL_DIR)/Makefile.connectal
