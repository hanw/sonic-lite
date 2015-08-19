QUARTUS_SH=$(shell which quartus_sh)
ROOTDIR=$(realpath .)
CONNECTALDIR?=$(ROOTDIR)/../../connectal/
IPDIR?=$(ROOTDIR)/../../fpgamake-cache/$(shell basename `/bin/pwd`)/
PROJTOP?=$(ROOTDIR)
ALTERAPINOUT=$(PROJTOP)/boards/de5.json

CONNECTALFLAGS += --bscflags="-p +:$(PROJTOP)/hw/bsv:$(CONNECTALDIR)/bsv"
CONNECTALFLAGS += --bscflags="+RTS -K46777216 -RTS -demote-errors G0066:G0045 -suppress-warnings G0046:G0020:S0015:S0080:S0039 -steps-max-intervals 20"

S2H_INTERFACES=NicTopRequest:NicTop.request:host.derivedClock,host.derivedReset
H2S_INTERFACES=NicTop:NicTopIndication:host.derivedClock,host.derivedReset
AUTOTOP= --interface pins:NicTop.pins
PIN_TYPE = NicPins
PIN_TYPE_INCLUDE = NicTop
BSVFILES=$(PROJTOP)/NicTop.bsv
CPPFILES=$(PROJTOP)/sw/test.cpp
NUMBER_OF_MASTERS=0
PIN_BINDINGS?=PCIE:PCIE LED:LED OSC:OSC SFPA:SFPA SFPB:SFPB SFPC:SFPC SFPD:SFPD SFP:SFP I2C:CLOCK BUTTON:BUTTON
CONNECTALFLAGS += --tcl=$(PROJTOP)/../boards/de5_extra.qsf
CONNECTALFLAGS += -D NicVersion=$(shell date +"%y%m%d%H%M")
CONNECTALFLAGS += --verilog=$(PROJTOP)/hw/verilog/
CONNECTALFLAGS += -D PcieHostIF
CONNECTALFLAGS += -D DataBusWidth=128
CONNECTALFLAGS += -D IMPORT_HOST_CLOCKS
CONNECTALFLAGS += --derivedclockperiod=6.4
CONNECTALFLAGS += -l="tins"
#CONNECTALFLAGS += --chipscope=$(PROJTOP)/../../sonic-debug/stp/memread.stp
ifneq (, $(BLUESIM))
CONNECTALFLAGS += --pinfo=$(PROJTOP)/boards/sonic_synth.json
endif

include $(CONNECTALDIR)/Makefile.connectal
