CONNECTALDIR ?= ../../../../connectal

S2H_INTERFACES = DtpmTestRequest:DtpmTest.request
H2S_INTERFACES = DtpmTest:DtpmTestIndication
MEM_INTERFACES = lDtpmTest.dmaClient,nil
BSVFILES = DtpmTest.bsv ../../bsv/Dtpm.bsv
CPPFILES = test_dtp.cpp
BSCPATHFLAGS+= -bdir $(CONNECTALDIR)/bsv -bdir ../../lib/bsv
CONNECTALFLAGS+= -D DataBusWidth=64 -m ../../lib/cpp/file_interface.cpp

include $(CONNECTALDIR)/Makefile.connectal
