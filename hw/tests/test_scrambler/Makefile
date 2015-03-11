CONNECTAL_DIR ?= ../../../../connectal
INTERFACES = ScramblerTestRequest ScramblerTestIndication
BSVFILES = Top.bsv ScramblerTest.bsv ../../lib/bsv/Scrambler.bsv
CPPFILES = test_scrambler.cpp

CONNECTALFLAGS+= -D DataBusWidth=128

include $(CONNECTAL_DIR)/Makefile.connectal
