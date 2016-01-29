DEV_ROOT ?= $(HOME)
CONNECTALDIR ?= $(DEV_ROOT)/connectal
SONICDIR ?= $(DEV_ROOT)/sonic-lite
S2H_INTERFACES = SchedulerTopRequest:SchedulerTop.request2
H2S_INTERFACES = SchedulerTop:SchedulerTopIndication
BSVFILES = $(SONICDIR)/scheduler/bsv/hw/SchedulerTop.bsv
CPPFILES = $(SONICDIR)/scheduler/cpp/test_hw.cpp

CONNECTALFLAGS += -D DataBusWidth=128
CONNECTALFLAGS += --bsvpath=$(CONNECTALDIR)/bsv
CONNECTALFLAGS += --bsvpath=$(SONICDIR)/hw/bsv/
CONNECTALFLAGS += --bsvpath=$(SONICDIR)/hw/generated/
CONNECTALFLAGS += -I $(SONICDIR)/sw/

CONNECTALFLAGS += -D SIM

CONNECTALFLAGS += --bscflags="-show-range-conflict +RTS -K46777216 -RTS -demote-errors G0066:G0045 -suppress-warnings G0046:G0020:S0015:S0080:S0039 -steps-max-intervals 20"

ifeq ($(BOARD), vsim)
CONNECTALFLAGS += --verilog $(IPDIR)/$(BOARD)/simulation/mac_10gbe
endif

prebuild::
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t $(SONICDIR)/hw/scripts/generate-mac.tcl)

include $(CONNECTALDIR)/Makefile.connectal
