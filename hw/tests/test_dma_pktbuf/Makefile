QUARTUS_SH=$(shell which quartus_sh)
ROOTDIR=$(realpath .)
CONNECTALDIR?=$(ROOTDIR)/../../../../connectal/
IPDIR?=$(ROOTDIR)/../../../../fpgamake-cache/$(shell basename `/bin/pwd`)/
PROJTOP?=$(ROOTDIR)

CONNECTALFLAGS += --bscflags="+RTS -K46777216 -RTS -demote-errors G0066:G0045 -suppress-warnings G0046:G0020:S0015:S0080:S0039 -steps-max-intervals 20"
CONNECTALFLAGS += --bsvpath=$(PROJTOP)/../../../hw/bsv
CONNECTALFLAGS += --bsvpath=$(PROJTOP)/../../../hw/generated
CONNECTALFLAGS += --bsvpath=$(PROJTOP)/../../../p4/examples/tdm/

S2H_INTERFACES=TestRequest:TestTop.request1 DmaRequest:TestTop.request2 
H2S_INTERFACES=TestTop:TestIndication,DmaIndication
BSVFILES=$(PROJTOP)/TestTop.bsv $(PROJTOP)/TestAPI.bsv $(PROJTOP)/../../bsv/DmaEth.bsv
CPPFILES=$(PROJTOP)/testdma.cpp $(PROJTOP)/../../../sw/dmac.cpp 
CONNECTALFLAGS += -I $(PROJTOP)/../../../sw/
CONNECTALFLAGS += -D DataBusWidth=128
CONNECTALFLAGS += -D BYTE_ENABLES
CONNECTALFLAGS += -D NumChannels=1
MEM_READ_INTERFACES = lTestTop.readClient
MEM_WRITE_INTERFACES = lTestTop.writeClient
#PIN_TYPE_INCLUDE=DmaTopPins

ifeq ($(BOARD), vsim)
CONNECTALFLAGS += --verilog $(IPDIR)/$(BOARD)/simulation/mac_10gbe
CONNECTALFLAGS += --verilog $(IPDIR)/$(BOARD)/simulation/altera_xcvr_10gbaser_wrapper
CONNECTALFLAGS += --modelsim $(IPDIR)/$(BOARD)/simulation/altera_xcvr_10gbaser_wrapper/submodules/alt_xcvr_csr_common_h.sv
CONNECTALFLAGS += --modelsim $(IPDIR)/$(BOARD)/simulation/altera_xcvr_10gbaser_wrapper/submodules/altera_xcvr_functions.sv
CONNECTALFLAGS += --modelsim $(IPDIR)/$(BOARD)/simulation/altera_xcvr_10gbaser_wrapper/submodules/alt_xcvr_csr_selector.sv
endif

ifeq ($(BOARD), de5)
AUTOTOP= --interface pins:TestTop.pins
PIN_TYPE=DE5Pins
PIN_TYPE_INCLUDE=DE5Pins
PINOUT_FILE=../../../boards/de5.json
#PIN_BINDINGS?=PCIE:PCIE LED:LED OSC:OSC SFPA:SFPA SFPB:SFPB SFPC:SFPC SFPD:SFPD SFP:SFP I2C:I2C BUTTON:BUTTON
PIN_BINDINGS?=PCIE:PCIE LED:LED OSC:OSC I2C:I2C SFP:SFP BUTTON:BUTTON
CONNECTALFLAGS += --nocache
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/pll_156/altera_pll_156.qip
CONNECTALFLAGS += --xci=$(IPDIR)/$(BOARD)/synthesis/altera_clkctrl/altera_clkctrl.qip
CONNECTALFLAGS += --verilog=$(PROJTOP)/../../../hw/verilog/si570/
CONNECTALFLAGS += --verilog=$(PROJTOP)/../../../hw/verilog/

CONNECTALFLAGS += -D PcieHostIF
#CONNECTALFLAGS += -D DEBUG_ETH
endif

CONNECTALFLAGS += -D DtpVersion=$(shell printf "%d" 0x`git rev-parse --short=8 HEAD`)

ifneq (, $(BLUESIM))
CONNECTALFLAGS += --pinfo=$(PROJTOP)/../../../boards/dtp_synth.json
endif

prebuild::
ifeq ($(BOARD), de5)
ifneq (, $(QUARTUS_SH))
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) $(QUARTUS_SH) -t $(CONNECTALDIR)/scripts/connectal-synth-pll.tcl)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) $(QUARTUS_SH) -t $(PROJTOP)/../../../hw/scripts/connectal-synth-misc.tcl)
	(cd $(BOARD); BUILDCACHE_CACHEDIR=$(BUILDCACHE_CACHEDIR) $(BUILDCACHE) $(QUARTUS_SH) -t $(CONNECTALDIR)/scripts/connectal-synth-eth.tcl)
endif
endif

LEN=1000

run-sim:
	(cd bluesim; ./bin/ubuntu.exe -n 200 -r 1 -p /home/kslee/sonic/sonic-lite/p4/tests/pcap/udp-large-$(LEN).pcap)

include $(CONNECTALDIR)/Makefile.connectal
