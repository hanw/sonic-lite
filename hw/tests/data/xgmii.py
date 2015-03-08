#! /usr/bin/python
import os, sys, argparse

verbose=False

def generate_packet(l):
    pkt=[]
    pkt.append(0x55)
    pkt.append(0x55)
    pkt.append(0x55)
    pkt.append(0x55)
    pkt.append(0x55)
    pkt.append(0x55)
    pkt.append(0xd5)

    for j in range(l):
        pkt.append(j)
    
    if verbose:
        k=0
        for i in range(len(pkt)):
            print format(pkt[i], '02x'),
            k+=1
            if k == 16:
                print
                k = 0

    print

    return pkt

def xgmii_encode(n, pkt, idle):
    encoded_data=[]
    encoded_control=[]
    beginning = idle

    for x in range(n):
        for i in range(beginning):
            encoded_data.append(0x70)
            encoded_control.append(1)

        if beginning % 4 != 0:
            for i in range(4 - beginning % 4):
                encoded_data.append(0x70)
                encoded_control.append(1)

        # /S/
        encoded_data.append(0x5f)
        encoded_control.append(1)

        # /D/
        for i in range(len(pkt)):
            encoded_data.append(pkt[i])
            encoded_control.append(0)

        # /T/
        encoded_data.append(0x3f)
        encoded_control.append(1)

        if (len(pkt) + 2) % 4 != 0:
            for i in range(4 - (len(pkt)+2)%4):
                encoded_data.append(0x70)
                encoded_control.append(1)

        beginning = idle - (5 - (len(pkt)+2) % 4)

    if len(encoded_data) % 8 != 0 :
        for i in range(8 - len(encoded_data) % 8):
            encoded_data.append(0x70)
            encoded_control.append(1)

    if verbose:
        k=0
        for i in range(len(encoded_data)):
            print format(encoded_data[i], '02x'),
            print encoded_control[i],
            k+=1
            if k == 16:
                print
                k = 0

        print

    return encoded_data, encoded_control

def print_xgmii_encoded(data, control, fname):

    f= open(fname+'.xgmii','w')
    ndata = []
    for i in range(len(data) / 4):
        x = data[i * 4] + (control[i*4] << 8) + (data [i*4+1] << 9) + (control[i*4+1]<<17) + (data[i*4+2] << 18) + (control[i*4+2] << 26) + (data[i*4+3] << 27) + (control[i*4+3] << 35)

        ndata.append(x)

    k = 0
    for i in range(len(ndata) / 2):
        f.write("{:09x} {:09x}\n".format(ndata[i*2+1],ndata[i*2]))
#        print format(ncontrol[i*2+1], 'x'),
#        print format(ndata[i*2+1], '08x'),
#        print format(ncontrol[i*2], 'x'),
#        print format(ndata[i*2], '08x')

    f.close()

def pcs_encode(data, control):
    ndata = []
    nsync = []
    for i in range(len(data) / 8):
        start = False
        end = False
        db=0
        idle = 0
        index = 0
        sync = 0
        # convert /S/ /T/ /I/
        for j in range(8):
            if control[i*8 + j] == 0:
                db += 1
                continue

            # /I/
            if data[i*8+j] == 0x07:
                idle += 1
                data[i*8+j] = 0
            # /S/
            elif data[i*8+j] == 0xfb:
                start = True
                index = j
                data[i*8+j] = 0
            # /T/
            elif data[i*8+j] == 0xfd:
                end=True
                index = j
                data[i*8+j] = 0


        c = control[i*8] + (control [i*8+1]<<1) + (control[i*8+2]<<2) + (control[i*8+3]<<3) \
            + (control[i*8+4]<<4) + (control [i*8+5]<<5) + (control[i*8+6]<<6) + (control[i*8+7]<<7) 

        d = data[i * 8] + (data [i*8+1] << 8) + (data[i*8+2] << 16) + (data[i*8+3]<<24) + \
             (data[i*8+4]<<32) + (data[i*8+5]<<40) + (data[i*8+6]<<48) + (data[i*8+7]<<56)

        sync=0x1
        if db == 8:
            sync=0x2
            pass
        elif idle == 8:
            d = 0x1e
        elif start:
            if index == 0:
                d += 0x78
            elif index == 4:
                d += 0x33
        elif end:
            d << 8
            if index == 0:
                d+= 0x87
            elif index == 1:
                d+= 0x99
            elif index == 2:
                d+= 0xaa
            elif index == 3:
                d+= 0xb4
            elif index == 4:
                d+= 0xcc
            elif index == 5:
                d+= 0xd2
            elif index == 6:
                d+= 0xe1
            else:
                d+= 0xff

        ndata.append(d)
        nsync.append(sync)

    if verbose:
        for i in range(len(ndata)):
            first = data[i * 8] + (data [i*8+1] << 8) + (data[i*8+2] << 16) + (data[i*8+3] << 24)
            second = data[i * 8+4] + (data [i*8+5] << 8) + (data[i*8+6] << 16) + (data[i*8+7] << 24)
            print "{:08x} {:08x} {:016x}".format(second, first, ndata[i] )

    return ndata, nsync

