
########################################################
# Basic Environment Setup
########################################################
QUARTUS_SH=$(shell which quartus_sh)
ROOTDIR=$(realpath .)
CONNECTALDIR?=$(ROOTDIR)/../../connectal/
IPDIR?=$(ROOTDIR)/../../fpgamake-cache/$(shell basename `/bin/pwd`)/
PROJTOP?=$(ROOTDIR)
CONNECTALFLAGS += --bsvpath=$(PROJTOP)/../hw/bsv
CONNECTALFLAGS += --bsvpath=$(PROJTOP)/../hw/generated
CONNECTALFLAGS += --bsvpath=$(PROJTOP)/bsv/AsymmetricBRAM
CONNECTALFLAGS += --bsvpath=$(PROJTOP)/bsv/Bcam
CONNECTALFLAGS += --bsvpath=$(PROJTOP)/bsv/MatchTable
CONNECTALFLAGS += --bsvpath=$(PROJTOP)/bsv/PktBuff

ALTERAPINOUT=$(PROJTOP)/../boards/de5.json

ifeq ($(P4),)
# compile manual bsv
BSVFILES=$(PROJTOP)/bsv/P4Top.bsv $(PROJTOP)/bsv/P4Types.bsv $(PROJTOP)/bsv/PktBuff/Malloc.bsv
CONNECTALFLAGS += --bsvpath=$(PROJTOP)/bsv
CONNECTALFLAGS += --bsvpath=$(CONNECTALDIR)/bsv
else
# compile generated P4 code
BSVFILES=$(PROJTOP)/build/bluespec/src/P4Top.bsv $(PROJTOP)/build/bluespec/src/P4Types.bsv
CONNECTALFLAGS += --bsvpath=$(PROJTOP)/build/bluespec/src
CONNECTALFLAGS += --bsvpath=$(CONNECTALDIR)/bsv
endif

# if P4Top needs a second clock.
#S2H_INTERFACES=P4TopRequest:P4Top.request:host.derivedClock,host.derivedReset
#H2S_INTERFACES=P4Top:P4TopIndication:host.derivedClock,host.derivedReset
#CONNECTALFLAGS += -D IMPORT_HOST_CLOCKS
#CONNECTALFLAGS += --derivedclockperiod=6.4

########################################################
# Top Level Switches
########################################################
CONFIG_PCIE=y
CONFIG_NETWORK=y
CONFIG_P4=y

########################################################
# Connectal Support
########################################################
S2H_INTERFACES=P4TopRequest:P4Top.request
H2S_INTERFACES=P4Top:P4TopIndication,MemServerIndication,MallocIndication
AUTOTOP= --interface pins:P4Top.pins
PIN_TYPE = DE5Pins
PIN_TYPE_INCLUDE = DE5Pins
CPPFILES=$(PROJTOP)/cpp/test.cpp
PIN_BINDINGS?=PCIE:PCIE LED:LED OSC:OSC SFPA:SFPA SFPB:SFPB SFPC:SFPC SFPD:SFPD SFP:SFP I2C:CLOCK BUTTON:BUTTON
PINOUT_FILE=../boards/de5.json

ifeq ($(CONFIG_PCIE), y)
CONNECTALFLAGS += -D NicVersion=$(shell printf "%d" 0x`git rev-parse --short=8 HEAD`)
CONNECTALFLAGS += --verilog=$(PROJTOP)/../hw/verilog/
#CONNECTALFLAGS += --verilog=$(PROJTOP)/../hw/ip/ii2dcam/
CONNECTALFLAGS += -D PcieHostIF
CONNECTALFLAGS += -D DataBusWidth=128
CONNECTALFLAGS += -D BYTE_ENABLES
CONNECTALFLAGS += -D USE_ALTERA_CLKCTRL
CONNECTALFLAGS += -D USE_ALTERA_PLL_PMA
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/pll_156/altera_pll_156.qip
#CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/altera_clkctrl/altera_clkctrl.qip

CONNECTALFLAGS += -I="../sw/"
CONNECTALFLAGS += --bscflags="-show-range-conflict +RTS -K46777216 -RTS -demote-errors G0066:G0045 -suppress-warnings G0046:G0020:S0015:S0080:S0039 -steps-max-intervals 20"
FPGAMAKE_CONNECTALFLAGS += -P mkPcieHostTop

