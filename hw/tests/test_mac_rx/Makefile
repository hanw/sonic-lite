CONNECTAL_DIR ?= ../../../connectal
INTERFACES = MacRxTestRequest MacRxTestIndication
BSVFILES = Top.bsv MacRxTest.bsv ../../lib/bsv/MacRx.bsv ../../bsv/Ethernet.bsv
CPPFILES = test_mac_rx.cpp

CONNECTALFLAGS+= -D DataBusWidth=128

include $(CONNECTAL_DIR)/Makefile.connectal