def print_pcs_encoded(data, sync, fname):
    f = open(fname+'.encoded', 'w')

    for i in range(len(data)):
        low = ((data[i] << 2) & 0xffffffffffffffff) ^ sync[i]
        high = (data[i] >> 62) & 0xf
        f.write("{:x} {:016x} {:016x}\n".format(high, low, data[i]))

    f.close()

def scramble(data):
    state = 0xffffffffffffffff
    #state = 0x0
    scrambled=[]
    for i in range(len(data)):
        r = ((state >> 6) & 0x3ffffffffffffff) ^ ((state >> 25)& 0x7fffffffff) ^ data[i]
        state = (r ^ (r<<39)^(r<<58)) & 0xffffffffffffffff

        scrambled.append(state)

    if verbose:
        for i in range(len(scrambled)):
            print "{:016x} {:016x}".format(data[i], scrambled[i])

    return scrambled

def print_scrambled(data, sync, fname):
    f = open(fname+'.scrambled', 'w')

    for i in range(len(data)):
        low = (data[i] << 2 & 0xffffffffffffffff) ^ sync[i]
        high = (data[i] >> 62) & 0xf
        f.write("{:x} {:016x} {:016x}\n".format(high, low, data[i]))

    f.close()

def xgmii_strings(n, l, idle, fname):
    pkt = generate_packet(l)

    xdata, xcontrol = xgmii_encode(n, pkt, idle)

    print_xgmii_encoded(xdata, xcontrol, fname)

    encoded, sync = pcs_encode(xdata, xcontrol)

    print_pcs_encoded(encoded, sync, fname)

    scrambled = scramble(encoded)

    print_scrambled(scrambled, sync, fname)

def print_all(fname, xgmii, encoded, scrambled):
    f = open(fname+'.all', 'w')

    for i in range(len(encoded)):
        f.write("{:09x} {:09x} {:016x} {:016x}\n".format(xgmii[i*2+1], xgmii[i*2], encoded[i], scrambled[i]))

    f.close()


def xgmii_file(fname):
    f = open(fname, 'r')

    data=[]
    control=[]
    xgmii=[]
    for l in f:
        tmp=l.split()
        first = tmp[1]
        second = tmp[0]
        xgmii.append(int(first, 16))
        xgmii.append(int(second, 16))

    f.close()

    for x in xgmii:
        for i in range(4):
            tmp = (x >> (i*9)) & 0x1ff
            d = tmp & 0xff
            c = (tmp >> 8) & 0x1

            data.append(d)
            control.append(c)

    encoded, sync = pcs_encode(data, control)

    scrambled = scramble(encoded)

    print_pcs_encoded(encoded, sync, fname)
    print_scrambled(scrambled, sync, fname)
    print_all(fname, xgmii, encoded, scrambled)

def main():
    global verbose
    
    parser=argparse.ArgumentParser()
    parser.add_argument('-v', '--verbose', action='store_true', default=False)
    parser.add_argument('-f', '--filename', type=str, default='tmp')
    parser.add_argument('-n', '--pkt_cnts', type=int, default=1)
    parser.add_argument('-i', '--idle', type=int, default=12)
    parser.add_argument('-l', '--pkt_length', type=int, default=1000)
    parser.add_argument('-x', '--xgmii', type=str, default=None)

    args=parser.parse_args()

    if args.verbose:
        verbose=True

    if args.xgmii is not None:
        xgmii_file(args.xgmii);
    else:
        xgmii_strings(args.pkt_cnts, args.pkt_length, args.idle, args.filename);

if __name__ == "__main__":
    main()

