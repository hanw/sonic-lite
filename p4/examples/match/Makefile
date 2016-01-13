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
PINOUT_FILE=$(P4FPGADIR)/boards/de5.json

########################################################
# Connectal Support
########################################################
S2H_INTERFACES=MatchTestRequest:MatchTest.request
H2S_INTERFACES=MatchTest:MatchTestIndication,MemServerIndication
BSVFILES=MatchTest.bsv $(P4FPGADIR)/bsv/MatchTable/MatchTable.bsv $(P4FPGADIR)/bsv/MatchTable/MatchTableTypes.bsv
CPPFILES=test.cpp

CONNECTALFLAGS += --verilog=$(P4FPGADIR)/bsv/AsymmetricBRAM/
CONNECTALFLAGS += -m $(P4FPGADIR)/bsv/AsymmetricBRAM/mem_model.c

include $(SONICDIR)/p4/Makefile.common
include $(CONNECTALDIR)/Makefile.connectal
