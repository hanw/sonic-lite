
########################################################
# Basic Environment Setup
########################################################
QUARTUS_SH=$(shell which quartus_sh)
P4FPGADIR?=$(HOME)/dev/sonic-lite/p4
SONICDIR?=$(HOME)/dev/sonic-lite/
CONNECTALDIR?=$(HOME)/dev/connectal
PROJLIB+=$(SONICDIR)/hw/lib/bsv:$(SONICDIR)/hw/bsv:$(P4FPGADIR)/bsv/AsymmetricBRAM:$(P4FPGADIR)/bsv/Bcam:$(P4FPGADIR)/bsv/MatchTable:$(P4FPGADIR)/bsv/

ALTERAPINOUT=$(P4FPGADIR)/boards/de5.json

BSVFILES=MatchTest.bsv $(P4FPGADIR)/bsv/MatchTable/MatchTable.bsv $(P4FPGADIR)/bsv/MatchTable/MatchTableTypes.bsv
CONNECTALFLAGS += --bscflags="-p +:$(CONNECTALDIR)/bsv:$(PROJLIB)"

########################################################
# Connectal Support
########################################################
S2H_INTERFACES=MatchTestRequest:MatchTest.request
H2S_INTERFACES=MatchTest:MatchTestIndication,MemServerIndication
CPPFILES=test.cpp

CONNECTALFLAGS += -D NicVersion=$(shell printf "%d" 0x`git rev-parse --short=8 HEAD`)
CONNECTALFLAGS += -D PcieHostIF
CONNECTALFLAGS += -D DataBusWidth=128
CONNECTALFLAGS += -D BYTE_ENABLES
CONNECTALFLAGS += --verilog=$(P4FPGADIR)/bsv/AsymmetricBRAM/
CONNECTALFLAGS += -m $(P4FPGADIR)/bsv/AsymmetricBRAM/mem_model.c

CONNECTALFLAGS += -I $(SONICDIR)/sw
CONNECTALFLAGS += --bscflags="-show-range-conflict +RTS -K46777216 -RTS -demote-errors G0066:G0045 -suppress-warnings G0046:G0020:S0015:S0080:S0039 -steps-max-intervals 20"
#FPGAMAKE_CONNECTALFLAGS += -P mkPcieHostTop

include $(CONNECTALDIR)/Makefile.connectal
