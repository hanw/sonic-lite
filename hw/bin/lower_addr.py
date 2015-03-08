#!/bin/python
import sys

def getLowerAddr(addr, be):
    req_addr = int(addr, 16)
    req_be = int(be, 16)
    mask=0x7F
    lowerAddr = (req_addr & mask)
    print "%x"%lowerAddr
    if (req_be == 0xE):
        print 'e'
        lowerAddr |= 0x1
    elif (req_be == 0xC):
        print 'c'
        lowerAddr |= 0x2
    elif (req_be == 0x8):
        print '8'
        lowerAddr |= 0x3
    else:
        pass

    print "Lower Addr %02x"% lowerAddr

getLowerAddr(sys.argv[1], sys.argv[2])
