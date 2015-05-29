CONNECTAL_DIR ?= ../../../../connectal
S2H_INTERFACES = BlockSyncTestRequest:BlockSyncTest.request
H2S_INTERFACES = BlockSyncTest:BlockSyncTestIndication
MEM_INTERFACES = lBlockSyncTest.dmaClient,nil
BSVFILES = BlockSyncTest.bsv ../../lib/bsv/BlockSync.bsv
CPPFILES = test_blocksync.cpp

CONNECTALFLAGS+= -D DataBusWidth=128
BSVPATHFLAGS+= -bdir $(CONNECTAL_DIR)/bsv -bdir ../../lib/bsv

include $(CONNECTAL_DIR)/Makefile.connectal
