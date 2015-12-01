CONNECTAL_DIR ?= ../../../../connectal
INTERFACES = MacTxTestRequest MacTxTestIndication
BSVFILES = Top.bsv MacTxTest.bsv ../../lib/bsv/MacTx.bsv ../../bsv/Ethernet.bsv
CPPFILES = test_mac_tx.cpp

CONNECTALFLAGS+= -D DataBusWidth=128

include $(CONNECTAL_DIR)/Makefile.connectal
