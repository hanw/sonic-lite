CONNECTALDIR?=$(HOME)/dev/connectal
SONICDIR?=$(DEV_ROOT)/sonic-lite/

S2H_INTERFACES = Ddr3TestRequest:Ddr3Test.request
H2S_INTERFACES = Ddr3Test:Ddr3TestIndication,MemServerIndication:host

CONNECTALFLAGS += -D DataBusWidth=128
CONNECTALFLAGS += -D IMPORT_HOSTIF -D XILINX_SYS_CLK -D ClockDefaultParam
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/axiddr3/axiddr3.xci
CONNECTALFLAGS += --bsvpath=$(SONICDIR)/hw/bsv

BSVFILES = Ddr3Test.bsv
CPPFILES=testddr3.cpp

PIN_TYPE = Ddr3Pins
PIN_TYPE_INCLUDE = Ddr3Controller
AUTOTOP = --interface pins:Ddr3Test.ddr3

include $(CONNECTALDIR)/Makefile.connectal
