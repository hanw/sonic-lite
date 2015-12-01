DEV_ROOT ?= $(HOME)/dev/
CONNECTAL_DIR ?= $(DEV_ROOT)/connectal
SONIC_DIR ?= $(DEV_ROOT)/sonic-lite
S2H_INTERFACES = TestRequest:Test.request
H2S_INTERFACES = Test:TestIndication
BSVFILES = Test.bsv
CPPFILES = test.cpp

CONNECTALFLAGS += -D DataBusWidth=128
CONNECTALFLAGS += --bsvpath=$(CONNECTAL_DIR)/bsv
CONNECTALFLAGS += --bsvpath=$(SONIC_DIR)/hw/lib/bsv
CONNECTALFLAGS += --bsvpath=$(SONIC_DIR)/hw/bsv/

CONNECTALFLAGS += -I $(SONIC_DIR)/sw/

include $(CONNECTAL_DIR)/Makefile.connectal
