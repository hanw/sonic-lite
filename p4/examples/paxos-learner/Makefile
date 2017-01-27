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
H2S_INTERFACES=MemoryTest:MemoryTestIndication,MemServerIndication:host
CPPFILES=test.cpp
CPPFILES += $(SONICDIR)/sw/lpcap.c
BSVFILES=MemoryTest.bsv MemoryAPI.bsv ConnectalTypes.bsv ../../../hw/bsv/DbgDefs.bsv #../../../hw/bsv/DbgTypes.bsv 
FPGAMAKE_CONNECTALFLAGS += -P mkPcieHostTop

CONNECTALFLAGS += -I $(SONICDIR)/sw/
CONNECTALFLAGS += -lpcap -lpthread
CONNECTALFLAGS += --bsvpath=$(P4FPGADIR)/bsv/
CONNECTALFLAGS += --bsvpath=$(P4FPGADIR)/bsv/AsymmetricBRAM
CONNECTALFLAGS += --bsvpath=$(P4FPGADIR)/bsv/Bcam
CONNECTALFLAGS += --bsvpath=$(P4FPGADIR)/examples/paxos-learner
CONNECTALFLAGS += --bsvpath=$(SONICDIR)/hw/bsv
CONNECTALFLAGS += --bsvpath=$(SONICDIR)/hw/generated
CONNECTALFLAGS += --verilog=$(P4FPGADIR)/bsv/AsymmetricBRAM
CONNECTALFLAGS += -D NicVersion=$(shell printf "%d" 0x`git rev-parse --short=8 HEAD`)
CONNECTALFLAGS += -D DataBusWidth=128
CONNECTALFLAGS += -D IMPORT_HOSTIF
CONNECTALFLAGS += -D BYTE_ENABLES
CONNECTALFLAGS += -D FOO
CONNECTALFLAGS += -D ClockDefaultParam
CONNECTALFLAGS += -D CONNECTAL_TYPE
CONNECTALFLAGS += --bscflags="-show-range-conflict +RTS -K46777216 -RTS -demote-errors G0066:G0045 -suppress-warnings G0046:G0020:G0023:S0015:S0080:S0039 -steps-max-intervals 20"
CONNECTALFLAGS += -m $(P4FPGADIR)/bsv/AsymmetricBRAM/mem_model.c
CONNECTALFLAGS += -m $(P4FPGADIR)/bsv/matchtable_model.cpp
CONNECTALFLAGS += --nocache
CONNECTALFLAGS += --cxxflags=-std=c++11

CONNECTALFLAGS += -D PARSER=Paxos
#CONNECTALFLAGS += -D PARSER=Parser
CONNECTALFLAGS += -D DEPARSER=Deparser
CONNECTALFLAGS += -D TYPEDEF=PaxosTypes
CONNECTALFLAGS += -D MATCHTABLE=MatchTableSim

BURST_LEN_SIZE=12

#######################################################
# DE5 Specific Settings
#######################################################
ifeq ($(BOARD), de5)
AUTOTOP = --interface pins:MemoryTest.pins
PIN_TYPE = DE5Pins
PIN_TYPE_INCLUDE = DE5Pins
PIN_BINDINGS ?= PCIE:PCIE OSC:OSC SFPA:SFPA SFPB:SFPB SFPC:SFPC SFPD:SFPD SFP:SFP LED:LED I2C:I2C
PINOUT_FILE = $(SONICDIR)/boards/de5.json

CONNECTALFLAGS += --bsvpath=$(P4FPGADIR)/bsv
CONNECTALFLAGS += --verilog=$(SONICDIR)/hw/verilog/si570/
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/mac_10gbe.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/altera_xcvr_10gbaser_wrapper.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/pll_156/altera_pll_156.qip
#CONNECTALFLAGS += --tcl=constraint.sdc
#CONNECTALFLAGS += --constraint=constraint.sdc
#CONNECTALFLAGS += --implconstraint=constraint.sdc
endif

#######################################################
# IP Generation Scripts
#######################################################
ifeq ($(BOARD), de5)
prebuild::
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t $(SONICDIR)/hw/scripts/generate-mac.tcl)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t $(SONICDIR)/hw/scripts/connectal-synth-phy.tcl)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t $(CONNECTALDIR)/scripts/connectal-synth-pll.tcl)
endif

########################################################
# NFSUME SUPPORT
########################################################
ifeq ($(BOARD), nfsume)
AUTOTOP = --interface pins:MemoryTest.pins
PIN_TYPE = NfsumePins
PIN_TYPE_INCLUDE = NfsumePins
PIN_BINDINGS ?= LED:LED SFP:SFP SFPA:SFPA SFPB:SFPB SFPC:SFPC SFPD:SFPD
PINOUT_FILE = $(SONICDIR)/boards/nfsume.json
CONNECTALFLAGS += -D XILINX_SYS_CLK
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/ten_gig_eth_mac_0/ten_gig_eth_mac_0.xci
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/ten_gig_eth_pcs_pma_shared/ten_gig_eth_pcs_pma_shared.xci
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/ten_gig_eth_pcs_pma_non_shared/ten_gig_eth_pcs_pma_non_shared.xci
CONNECTALFLAGS += --constraint=timing_constraints.xdc --implconstraint=timing_constraints.xdc
prebuild::
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) vivado -notrace -mode batch -source $(SONICDIR)/hw/scripts/generate-mac.tcl)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) vivado -notrace -mode batch -source $(SONICDIR)/hw/scripts/connectal-synth-phy.tcl)
endif

#######################################################
# Default Rules
#######################################################
run:
	(cd bluesim; ./bin/ubuntu.exe -p ../paxos.pcap)

run-coo:
	(cd bluesim; ./bin/ubuntu.exe -p ../paxosv02.pcap -C)

run-acc:
	(cd bluesim; ./bin/ubuntu.exe -p ../paxosv02.pcap -A)

run-pktgen:
	(cd bluesim; ./bin/ubuntu.exe -p ../learner.pcap -r 2 -n 100)

run-small:
	(cd bluesim; ./bin/ubuntu.exe -p ../tests/udp-small.pcap)

run-paxos:
	(cd bluesim; ./bin/ubuntu.exe -p ../tests/multipaxos.pcap)

run-libpaxos:
	(cd bluesim; ./bin/ubuntu.exe -p ../libpaxos.pcap)

run-lea:
	(cd bluesim; ./bin/ubuntu.exe -p ../learner.pcap)

FIRMWARE_VERSION=$(shell printf "%x" 0x`git rev-parse --short=8 HEAD`)
SYSTEM_TIME=$(shell date +'%Y.%m.%d-%H:%M:%S')
release:
	GITHUB_TOKEN=$(GITHUB_TOKEN) github-release release --user hanw --repo p4paxos-firmware --tag $(FIRMWARE_VERSION) --name $(SYSTEM_TIME) --description $(FIRMWARE_VERSION) ;
	GITHUB_TOKEN=$(GITHUB_TOKEN) github-release upload --user hanw --repo p4paxos-firmware --tag $(FIRMWARE_VERSION) --name "ubuntu.exe" --file ./nfsume/bin/ubuntu.exe;
	GITHUB_TOKEN=$(GITHUB_TOKEN) github-release upload --user hanw --repo p4paxos-firmware --tag $(FIRMWARE_VERSION) --name "mkTop.bit" --file ./nfsume/Impl/TopDown/mkTop.bit;

include $(CONNECTALDIR)/Makefile.connectal
