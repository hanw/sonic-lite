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
S2H_INTERFACES=TbRequest:TbTop.request
H2S_INTERFACES=TbTop:TbIndication,MemServerIndication,MallocIndication
BSVFILES=TbTop.bsv $(P4FPGADIR)/bsv/Malloc.bsv
CPPFILES=test.cpp

run:
	(cd bluesim; ./bin/ubuntu.exe -p ../udp-small.pcap)

malloc:
	(cd bluesim; ./bin/ubuntu.exe -m)

include $(SONICDIR)/p4/Makefile.common
include $(CONNECTALDIR)/Makefile.connectal
