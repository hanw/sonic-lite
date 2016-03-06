QUARTUS_SH=$(shell which quartus_sh)
ROOTDIR=$(realpath .)
CONNECTALDIR?=$(ROOTDIR)/../../../../connectal/
IPDIR?=$(ROOTDIR)/../../../../fpgamake-cache/$(shell basename `/bin/pwd`)/
PROJTOP?=$(ROOTDIR)

CONNECTALFLAGS += --bscflags="+RTS -K46777216 -RTS -demote-errors G0066:G0045 -suppress-warnings G0046:G0020:S0015:S0080:S0039 -steps-max-intervals 20"
CONNECTALFLAGS += --bsvpath=$(PROJTOP)/../../../hw/bsv
CONNECTALFLAGS += --bsvpath=$(PROJTOP)/../../../hw/generated
CONNECTALFLAGS += --bsvpath=$(PROJTOP)/../../../p4/examples/tdm/

S2H_INTERFACES=DtpPktGenRequest:DtpPktGenTop.request2
H2S_INTERFACES=DtpPktGenTop:DtpPktGenIndication
BSVFILES=$(PROJTOP)/DtpPktGenTop.bsv $(PROJTOP)/DtpPktGenAPI.bsv 
CPPFILES=$(PROJTOP)/pktgen.cpp
CPPFILES += $(PROJTOP)/../../../sw/lpcap.c
CONNECTALFLAGS += -I $(PROJTOP)/../../../sw/ 

CONNECTALFLAGS += -D DataBusWidth=128
CONNECTALFLAGS += -D BYTE_ENABLES

ifeq ($(BOARD), vsim)
CONNECTALFLAGS += --verilog $(IPDIR)/$(BOARD)/simulation/mac_10gbe
CONNECTALFLAGS += --verilog $(IPDIR)/$(BOARD)/simulation/altera_xcvr_10gbaser_wrapper
CONNECTALFLAGS += --modelsim $(IPDIR)/$(BOARD)/simulation/altera_xcvr_10gbaser_wrapper/submodules/alt_xcvr_csr_common_h.sv
CONNECTALFLAGS += --modelsim $(IPDIR)/$(BOARD)/simulation/altera_xcvr_10gbaser_wrapper/submodules/altera_xcvr_functions.sv
CONNECTALFLAGS += --modelsim $(IPDIR)/$(BOARD)/simulation/altera_xcvr_10gbaser_wrapper/submodules/alt_xcvr_csr_selector.sv
endif

CONNECTALFLAGS += -D DtpVersion=$(shell printf "%d" 0x`git rev-parse --short=8 HEAD`)

ifneq (, $(BLUESIM))
CONNECTALFLAGS += --pinfo=$(PROJTOP)/../../../boards/dtp_synth.json
endif

LEN=1000

run-sim:
	(cd bluesim; ./bin/ubuntu.exe -n 200 -r 1 -p /home/kslee/sonic/sonic-lite/p4/tests/pcap/udp-large-$(LEN).pcap)

include $(CONNECTALDIR)/Makefile.connectal
