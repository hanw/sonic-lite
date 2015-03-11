CONNECTAL_DIR ?= ../../../../connectal
INTERFACES = EncoderTestRequest EncoderTestIndication
BSVFILES = Top.bsv EncoderTest.bsv ../../lib/bsv/Encoder.bsv ../../bsv/Ethernet.bsv
CPPFILES = test_encoder.cpp

CONNECTALFLAGS+= -D DataBusWidth=128

include $(CONNECTAL_DIR)/Makefile.connectal
