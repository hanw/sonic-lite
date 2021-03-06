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
S2H_INTERFACES=FwdTestRequest:FwdTest.request
H2S_INTERFACES=FwdTest:FwdTestIndication,MemServerIndication:host
CPPFILES=test.cpp
CPPFILES+=$(SONICDIR)/sw/lpcap.c
BSVFILES=FwdTest.bsv FwdAPI.bsv FwdTypes.bsv
FPGAMAKE_CONNECTALFLAGS += -P mkPcieHostTop

CONNECTALFLAGS += -I $(SONICDIR)/sw/
CONNECTALFLAGS += --bsvpath=$(P4FPGADIR)/bsv/
CONNECTALFLAGS += --bsvpath=$(P4FPGADIR)/bsv/AsymmetricBRAM
CONNECTALFLAGS += --bsvpath=$(P4FPGADIR)/bsv/Bcam
CONNECTALFLAGS += --bsvpath=$(P4FPGADIR)/examples/paxos
CONNECTALFLAGS += --bsvpath=$(SONICDIR)/hw/bsv
CONNECTALFLAGS += --bsvpath=$(SONICDIR)/hw/generated
CONNECTALFLAGS += --verilog=$(P4FPGADIR)/bsv/AsymmetricBRAM
CONNECTALFLAGS += -D NicVersion=$(shell printf "%d" 0x`git rev-parse --short=8 HEAD`)
CONNECTALFLAGS += -D DataBusWidth=128
CONNECTALFLAGS += -D IMPORT_HOSTIF
CONNECTALFLAGS += -D BYTE_ENABLES
CONNECTALFLAGS += --bscflags="-show-range-conflict +RTS -K46777216 -RTS -demote-errors G0066:G0045 -suppress-warnings G0046:G0020:S0015:S0080:S0039 -steps-max-intervals 20"
CONNECTALFLAGS += -m $(P4FPGADIR)/bsv/AsymmetricBRAM/mem_model.c
CONNECTALFLAGS += -m $(P4FPGADIR)/bsv/matchtable_model.cpp

########################################################
# DE5 SUPPORT
########################################################
ifeq ($(BOARD), de5)
PIN_BINDINGS ?= PCIE:PCIE LED:LED OSC:OSC SFPA:SFPA SFPB:SFPB SFPC:SFPC SFPD:SFPD SFP:SFP I2C:I2C BUTTON:BUTTON
PINOUT_FILE = $(SONICDIR)/boards/de5.json
endif

########################################################
# NFSUME SUPPORT
########################################################
ifeq ($(BOARD), nfsume)
AUTOTOP = --interface pins:FwdTest.pins
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

run:
	(cd bluesim; ./bin/ubuntu.exe -p ../paxos.pcap)

run-small:
	(cd bluesim; ./bin/ubuntu.exe -p ../udp-small.pcap)

run-udp:
	(cd bluesim; ./bin/ubuntu.exe -p ../sendip.pcap)

run-intel:
	(cd bluesim; ./bin/ubuntu.exe -p ../ipv4noise.pcap)

include $(CONNECTALDIR)/Makefile.connectal
