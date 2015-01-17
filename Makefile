
CONNECTALDIR?=../connectal
INTERFACES=Simple
BSVFILES=bsv/PcieAlteraTbWrap.bsv SimpleIF.bsv Top.bsv
CPPFILES=testsimple.cpp
NUMBER_OF_MASTERS =0
CONNECTALFLAGS += --pinfo=`pwd`/proj.json
BSVPATH+=`pwd`/bsv

# Supported Platforms:
# {vendor}_{platform}=1
ALTERA_SIM_vsim=1
ALTERA_SYNTH_de5=1

PIN_BINDINGS?=-b PCIE:PCIE -b LED:LED -b OSC:OSC

QSYS_SIMDIR=pcie_tbed
QUARTUS_INSTALL_DIR="/home/hwang/altera/14.0/quartus/"

include tests/Makefile.pcie

.PHONY: vsim

gentarget:: $(BOARD)/sources/sonic.qsf

prebuild::
ifeq ($(ALTERA_SIM_$(BOARD)), 1)
#	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t ../connectal-synth-pll.tcl)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t ../connectal-simu-pcietb.tcl)
endif
ifeq ($(ALTERA_SYNTH_$(BOARD)), 1)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t ../connectal-synth-mac.tcl)
endif

$(BOARD)/sources/sonic.qsf: sonic.json $(CONNECTALDIR)/boardinfo/$(BOARD).json
ifeq ($(ALTERA_SYNTH_$(BOARD)), 1)
	mkdir -p $(BOARD)/sources
	$(CONNECTALDIR)/scripts/generate-constraints.py -f altera $(PIN_BINDINGS) -o $(BOARD)/sources/$(BOARD).qsf $(CONNECTALDIR)/boardinfo/$(BOARD).json sonic.json
endif

BSV_VERILOG_FILES+=$(PCIE_TBED_VERILOG_FILES)

vsim: gen.vsim prebuild
	make -C $@ vsim
#	$(Q)bsc -D BSV_TIMESCALE=1ns/1ns -verilog -vsearch +:$(QSYS_SIMDIR)/simulation/submodules/ \
#		-vsim ./bsc_build_vsim_modelsim -e tb -o run_simulation -Xv "+incdir+$(QSYS_SIMDIR)/simulation/submodules/" \
#		$(BSV_VERILOG_FILES)

include $(CONNECTALDIR)/Makefile.connectal
