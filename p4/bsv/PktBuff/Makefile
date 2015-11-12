
########################################################
# Basic Environment Setup
########################################################
QUARTUS_SH=$(shell which quartus_sh)
ROOTDIR=$(realpath .)
CONNECTALDIR?=~/dev/connectal
SONICLIB?=$(ROOTDIR)/../../../
PROJLIB+=$(SONICLIB)/hw/lib/bsv:$(SONICLIB)/hw/bsv:$(ROOTDIR)/../AsymmetricBRAM:$(ROOTDIR)/../Bcam:$(ROOTDIR)/../MatchTable:$(ROOTDIR)/../:$(ROOTDIR)

ALTERAPINOUT=$(ROOTDIR)/../boards/de5.json

BSVFILES=$(ROOTDIR)/TbTop.bsv $(ROOTDIR)/Malloc.bsv
CONNECTALFLAGS += --bscflags="-p +:$(CONNECTALDIR)/bsv:$(PROJLIB)"

########################################################
# Connectal Support
########################################################
S2H_INTERFACES=TbRequest:TbTop.request
#H2S_INTERFACES=TbTop:TbIndication,MemServerIndication,MMUIndication
H2S_INTERFACES=TbTop:TbIndication,MemServerIndication,MallocIndication
#H2S_INTERFACES=TbTop:TbIndication
CPPFILES=$(ROOTDIR)/cpp/test.cpp

CONNECTALFLAGS += -D NicVersion=$(shell printf "%d" 0x`git rev-parse --short=8 HEAD`)
CONNECTALFLAGS += -D PcieHostIF
CONNECTALFLAGS += -D DataBusWidth=128
CONNECTALFLAGS += -D BYTE_ENABLES

CONNECTALFLAGS += -I="../../../sw/"
CONNECTALFLAGS += --bscflags="-show-range-conflict +RTS -K46777216 -RTS -demote-errors G0066:G0045 -suppress-warnings G0046:G0020:S0015:S0080:S0039 -steps-max-intervals 20"
FPGAMAKE_CONNECTALFLAGS += -P mkPcieHostTop

include $(CONNECTALDIR)/Makefile.connectal
