
CONNECTALDIR?=../connectal
INTERFACES=Simple
BSVFILES=SimpleIF.bsv Top.bsv
CPPFILES=testsimple.cpp
NUMBER_OF_MASTERS =0

NEED_ALTERA_PHY_de5=1

prebuild::
ifeq ($(NEED_ALTERA_PHY_$(BOARD)), 1)
	(cd $(BOARD); quartus_sh -t ../connectal-synth-pll.tcl)
	(cd $(BOARD); quartus_sh -t ../connectal-synth-mac.tcl)
endif

include $(CONNECTALDIR)/Makefile.connectal
