########################################################
# Basic Environment Setup
########################################################
ifeq ($(DEV_ROOT), )
    $(error DEV_ROOT not defined)
endif
CONNECTALDIR?=$(DEV_ROOT)/connectal
SONICDIR?=$(DEV_ROOT)/sonic-lite/
P4FPGADIR?=$(DEV_ROOT)/sonic-lite/p4

PIN_BINDINGS?=PCIE:PCIE LED:LED OSC:OSC SFPA:SFPA SFPB:SFPB SFPC:SFPC SFPD:SFPD SFP:SFP I2C:I2C BUTTON:BUTTON
PINOUT_FILE=$(SONICDIR)/boards/de5.json

########################################################
# Connectal Support
########################################################
S2H_INTERFACES=MatchTestRequest:MatchTest.request
H2S_INTERFACES=MatchTest:MatchTestIndication
BSVFILES=MatchTest.bsv $(P4FPGADIR)/bsv/MatchTable.bsv $(P4FPGADIR)/examples/tdm/TdmTypes.bsv
CPPFILES=test.cpp

CONNECTALFLAGS += --bsvpath=$(P4FPGADIR)/bsv
CONNECTALFLAGS += --bsvpath=$(P4FPGADIR)/bsv/Bcam
CONNECTALFLAGS += --bsvpath=$(P4FPGADIR)/bsv/AsymmetricBRAM
CONNECTALFLAGS += --verilog=$(P4FPGADIR)/bsv/AsymmetricBRAM
CONNECTALFLAGS += -m $(P4FPGADIR)/bsv/AsymmetricBRAM/mem_model.c

CONNECTALFLAGS += --nocache
#CONNECTALFLAGS += --chipscope=$(P4FPGADIR)/examples/match/debug.stp

run:
	(cd bluesim; ./bin/ubuntu.exe -a -s -l)

include $(SONICDIR)/p4/Makefile.common
include $(CONNECTALDIR)/Makefile.connectal
