import Verilog_VCD as vcd
import argparse
import pprint
import re
import natsort
import array
import bitstring

argparser = argparse.ArgumentParser("Parse VCD file")
argparser.add_argument("vcdfile", help='VCD file to parse')
argparser.add_argument('-s', '--signal', default=[], help='Name of the signal to extract')
argparser.add_argument('-l', '--listsigs', help='List all available signals', action='store_true')

options=argparser.parse_args()
pp = pprint.PrettyPrinter(indent=4)

if options.listsigs:
    signals = vcd.list_sigs(options.vcdfile)
    pp.pprint(signals)
    exit(1)

if options.signal:
    sig_list=[]
    signals = vcd.list_sigs(options.vcdfile)
    pattern = "[a-z0-9._]+"+options.signal+"\[[0-9]+\]"
    for signal in signals:
        v = re.search(pattern, signal)
        if v is not None:
            sig_list.append(v.group())
            sig_list=natsort.natsorted(sig_list, reverse=True)

    print sig_list
    if sig_list is not None:
        vcd=vcd.parse_vcd(options.vcdfile, siglist=sig_list, opt_timescale='ns')

        signal_out = {}
        signal_length = int(round(float(len(vcd.values()))/4)*4)
        for vcd_raw in vcd.values():
            #pp.pprint(vcd_raw)
            signal_name = vcd_raw['nets'][0]['name']
            index = signal_name.split('[')[1].strip(']')
            for tv in vcd_raw['tv']:
                time = tv[0]
                if (tv[1] != 'X'):
                    if (time not in signal_out):
                        signal_out[time] = bitstring.BitArray(length=signal_length)
                    #print signal_name, "%d"%time, index, tv[1]
                    signal_out[time].overwrite("bin:1=%s"%tv[1], signal_length-int(index)-1)

        for key in sorted(signal_out.keys()):
            arr = signal_out[key]
            print "%d"%key, arr.hex

