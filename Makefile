
CONNECTALDIR?=../connectal
INTERFACES=Simple
BSVFILES=SimpleIF.bsv Top.bsv
CPPFILES=testsimple.cpp
NUMBER_OF_MASTERS =0

# Supported Platforms:
# {vendor}_{platform}=1
ALTERA_de5=1
PIN_BINDINGS?=-b PCIE:PCIE -b LED:LED -b OSC:OSC

gentarget:: $(BOARD)/sources/sonic.qsf

prebuild::
ifeq ($(ALTERA_$(BOARD)), 1)
	@echo "generating 10GbE Mac ..."
#	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t ../connectal-synth-pll.tcl)
#	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t ../connectal-synth-mac.tcl)
endif

$(BOARD)/sources/sonic.qsf: sonic.json $(CONNECTALDIR)/boardinfo/$(BOARD).json
ifeq ($(ALTERA_$(BOARD)), 1)
	mkdir -p $(BOARD)/sources
	$(CONNECTALDIR)/scripts/generate-constraints.py -f altera $(PIN_BINDINGS) -o $(BOARD)/sources/$(BOARD).qsf $(CONNECTALDIR)/boardinfo/$(BOARD).json sonic.json
endif

include $(CONNECTALDIR)/Makefile.connectal