CONNECTALFLAGS += --verilog=$(PROJTOP)/../hw/verilog/si570/
CONNECTALFLAGS += --floorplan=$(PROJTOP)/floorplan/p4fpga.qsf
#CONNECTALFLAGS += --tcl=$(PROJTOP)/../boards/quartus_advanced_settings.qsf
endif #CONFIG_PCIE

########################################################
# 10GbE Support
########################################################
ifeq ($(CONFIG_NETWORK), y)
FPGAMAKE_CONNECTALFLAGS += -P mkEthMac
CONNECTALFLAGS += -D DEBUG_ETH
CONNECTALFLAGS += -D USE_ALTERA_10GBASER
CONNECTALFLAGS += -D USE_ALTERA_MAC
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/altera_xcvr_10gbaser_wrapper/altera_xcvr_10gbaser_wrapper.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/altera_mac/altera_mac.qip
#CONNECTALFLAGS += --chipscope=$(PROJTOP)/xgmii.stp
endif #CONFIG_NETWORK

########################################################
# P4 Support
########################################################
ifeq ($(CONFIG_P4), y)
CONNECTALFLAGS += --verilog=$(PROJTOP)/bsv/AsymmetricBRAM/
#CONNECTALFLAGS += -D DEBUG_MATCH_TABLE
CONNECTALFLAGS += -D DEBUG_BCAM
#CONNECTALFLAGS += -D MTABLE_HASH
#CONNECTALFLAGS += -D MTABLE_CAM
#CONNECTALFLAGS += -D MTABLE
CONNECTALFLAGS += -m $(PROJTOP)/bsv/AsymmetricBRAM/mem_model.c
FPGAMAKE_CONNECTALFLAGS += -P mkBinaryCam_1024_9
endif #CONFIG_P4

# P4 support
P4FACTORY ?=$(ROOTDIR)/../../p4/p4factory/
export TARGET_ROOT :=$(abspath $(dir $(lastword $(MAKEFILE_LIST))))
export P4_INPUT := p4src/source_routing.p4
export P4_NAME := source_routing
include ${P4FACTORY}/init.mk
MAKEFILES_DIR := ${P4FACTORY}/makefiles
include ${MAKEFILES_DIR}/common.mk
SUBMODULE_P4C_FPGA := ${P4FACTORY}/../p4c-fpga
include ${SUBMODULE_P4C_FPGA}/p4c-fpga.mk

P4_TARGET=bluesim altera xilinx
$(addprefix p4.,$(P4_TARGET)): p4fpga

TEST_PACKET_DIR=$(ROOTDIR)/tests/pcap
include ${TEST_PACKET_DIR}/packet.mk

regenerate-pcap:
	$(Q)python ${TEST_PACKET_DIR}/generate-pcap.py --out-dir=${TEST_PACKET_DIR}

$(addprefix test.,$(TEST_PACKET)):
	RUN_ARGS=${TEST_PACKET_DIR}/$(subst test.,,$@).pcap make run.bluesim

prebuild::
ifneq (, $(QUARTUS_SH))
ifeq (de5, $(BOARD))
ifeq ($(CONFIG_NETWORK), y)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) $(QUARTUS_SH) -t $(PROJTOP)/../hw/scripts/generate-mac.tcl)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) $(QUARTUS_SH) -t $(PROJTOP)/../hw/scripts/connectal-synth-phy.tcl)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) $(QUARTUS_SH) -t $(PROJTOP)/../hw/scripts/connectal-synth-pma.tcl)
endif
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) $(QUARTUS_SH) -t $(PROJTOP)/../hw/scripts/connectal-synth-misc.tcl)
	#(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) $(QUARTUS_SH) -t $(PROJTOP)/../hw/scripts/connectal-synth-pciedma.tcl)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) $(QUARTUS_SH) -t $(CONNECTALDIR)/scripts/connectal-synth-pll.tcl)
endif
endif

#gentarget::
#	make -C $(PROJTOP)/../hw/ip/ii2dcam

run:
	RUNPARAM=${RUNPARAM} NOFPGAJTAG=1 make run.de5

program:
	SERIALNO=${SERIALNO} make run.de5

include $(CONNECTALDIR)/Makefile.connectal
