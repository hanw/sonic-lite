#! /bin/bash

if [ !`lsmod | grep -o dtp` ]; then
    sudo rmmod dtp
fi

if [ !`lsmod | grep -o pcieportal` ]; then
    sudo rmmod pcieportal
fi

sudo insmod /home/kslee/dtp/connectal/drivers/pcieportal/pcieportal.ko

#cp /home/kslee/connectal/drivers/pcieportal/Module.symvers .

#make

sudo insmod ./dtp.ko
