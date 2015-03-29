dtp := dtp
dtp_mod := dtp_mod

EXTRA_CFLAGS = -O3 -I${HOME}/connectal/drivers/pcieportal -I${HOME}/connectal/cpp/

ifneq ($(KERNELRELEASE),)
# in Kernel
obj-m := $(dtp).o
$(dtp_mod)-objs := dtp_daemon.o 

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
	rm -f dtp_user *.tar.gz *.dev cpu

endif

CC = gcc -Wall

dtp_user: dtp_user.c 
	$(CC) -o $@ $(CFLAGS) $(LDFLAGS) $(EXTRA_CFLAGS) $^ 

cpu: cpu.c$
