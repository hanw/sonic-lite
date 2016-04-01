QUARTUS_SH=$(shell which quartus_sh)
ROOTDIR=$(realpath .)
CONNECTALDIR?=$(ROOTDIR)/../../../../connectal/
IPDIR?=$(ROOTDIR)/../../../../fpgamake-cache/$(shell basename `/bin/pwd`)/
PROJTOP?=$(ROOTDIR)
SONICDIR?=$(ROOTDIR)/../../../

CONNECTALFLAGS += --bscflags="+RTS -K46777216 -RTS -demote-errors G0066:G0045 -suppress-warnings G0046:G0020:S0015:S0080:S0039 -steps-max-intervals 20"
CONNECTALFLAGS += --bsvpath=$(PROJTOP)/../../../hw/bsv
CONNECTALFLAGS += --bsvpath=$(PROJTOP)/../../../hw/generated
CONNECTALFLAGS += --bsvpath=$(PROJTOP)/../../../p4/examples/tdm/

S2H_INTERFACES=TestRequest:TestTop.request1 DmaRequest:TestTop.request2,TestTop.request3,TestTop.request4,TestTop.request5
H2S_INTERFACES=TestTop:TestIndication,DmaIndication,DmaIndication,DmaIndication,DmaIndication
BSVFILES=$(PROJTOP)/TestTop.bsv $(PROJTOP)/TestAPI.bsv $(PROJTOP)/../../bsv/DmaEth.bsv
CPPFILES=$(PROJTOP)/testdma.cpp $(PROJTOP)/../../../sw/dmac.cpp 
CONNECTALFLAGS += -I $(PROJTOP)/../../../sw/
CONNECTALFLAGS += -D DataBusWidth=128
CONNECTALFLAGS += -D BYTE_ENABLES
CONNECTALFLAGS += -D NumChannels=4
CONNECTALFLAGS += -D DEBUG_ETH
CONNECTALFLAGS += -D PcieHostIF
MEM_READ_INTERFACES = lTestTop.readClient
MEM_WRITE_INTERFACES = lTestTop.writeClient

ifneq (, $(BLUESIM))
CONNECTALFLAGS += --pinfo=$(PROJTOP)/../../../boards/dtp_synth.json
endif

AUTOTOP = --interface pins:TestTop.pins
PIN_TYPE = DE5Pins
PIN_TYPE_INCLUDE = DE5Pins
PIN_BINDINGS ?= PCIE:PCIE OSC:OSC SFPA:SFPA SFPB:SFPB SFPC:SFPC SFPD:SFPD SFP:SFP LED:LED I2C:I2C
PINOUT_FILE = $(SONICDIR)/boards/de5.json
CONNECTALFLAGS += --nocache
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/mac_10gbe.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/altera_xcvr_10gbaser_wrapper.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/pll_156/altera_pll_156.qip
#CONNECTALFLAGS += --chipscope=$(PROJTOP)/stp1.stp

CONNECTALFLAGS += --verilog=$(SONICDIR)/hw/verilog/si570/

prebuild::
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t $(SONICDIR)/hw/scripts/generate-mac.tcl)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t $(SONICDIR)/hw/scripts/connectal-synth-phy.tcl)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) $(QUARTUS_SH) -t $(CONNECTALDIR)/scripts/connectal-synth-pll.tcl)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) quartus_sh -t $(CONNECTALDIR)/scripts/connectal-synth-eth.tcl)

LEN=1000

run-sim:
	(cd bluesim; ./bin/ubuntu.exe -n 200 -r 1 -p /home/kslee/sonic/sonic-lite/p4/tests/pcap/udp-large-$(LEN).pcap)

include $(CONNECTALDIR)/Makefile.connectal
