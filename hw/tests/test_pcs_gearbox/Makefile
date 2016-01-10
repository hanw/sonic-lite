CONNECTAL_DIR ?= ../../../../connectal
INTERFACES = PcsTestRequest PcsTestIndication
BSVFILES = Top.bsv PcsTest.bsv ../../bsv/Dtp.bsv ../../bsv/EthPcs.bsv ../../bsv/Decoder.bsv
CPPFILES = test_pcs.cpp
BURST_LEN_SIZE=10

CONNECTALFLAGS+= -D DataBusWidth=256
include $(CONNECTAL_DIR)/Makefile.connectal
