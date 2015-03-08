CONNECTALDIR ?= ../../../connectal
INTERFACES = DtpTestRequest DtpTestIndication
BSVFILES = Top.bsv DtpTest.bsv ../../bsv/Dtp.bsv ../../bsv/Ethernet.bsv
CPPFILES = test_dtp.cpp

CONNECTALFLAGS+= -D DataBusWidth=128

include $(CONNECTALDIR)/Makefile.connectal
