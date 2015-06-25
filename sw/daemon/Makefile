dtp := dtp
SRC := kernel.c dtp_portal.c
CONNECTAL_PATH=/home/kslee/dtp/connectal
SONIC_PATH=/home/kslee/dtp/sonic-lite
EXTRA_CFLAGS := -O3 -I$(CONNECTAL_PATH)/drivers/pcieportal -I$(CONNECTAL_PATH)/cpp/ -I$(SONIC_PATH)/de5/jni

ifneq ($(KERNELRELEASE),)
# in Kernel
$(dtp)-objs := $(SRC:.c=.o)
obj-m := $(dtp).o

else
KVER := $(shell uname -r)
KDIR := /lib/modules/$(KVER)/build
KSRC := /lib/modules/$(KVER)/source
PWD := $(shell pwd)

all: default dtp_user cpu

default:
	$(MAKE) -C $(KDIR) SUBDIRS=$(PWD) modules

clean: 
	$(MAKE) -C $(KDIR) SUBDIRS=$(PWD) clean
	rm -f dtp_user *.tar.gz *.dev

endif

CC = gcc -Wall

dtp_user: dtp_user.c 
	$(CC) -o $@ $(CFLAGS) $(LDFLAGS) $(EXTRA_CFLAGS) $^ 

cpu: cpu.c$
