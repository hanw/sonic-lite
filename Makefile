
CONNECTALDIR?=../connectal
INTERFACES = Simple
BSVFILES = SimpleIF.bsv Top.bsv
CPPFILES=testsimple.cpp
NUMBER_OF_MASTERS =0

prebuild::
	(cd $(BOARD); quartus_sh -t ../connectal-synth-pll.tcl)
	(cd $(BOARD); quartus_sh -t ../connectal-synth-mac.tcl)

include $(CONNECTALDIR)/Makefile.connectal
