CONNECTAL_DIR ?= ../../../connectal
INTERFACES = DescramblerTestRequest DescramblerTestIndication
BSVFILES = Top.bsv DescramblerTest.bsv ../../lib/bsv/Descrambler.bsv
CPPFILES = test_descrambler.cpp

CONNECTALFLAGS+= -D DataBusWidth=128

include $(CONNECTAL_DIR)/Makefile.connectal
