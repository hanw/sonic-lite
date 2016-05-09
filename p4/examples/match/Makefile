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
S2H_INTERFACES=MatchTestRequest:MatchTest.request
H2S_INTERFACES=MatchTest:MatchTestIndication
BSVFILES=MatchTest.bsv $(P4FPGADIR)/bsv/MatchTable.bsv
CPPFILES=test.cpp
CPPFILES += $(SONICDIR)/sw/lpcap.c

CONNECTALFLAGS += --bsvpath=$(P4FPGADIR)/bsv
CONNECTALFLAGS += --bsvpath=$(P4FPGADIR)/bsv/Bcam
CONNECTALFLAGS += --bsvpath=$(P4FPGADIR)/bsv/AsymmetricBRAM
CONNECTALFLAGS += --verilog=$(P4FPGADIR)/bsv/AsymmetricBRAM
CONNECTALFLAGS += -m $(P4FPGADIR)/bsv/AsymmetricBRAM/mem_model.c
CONNECTALFLAGS += -m $(P4FPGADIR)/bsv/matchtable_model.cpp
CONNECTALFLAGS += --cxxflags=-std=c++11
CONNECTALFLAGS += --nocache

#######################################################
# DE5 Specific Settings
#######################################################
ifeq ($(BOARD), de5)
#AUTOTOP = --interface pins:MatchTest.pins
#PIN_TYPE = DE5Pins
#PIN_TYPE_INCLUDE = DE5Pins
PIN_BINDINGS ?= PCIE:PCIE OSC:OSC SFPA:SFPA SFPB:SFPB SFPC:SFPC SFPD:SFPD SFP:SFP LED:LED I2C:I2C
PINOUT_FILE = $(SONICDIR)/boards/de5.json

CONNECTALFLAGS += --bsvpath=$(P4FPGADIR)/bsv
CONNECTALFLAGS += --verilog=$(SONICDIR)/hw/verilog/si570/
endif

########################################################
# NFSUME SUPPORT
########################################################
ifeq ($(BOARD), nfsume)
#AUTOTOP = --interface pins:MatchTest.pins
#PIN_TYPE = NfsumePins
#PIN_TYPE_INCLUDE = NfsumePins
PIN_BINDINGS ?= LED:LED SFP:SFP SFPA:SFPA SFPB:SFPB SFPC:SFPC SFPD:SFPD
PINOUT_FILE = $(SONICDIR)/boards/nfsume.json
CONNECTALFLAGS += -D XILINX_SYS_CLK
#CONNECTALFLAGS += --constraint=timing_constraints.xdc --implconstraint=timing_constraints.xdc
endif

run:
	(cd bluesim; ./bin/ubuntu.exe -a -s -l)

include $(SONICDIR)/p4/Makefile.common
include $(CONNECTALDIR)/Makefile.connectal
