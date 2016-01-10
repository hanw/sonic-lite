CONNECTALDIR ?= ../../../../connectal
S2H_INTERFACES = DtpTestRequest:DtpTest.request
H2S_INTERFACES = DtpTest:DtpTestIndication
MEM_INTERFACES = lDtpTest.dmaClient,nil
#INTERFACES = DtpTestRequest DtpTestIndication
BSVFILES = DtpTest.bsv ../../bsv/Dtp.bsv
CPPFILES = test_dtp.cpp
BSCPATHFLAGS+= -bdir $(CONNECTALDIR)/bsv
CONNECTALFLAGS+= -D DataBusWidth=128

include $(CONNECTALDIR)/Makefile.connectal
