QUARTUS_SH=$(shell which quartus_sh)
ROOTDIR=$(realpath .)
CONNECTALDIR?=$(ROOTDIR)/../../connectal/
IPDIR?=$(ROOTDIR)/../../fpgamake-cache/$(shell basename `/bin/pwd`)/
PROJTOP?=$(ROOTDIR)
PROJLIB=$(PROJTOP)/../hw/lib/bsv:$(PROJTOP)/../hw/bsv

ALTERAPINOUT=$(PROJTOP)/boards/de5.json

ifndef P4FACTORY
P4FACTORY=$(ROOTDIR)/../../p4/p4factory/
endif

ifeq ($(P4),)
# compile manual bsv
BSVFILES=$(PROJTOP)/bsv/P4Top.bsv $(PROJTOP)/bsv/Types.bsv
CONNECTALFLAGS += --bscflags="-p +:$(PROJTOP)/bsv:$(CONNECTALDIR)/bsv:$(PROJLIB)"
else
# compile generated P4 code
BSVFILES=$(PROJTOP)/build/bluespec/src/P4Top.bsv $(PROJTOP)/build/bluespec/src/Types.bsv
CONNECTALFLAGS += --bscflags="-p +:$(PROJTOP)/build/bluespec/src:$(CONNECTALDIR)/bsv:$(PROJLIB)"
endif

S2H_INTERFACES=P4TopRequest:P4Top.request:host.derivedClock,host.derivedReset
H2S_INTERFACES=P4Top:P4TopIndication:host.derivedClock,host.derivedReset
AUTOTOP= --interface pins:P4Top.pins
PIN_TYPE = P4Pins
PIN_TYPE_INCLUDE = P4Top
CPPFILES=$(PROJTOP)/cpp/test.cpp
PIN_BINDINGS?=PCIE:PCIE LED:LED OSC:OSC SFPA:SFPA SFPB:SFPB SFPC:SFPC SFPD:SFPD SFP:SFP I2C:CLOCK BUTTON:BUTTON
CONNECTALFLAGS += --tcl=$(PROJTOP)/../boards/de5_extra.qsf
CONNECTALFLAGS += -D NicVersion=$(shell date +"%y%m%d%H%M")
CONNECTALFLAGS += --verilog=$(PROJTOP)/hw/verilog/
CONNECTALFLAGS += -D PcieHostIF
CONNECTALFLAGS += -D DataBusWidth=128
CONNECTALFLAGS += -D IMPORT_HOST_CLOCKS
CONNECTALFLAGS += --derivedclockperiod=6.4
CONNECTALFLAGS += -l="tins"
CONNECTALFLAGS += -I="../sw/"
CONNECTALFLAGS += --bscflags="-show-range-conflict +RTS -K46777216 -RTS -demote-errors G0066:G0045 -suppress-warnings G0046:G0020:S0015:S0080:S0039 -steps-max-intervals 20"
#CONNECTALFLAGS += --chipscope=$(PROJTOP)/../../sonic-debug/stp/memread.stp

# P4 support
export TARGET_ROOT :=$(abspath $(dir $(lastword $(MAKEFILE_LIST))))
export P4_INPUT := p4src/sonic.p4
export P4_NAME := sonic
include ${P4FACTORY}/init.mk
MAKEFILES_DIR := ${P4FACTORY}/makefiles
include ${MAKEFILES_DIR}/common.mk
SUBMODULE_P4C_FPGA := ${P4FACTORY}/../p4c-fpga
include ${SUBMODULE_P4C_FPGA}/p4c-fpga.mk

include $(CONNECTALDIR)/Makefile.connectal

p4.%: p4fpga

.PHONY: p4fpga
