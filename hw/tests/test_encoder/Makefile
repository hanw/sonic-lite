CONNECTAL_DIR ?= ../../../../connectal
S2H_INTERFACES = EncoderTestRequest:EncoderTest.request
H2S_INTERFACES = EncoderTest:EncoderTestIndication
MEM_INTERFACES = lEncoderTest.dmaClient,nil
BSVFILES = EncoderTest.bsv ../../lib/bsv/Encoder.bsv
CPPFILES = test_encoder.cpp
BSCPATHFLAGS+= -bdir $(CONNECTAL_DIR)/bsv -bdir ../../lib/bsv
CONNECTALFLAGS+= -D DataBusWidth=128

include $(CONNECTAL_DIR)/Makefile.connectal
