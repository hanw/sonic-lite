DEV_ROOT ?= $(HOME)/dev/
CONNECTALDIR ?= $(DEV_ROOT)/connectal
SONICDIR ?= $(DEV_ROOT)/sonic-lite
#IPDIR=$(DEV_ROOT)/fpgamake-cache/$(shell basename `/bin/pwd`)/
S2H_INTERFACES = TestRequest:Test.request
H2S_INTERFACES = Test:TestIndication
BSVFILES = Test.bsv
CPPFILES = test.cpp

CONNECTALFLAGS += -D DataBusWidth=128
CONNECTALFLAGS += --bsvpath=$(CONNECTALDIR)/bsv
CONNECTALFLAGS += --bsvpath=$(SONICDIR)/hw/bsv/
CONNECTALFLAGS += --bsvpath=$(SONICDIR)/hw/generated/

CONNECTALFLAGS += -I $(SONICDIR)/sw/

ifeq ($(BOARD), vsim)
CONNECTALFLAGS += --verilog $(IPDIR)/$(BOARD)/simulation/mac_10gbe
endif

ifeq ($(BOARD), de5)
prebuild::
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t $(SONICDIR)/hw/scripts/generate-mac.tcl)
endif

ifeq ($(BOARD), nfsume)
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/ten_gig_eth_mac_0/ten_gig_eth_mac_0.xci
prebuild::
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) vivado -notrace -mode batch -source $(SONICDIR)/hw/scripts/generate-mac.tcl)
endif

run:
	(cd vsim; ./bin/ubuntu.exe -p ../udp-burst.pcap)

include $(SONICDIR)/p4/Makefile.common
include $(CONNECTALDIR)/Makefile.connectal
