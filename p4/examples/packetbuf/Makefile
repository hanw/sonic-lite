########################################################
# Basic Environment Setup
########################################################
DEV_ROOT ?= $(HOME)/dev/
CONNECTALDIR?=$(DEV_ROOT)/connectal
SONICDIR?=$(DEV_ROOT)/sonic-lite/
P4FPGADIR?=$(DEV_ROOT)/sonic-lite/p4

ALTERAPINOUT=$(ROOTDIR)/../boards/de5.json


########################################################
# Connectal Support
########################################################
S2H_INTERFACES=TbRequest:TbTop.request
H2S_INTERFACES=TbTop:TbIndication,MemServerIndication,MallocIndication
BSVFILES=TbTop.bsv $(P4FPGADIR)/bsv/Malloc.bsv
CPPFILES=cpp/test.cpp

CONNECTALFLAGS += --bsvpath=$(SONICDIR)/hw/lib/bsv
CONNECTALFLAGS += --bsvpath=$(SONICDIR)/hw/bsv
CONNECTALFLAGS += --bsvpath=$(SONICDIR)/hw/generated
CONNECTALFLAGS += -I $(SONICDIR)/sw

CONNECTALFLAGS += -D NicVersion=$(shell printf "%d" 0x`git rev-parse --short=8 HEAD`)
CONNECTALFLAGS += -D PcieHostIF
CONNECTALFLAGS += -D DataBusWidth=128
CONNECTALFLAGS += -D BYTE_ENABLES

CONNECTALFLAGS += -I="../../../sw/"
CONNECTALFLAGS += --bscflags="-show-range-conflict +RTS -K46777216 -RTS -demote-errors G0066:G0045 -suppress-warnings G0046:G0020:S0015:S0080:S0039 -steps-max-intervals 20"
FPGAMAKE_CONNECTALFLAGS += -P mkPcieHostTop

include $(CONNECTALDIR)/Makefile.connectal
