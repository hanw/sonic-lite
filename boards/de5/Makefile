#
# Programm DE5 User Flash
#

all: program

ifneq (, $(QUARTUS_ROOTDIR))
NIOS2EDS_ROOTDIR=$(QUARTUS_ROOTDIR)/../nios2eds
QUARTUS_PGM_PATH=$(QUARTUS_ROOTDIR)/bin/quartus_pgm
PROJDIR?=../../de5/
endif
ifeq (, $(SERIALNO))
BOARD_USB=-c 1
else
BOARD_USB=-c $(SERIALNO)
endif

program:
	@echo $(QUARTUS_ROOTDIR)
	@echo $(QUARTUS_PGM_PATH)
	# program pfl
	$(QUARTUS_PGM_PATH) -m jtag $(BOARD_USB) -o "p;S5_PFL.sof"

	# convert to .flash
	$(NIOS2EDS_ROOTDIR)/nios2_command_shell.sh sof2flash --input=$(PROJDIR)/mkSonicTop.sof --output=flash_hw.flash --offset=0x20C0000 --pfl --optionbit=0x00030000 --programmingmode=PS

	# programming with .flash
	$(NIOS2EDS_ROOTDIR)/nios2_command_shell.sh nios2-flash-programmer --base=0x0 flash_hw.flash
	$(NIOS2EDS_ROOTDIR)/nios2_command_shell.sh nios2-flash-programmer --base=0x0 S5_OptionBits.flash
