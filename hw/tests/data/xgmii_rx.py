#! /usr/bin/python
import os, sys, argparse

verbose=False

def print_xgmii_encoded(data, control):
    ndata = []
    for i in range(len(data) / 4):
        x = data[i * 4] + (control[i*4] << 8) + (data [i*4+1] << 9) + (control[i*4+1]<<17) + (data[i*4+2] << 18) + (control[i*4+2] << 26) + (data[i*4+3] << 27) + (control[i*4+3] << 35)

        ndata.append(x)

    k = 0
    for i in range(len(ndata) / 2):
        print "{:09x} {:09x}".format(ndata[i*2+1],ndata[i*2])
#        print format(ncontrol[i*2+1], 'x'),
#        print format(ndata[i*2+1], '08x'),
#        print format(ncontrol[i*2], 'x'),
#        print format(ndata[i*2], '08x')

def append_idle(encoded, data, control, n):
    encoded >>= 8

    for i in range(n):
        data.append((encoded >> (i*8)) & 0xff)
        control.append(0)

    data.append(0xfd)
    control.append(1)

    for i in range(7-n):
        data.append(0x07)
        control.append(1)

def pcs_decode(encoded, sync):
    data=[]
    control=[]
    for i in range(len(encoded)):
        if sync[i] == 0x2:      # data
            for j in range(8):
                data.append((encoded[i] >> (j * 8)) & 0xff)
                control.append(0)
            continue

        if encoded[i] == 0x1e:
            for j in range(8):
                data.append(0x07)
                control.append(1)
            continue

        blocktype = encoded[i] & 0xff
        if blocktype == 0x78:
            data.append(0xfb)
            control.append(1)
            for j in range(7):
                data.append((encoded[i]>> ((j+1)*8)) & 0xff)
                control.append(0)
        elif blocktype == 0x33:
            for j in range(4):
                data.append(0x07)
                control.append(1)
            data.append(0xfb)
            control.append(1)

            for j in range(3):
                data.append((encoded[i] >> ((j+5)*8)) & 0xff)
                control.append(0)

        elif blocktype == 0x87:
            append_idle(encoded[i], data, control, 0)
        elif blocktype == 0x99:
            append_idle(encoded[i], data, control, 1)
        elif blocktype == 0xaa:
            append_idle(encoded[i], data, control, 2)
        elif blocktype == 0xb4:
            append_idle(encoded[i], data, control, 3)
        elif blocktype == 0xcc:
            append_idle(encoded[i], data, control, 4)
        elif blocktype == 0xd2:
            append_idle(encoded[i], data, control, 5)
        elif blocktype == 0xe1:
            append_idle(encoded[i], data, control, 6)
        elif blocktype == 0xff:
            append_idle(encoded[i], data, control, 7)

    return data, control



def pcs_decode_file(fname):
    f = open(fname, 'r')

    encoded=[]
    syncheader=[]
    for line in f:
        s = line.split()

        tmp = (int(s[0],16) << 62) + (int(s[1],16) >> 2)
        tmp2 = int(s[1], 16) & 0x3

        encoded.append(tmp)
        syncheader.append(tmp2)

    f.close()

    data,control = pcs_decode(encoded, syncheader)

    print_xgmii_encoded(data, control)

    return data,control


def descramble(data):
    state = 0xffffffffffffffff

    descrambled=[]
    for i in range(len(data)):
        r = ((state >> 6) & 0x3ffffffffffffff) ^ ((state >> 25)& 0x7fffffffff) ^ data[i]
        state = (r ^ (data[i]<<39)^(data[i]<<58)) & 0xffffffffffffffff

        descrambled.append(data[i])

    return descrambled

def descramble_file(fname):
    f = open(fname, 'r')

    scrambled=[]
    syncheader=[]
    descrambled=[]
    for line in f:
        s = line.split()

        tmp = (int(s[0],16) <<62) + (int(s[1],16) >> 2)
        tmp2 = int(s[1],16) & 0x3

        scrambled.append(tmp)
        syncheader.append(tmp2)
        descrambled.append(int(s[2],16))

    f.close()

    data=descramble(scrambled)

    for i in range(len(data)):
        if data[i] != descrambled[i]:
            print "Error"

    return data, syncheader

def main():
    global verbose
    
    parser=argparse.ArgumentParser()
    parser.add_argument('-v', '--verbose', action='store_true', default=False)
    parser.add_argument('-s', '--descramble', type=str, default=None)
    parser.add_argument('-e', '--decode', type=str, default=None)

    args=parser.parse_args()

    if args.verbose:
        verbose=True

    if args.descramble is not None:
        descramble_file(args.descramble)
    if args.decode is not None:
        pcs_decode_file(args.decode)
#    if args.xgmii is not None:
#        xgmii_decode_file(args.xgmii)

if __name__ == "__main__":
    main()

