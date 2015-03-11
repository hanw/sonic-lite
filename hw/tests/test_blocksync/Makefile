CONNECTAL_DIR ?= ../../../../connectal
INTERFACES = BlockSyncTestRequest BlockSyncTestIndication
BSVFILES = Top.bsv BlockSyncTest.bsv ../../lib/bsv/BlockSync.bsv
CPPFILES = test_blocksync.cpp

CONNECTALFLAGS+= -D DataBusWidth=128

include $(CONNECTAL_DIR)/Makefile.connectal
