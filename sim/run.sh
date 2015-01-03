#!/bin/bash

QSYS='pcie_de_gen1_x8_ast128.qsys'
PROJ='pcie_de_gen1_x8_ast128'
DIR=`pwd`/$PROJ

echo $DIR

if [ ! -d $DIR ]; then
    mkdir -p $DIR
fi

# generate ip used for synthesis 
#ip-generate --project-directory=$DIR \
#			--output-directory=$DIR/synthesis \
#			--file-set=QUARTUS_SYNTH \
#			--report-file=html:$DIR/$PROJ.html \
#			--report-file=sopcinfo:$DIR/../$PROJ.sopcinfo \
#			--report-file=cmp:$DIR/$PROJ.cmp \
#			--report-file=qip:$DIR/synthesis/$PROJ.qip \
#			--report-file=svd:$DIR/synthesis/$PROJ.svd \
#			--report-file=regmap:$DIR/synthesis/$PROJ.regmap \
#			--report-file=xml:$DIR/$PROJ.xml \
#			--report-file=spd:$DIR/$PROJ.spd \
#			--report-file=sip:$DIR/$PROJ.sip \
#			--system-info=DEVICE_SPEEDGRADE=2_H2 \
#			--language=VERILOG \
#			--component-file=$QSYS
#

## generate ip used for simulation
#qsys-generate --synthesis=VERILOG \
#              --simulation=VERILOG \
#              --testbench=standard \
#              --testbench-simulation=VERILOG \
#              --output-directory=$DIR \
#              $QSYS
#
#ip-generate --project-directory=$DIR \
#			--output-directory=$DIR/synthesis \
#			--file-set=QUARTUS_SYNTH \
#			--report-file=html:$DIR/$PROJ.html \
#			--report-file=sopcinfo:$DIR/../$PROJ.sopcinfo \
#			--report-file=cmp:$DIR/$PROJ.cmp \
#			--report-file=qip:$DIR/synthesis/$PROJ.qip \
#			--report-file=svd:$DIR/synthesis/$PROJ.svd \
#			--report-file=regmap:$DIR/synthesis/$PROJ.regmap \
#			--report-file=xml:$DIR/$PROJ.xml \
#			--report-file=spd:$DIR/$PROJ.spd \
#			--report-file=sip:$DIR/$PROJ.sip \
#			--system-info=DEVICE_SPEEDGRADE=2_H2 \
#			--language=VERILOG \
#			--component-name=$PROJ
#
#PROJ='alt_xcvr_reconfig'
#DIR=`pwd`/$PROJ
#
#echo $DIR
#
#if [ ! -d $DIR ]; then
#    mkdir -p $DIR
#fi
#
#ip-generate --project-directory=$DIR \
#			--output-directory=$DIR/synthesis \
#			--file-set=QUARTUS_SYNTH \
#			--report-file=html:$DIR/$PROJ.html \
#			--report-file=sopcinfo:$DIR/../$PROJ.sopcinfo \
#			--report-file=cmp:$DIR/$PROJ.cmp \
#			--report-file=qip:$DIR/synthesis/$PROJ.qip \
#			--report-file=svd:$DIR/synthesis/$PROJ.svd \
#			--report-file=regmap:$DIR/synthesis/$PROJ.regmap \
#			--report-file=xml:$DIR/$PROJ.xml \
#			--report-file=spd:$DIR/$PROJ.spd \
#			--report-file=sip:$DIR/$PROJ.sip \
#			--system-info=DEVICE_SPEEDGRADE=2_H2 \
#			--language=VERILOG \
#			--component-name=$PROJ
#
PROJ='altpcierd_hip_rs'
DIR=`pwd`/$PROJ

echo $DIR

if [ ! -d $DIR ]; then
    mkdir -p $DIR
fi

ip-generate --project-directory=$DIR \
			--output-directory=$DIR/synthesis \
			--file-set=QUARTUS_SYNTH \
			--report-file=html:$DIR/$PROJ.html \
			--report-file=sopcinfo:$DIR/../$PROJ.sopcinfo \
			--report-file=cmp:$DIR/$PROJ.cmp \
			--report-file=qip:$DIR/synthesis/$PROJ.qip \
			--report-file=svd:$DIR/synthesis/$PROJ.svd \
			--report-file=regmap:$DIR/synthesis/$PROJ.regmap \
			--report-file=xml:$DIR/$PROJ.xml \
			--report-file=spd:$DIR/$PROJ.spd \
			--report-file=sip:$DIR/$PROJ.sip \
			--system-info=DEVICE_SPEEDGRADE=2_H2 \
			--language=VERILOG \
			--component-name=$PROJ
echo $?
