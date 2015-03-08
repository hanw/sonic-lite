CONNECTAL_DIR ?= ../../../connectal
INTERFACES = DecoderTestRequest DecoderTestIndication
BSVFILES = Top.bsv DecoderTest.bsv ../../lib/bsv/Decoder.bsv ../../bsv/Ethernet.bsv
CPPFILES = test_decoder.cpp

CONNECTALFLAGS+= -D DataBusWidth=128

include $(CONNECTAL_DIR)/Makefile.connectal
