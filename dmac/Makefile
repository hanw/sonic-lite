
QUARTUS_SH=$(shell which quartus_sh)
ROOTDIR=$(realpath .)
CONNECTALDIR?=$(ROOTDIR)/../../connectal
IPDIR?=$(ROOTDIR)/../../fpgamake-cache/$(shell basename `/bin/pwd`)/
PROJTOP?=$(ROOTDIR)
CONNECTALFLAGS += --bsvpath=$(PROJTOP)/../hw/bsv
CONNECTALFLAGS += --bsvpath=$(PROJTOP)/../hw/generated
CONNECTALFLAGS += --bsvpath=$(PROJTOP)/bsv

#BSVFILES=$(PROJTOP)/DmaTop.bsv $(PROJTOP)/bsv/DmaController.bsv #$(PROJTOP)/bsv/PcieDma.bsv #$(PROJTOP)/DmaTop.bsv 
BSVFILES=$(PROJTOP)/bsv/DmaTop.bsv $(PROJTOP)/../hw/bsv/DmaController.bsv 
CPPFILES=$(PROJTOP)/cpp/dmac.cpp $(PROJTOP)/cpp/testdma.cpp
#S2H_INTERFACES=DmaRequest:DmaTop.request0
S2H_INTERFACES=DmaRequest:DmaTop.request0,DmaTop.request1,DmaTop.request2,DmaTop.request3
#H2S_INTERFACES=DmaTop:DmaIndication
H2S_INTERFACES=DmaTop:DmaIndication,DmaIndication,DmaIndication,DmaIndication
MEM_READ_INTERFACES = lDmaTop.readClient
MEM_WRITE_INTERFACES = lDmaTop.writeClient
#AUTOTOP= --interface pins:DmaTop.pins
#PIN_TYPE=DmaTopPins
PIN_TYPE_INCLUDE=DmaTopPins
CONNECTALFLAGS += -D NumChannels=4
CONNECTALFLAGS += -D DataBusWidth=128
#CONNECTALFLAGS += -D BurstLenSize=10
include $(CONNECTALDIR)/Makefile.connectal
