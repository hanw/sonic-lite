########################################################
# Basic Environment Setup
########################################################
ifeq ($(DEV_ROOT), )
    $(error DEV_ROOT not defined)
endif
CONNECTALDIR?=$(DEV_ROOT)/connectal
SONICDIR?=$(DEV_ROOT)/sonic-lite/
P4FPGADIR?=$(DEV_ROOT)/sonic-lite/p4

CONNECTALFLAGS += --bsvpath=$(P4FPGADIR)/bsv/
CONNECTALFLAGS += --bsvpath=$(P4FPGADIR)/bsv/AsymmetricBRAM
CONNECTALFLAGS += --bsvpath=$(P4FPGADIR)/bsv/Bcam
CONNECTALFLAGS += --bsvpath=$(P4FPGADIR)/bsv/MatchTable
#
PINOUT_FILE=$(P4FPGADIR)/boards/de5.json

########################################################
# Connectal Support
########################################################
S2H_INTERFACES=ParserTestRequest:ParserTest.request
H2S_INTERFACES=ParserTest:ParserTestIndication
CPPFILES=test.cpp
BSVFILES=ParserTest.bsv $(P4FPGADIR)/bsv/MatchTable/MatchTable.bsv $(P4FPGADIR)/bsv/MatchTable/MatchTableTypes.bsv
FPGAMAKE_CONNECTALFLAGS += -P mkPcieHostTop

CONNECTALFLAGS += -m $(P4FPGADIR)/bsv/AsymmetricBRAM/mem_model.c

include $(SONICDIR)/p4/Makefile.common
include $(CONNECTALDIR)/Makefile.connectal
