CONNECTAL_DIR ?= ../../../../connectal
INTERFACES = PmaTestRequest PmaTestIndication
BSVFILES = Top.bsv PmaTest.bsv ../../lib/Gearbox_40_66.bsv
CPPFILES = test_gearbox.cpp
CONNECTALFLAGS += --bscflags="+RTS -K50000K -RTS"

include $(CONNECTAL_DIR)/Makefile.connectal
