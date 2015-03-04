#!/bin/bash
DEVICE_ID=1be7

busnum=`lspci | grep $DEVICE_ID | awk '{print $1}' | awk -F ":" '{print $1}'`
rootport=`lspci -t | grep "\[04\]" | awk -F"-" '{print $2}' | awk -F"." '{print $1}'`

sudo setpci -v -G -s 00:${rootport}.0 C0.w=2:F
sudo setpci -v -G -s 00:${rootport}.0 A0.b=20:20

#sudo setpci -v -G -s 00:03.0 114.b=80:80
