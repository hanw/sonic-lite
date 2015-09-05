
Useful Commands
===============
```
# Build bluesim simulation
make build.bluesim

# Run bluesim simulation
make run.bluesim

# Create BSV from templates (no build)
make p4fpga
```
Install P4
==========
https://github.com/p4lang/p4factory/blob/master/README.md

Required Projects and layout
============================
```
/buildcache
/fpgamake
/connectal
/sonic-lite
/p4/p4factory
/p4/p4c-fpga
```

Example simulation output
=========================
```
$ make run.bluesim
make -C bluesim --no-print-directory run
LD_PRELOAD=libSegFault.so SEGFAULT_USE_ALTSTACK=1 SEGFAULT_OUTPUT_NAME=bin/bsimexe-segv-output.txt ./bin/bsim_exe ; retcode=$?; exit $retcode
buffer /home/hwang/sonic-lite/p4/bluesim/bin/bsim_exe
[initPortalHardware:253] BSIM /home/hwang/sonic-lite/p4/bluesim/bin/bsim *******
init_connecting (socket_for_bluesim) connected.  Attempts 1
Portal::registerInstance fpga0 fd -1 clients 0
portalExec::about to enter loop, numFds=2
[INFO]nBeats=12
[INFO]src_mac=77:22:33:11:ad:ad, dst_mac=11:22:33:44:55:66
[INFO]src_ip=192.168.2.1, dst_ip=192.168.0.1
table add on miss
[INFO]00450008adad1133 2277665544332211 1 0
[INFO]a8c00102a8c055b7 0680000001004f00 0 0
[INFO]0050000000000000 00000d000f000100 0 0
[INFO]6c7961702061206d 27490000deefa67f 0 0
[INFO]6e69646e65732074 736554202164616f 0 0
[INFO]0000002e74656b63 617020656e6f2067 0 1
readPacket     645937: pktLen 0060
inprogress     645939:
enqueue packet data 200450008adad11332277665544332211
inprogress     645941:
enqueue packet data 0a8c00102a8c055b70680000001004f00
parse ethernet
wait for ip
inprogress     645943:
enqueue packet data 0005000000000000000000d000f000100
inprogress     645945:
enqueue packet data 06c7961702061206d27490000deefa67f
Parse Done
inprogress     645947:
enqueue packet data 06e69646e65732074736554202164616f
inprogress     645949:
enqueue packet data 10000002e74656b63617020656e6f2067
eop     645949:
[INFO]00450008adad1133 2277665544332211 1 0
[INFO]a8c00102a8c055b7 0680000001004f00 0 0
[INFO]0050000000000000 00000d000f000100 0 0
[INFO]6c7961702061206d 27490000deefa67f 0 0
[INFO]6e69646e65732074 736554202164616f 0 0
[INFO]0000002e74656b63 617020656e6f2067 0 1
readPacket     675606: pktLen 0060
inprogress     675608:
enqueue packet data 200450008adad11332277665544332211
inprogress     675610:
enqueue packet data 0a8c00102a8c055b70680000001004f00
parse ethernet
wait for ip
inprogress     675612:
enqueue packet data 0005000000000000000000d000f000100
inprogress     675614:
enqueue packet data 06c7961702061206d27490000deefa67f
Parse Done
inprogress     675616:
enqueue packet data 06e69646e65732074736554202164616f
inprogress     675618:
enqueue packet data 10000002e74656b63617020656e6f2067
eop     675618:
```
