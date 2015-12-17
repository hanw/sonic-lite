#ROOTDIR=$(realpath .)
#CONNECTALDIR?=$(ROOTDIR)/../../connectal/
#PROJTOP?=$(ROOTDIR)

#S2H_INTERFACES = SchedulerTopRequest:SchedulerTop.request
#H2S_INTERFACES = SchedulerTop:SchedulerTopIndication

#BSVFILES = $(PROJTOP)/bsv/SchedulerTop.bsv
#CPPFILES= $(PROJTOP)/cpp/test.cpp

#CONNECTALFLAGS += -D DEBUG
#CONNECTALFLAGS += -D DEBUG_SCHEDULER
#CONNECTALFLAGS += -D FULL_SYSTEM_TEST

#include $(CONNECTALDIR)/Makefile.connectal

DEV_ROOT ?= $(HOME)
CONNECTAL_DIR ?= $(DEV_ROOT)/connectal
SONIC_DIR ?= $(DEV_ROOT)/sonic-lite
IPDIR=$(DEV_ROOT)/fpgamake-cache/$(shell basename `/bin/pwd`)/
S2H_INTERFACES = SchedulerTopRequest:SchedulerTop.request
H2S_INTERFACES = SchedulerTop:SchedulerTopIndication
BSVFILES = $(SONIC_DIR)/scheduler/bsv/SchedulerTop.bsv
CPPFILES = $(SONIC_DIR)/scheduler/cpp/test.cpp

CONNECTALFLAGS += -D DataBusWidth=128
CONNECTALFLAGS += --bsvpath=$(CONNECTAL_DIR)/bsv
CONNECTALFLAGS += --bsvpath=$(SONIC_DIR)/hw/lib/bsv
CONNECTALFLAGS += --bsvpath=$(SONIC_DIR)/hw/bsv/
CONNECTALFLAGS += --bsvpath=$(SONIC_DIR)/hw/generated/

CONNECTALFLAGS += -I $(SONIC_DIR)/sw/

#CONNECTALFLAGS += -D DEBUG
CONNECTALFLAGS += -D DEBUG_SCHEDULER
CONNECTALFLAGS += -D FULL_SYSTEM_TEST

ifeq ($(BOARD), vsim)
CONNECTALFLAGS += --systemverilog $(IPDIR)/$(BOARD)/simulation/mac_10gbe
endif

prebuild::
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t $(SONIC_DIR)/hw/scripts/generate-mac.tcl)

include $(CONNECTAL_DIR)/Makefile.connectal
