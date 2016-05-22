CONNECTALDIR ?= ../../../../connectal
ROOTDIR=$(realpath .)
PROJTOP?=$(ROOTDIR)

S2H_INTERFACES = DtpmTestRequest:DtpmTest.request
H2S_INTERFACES = DtpmTest:DtpmTestIndication
MEM_READ_INTERFACES = lDtpmTest.dmaClient
BSVFILES = DtpmTest.bsv ../../bsv/Dtpm.bsv
CPPFILES = test_dtp.cpp
CONNECTALFLAGS += --bsvpath=$(PROJTOP)/../../bsv
CONNECTALFLAGS += -D DataBusWidth=128

include $(CONNECTALDIR)/Makefile.connectal
