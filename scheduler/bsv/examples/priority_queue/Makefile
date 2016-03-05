DEV_ROOT ?= $(HOME)
CONNECTALDIR ?= $(DEV_ROOT)/connectal
SONICDIR ?= $(DEV_ROOT)/sonic-lite
S2H_INTERFACES = PriorityQueueTopRequest:PriorityQueueTop.request
H2S_INTERFACES = PriorityQueueTop:PriorityQueueTopIndication
BSVFILES = $(SONICDIR)/scheduler/bsv/examples/priority_queue/PriorityQueueTop.bsv
CPPFILES = $(SONICDIR)/scheduler/bsv/examples/priority_queue/test.cpp

CONNECTALFLAGS += -D DataBusWidth=128
CONNECTALFLAGS += --bsvpath=$(CONNECTALDIR)/bsv
CONNECTALFLAGS += --bsvpath=$(SONICDIR)/hw/bsv/
CONNECTALFLAGS += --bsvpath=$(SONICDIR)/hw/generated/
CONNECTALFLAGS += -I $(SONICDIR)/sw/

CONNECTALFLAGS += --bscflags="-show-range-conflict +RTS -K46777216 -RTS -demote-errors G0066:G0045 -suppress-warnings G0046:G0020:S0015:S0080:S0039 -steps-max-intervals 20"

include $(CONNECTALDIR)/Makefile.connectal
