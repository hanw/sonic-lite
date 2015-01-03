PROJ=altera_pcie_sv
DIR=`pwd`/${PROJ}

all:
	qsys-generate --synthesis=VERILOG \
        --simulation=VERILOG \
        --testbench=standard \
        --testbench-simulation=VERILOG \
        --output-directory=${DIR} \
        ${PROJ}.qsys

clean:
	rm -rf ${PROJ}
	rm *.csv *.spd *.sopcinfo
