/* Copyright (c) 2015 Cornell University
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

#include "DtpPktGenRequest.h"
#include "DtpPktGenIndication.h"
#include "GeneratedTypes.h"
#include "lutils.h"
#include "lpcap.h"
#include <cstdlib>
#include <stdio.h>
#include <stdlib.h>
#include <semaphore.h>

using namespace std;

#define DATA_WIDTH 128
#define LINK_SPEED 10

static DtpPktGenRequestProxy *device = 0;

class DtpPktGenTop : public DtpPktGenIndicationWrapper
{
   public:
      virtual void read_version_resp(uint32_t a) {
         fprintf(stderr, "read version %d\n", a);
      }
      virtual void read_pktbuf_debug_resp(uint8_t p, uint64_t a, uint64_t b, uint64_t c, uint64_t d) {
         fprintf(stderr, "Port %d: sop_enq: %ld sop_deq: %ld eop_enq: %ld eop_deq: %ld\n", p, a, b, c, d);
      }
      virtual void read_ring2mac_debug_resp(uint8_t p, uint64_t a, uint64_t b, uint64_t c, uint64_t d, uint64_t e) {
         fprintf(stderr, "Ring2Mac %d: bytes: %ld sop: %ld eop: %ld idles: %ld total: %ld\n", p, a, b, c, d, e);
      }
      virtual void read_mac2ring_debug_resp(uint8_t p, uint64_t a, uint64_t b, uint64_t c, uint64_t d, uint64_t e) {
         fprintf(stderr, "Mac2Ring %d: bytes: %ld sop: %ld eop: %ld idles: %ld total: %ld\n", p, a, b, c, d, e);
      }

      DtpPktGenTop(unsigned int id) : DtpPktGenIndicationWrapper(id) {}
};

uint16_t flowid;
sem_t cmdCompleted;

void device_writePacketData(uint64_t* data, uint8_t* mask, int sop, int eop) {
    device->writePacketData(data, mask, sop, eop);
}

void usage (const char *program_name) {
    printf("%s: pktgen tester\n"
     "usage: %s [OPTIONS] \n",
     program_name, program_name);
    printf("\nOther options:\n"
    " -p, --parser=FILE                demo parsing pcap log\n"
    );
}

struct arg_info {
    double rate;
    int tracelen;
};

static void
parse_options(int argc, char *argv[], char **pcap_file, struct arg_info* info) {
    int c, option_index;

    static struct option long_options [] = {
        {"help",                no_argument, 0, 'h'},
        {"parser",              required_argument, 0, 'p'},
        {"pktgen-rate",         required_argument, 0, 'r'},
        {"pktgen-count",        required_argument, 0, 'n'},
        {0, 0, 0, 0}
    };

    static string short_options
        (long_options_to_short_options(long_options));

    for (;;) {
        c = getopt_long(argc, argv, short_options.c_str(), long_options, &option_index);

        if (c == -1)
            break;

        switch (c) {
            case 'h':
                usage(get_exe_name(argv[0]));
                break;
            case 'p':
                *pcap_file = strdup(optarg);
                break;
            case 'r':
                info->rate = strtod(optarg, NULL);
                break;
            case 'n':
                info->tracelen = strtol(optarg, NULL, 0);
                break;
            default:
                exit(EXIT_FAILURE);
        }
    }
}

/* compute idle character in bytes (round to closest 16) */
int
compute_idle (const struct pcap_trace_info *info, double rate, double link_speed) {

    double idle_count = (link_speed - rate) * info->byte_count / rate;
    int idle = idle_count / info->packet_count;
    int average_packet_len = info->byte_count / info->packet_count;
    fprintf(stderr, "idle = %d, link_speed=%f, rate=%f, average packet len = %d\n", idle, link_speed, rate, average_packet_len);
    return idle;
}

int main(int argc, char **argv)
{
    char *pcap_file=NULL;
    struct arg_info arguments = {1, 200};
    struct pcap_trace_info pcap_info = {0, 0};

    DtpPktGenTop indication (IfcNames_DtpPktGenIndicationH2S);
    device = new DtpPktGenRequestProxy(IfcNames_DtpPktGenRequestS2H);


    parse_options(argc, argv, &pcap_file, &arguments);

    if (pcap_file) {
        fprintf(stderr, "Attempts to read pcap file %s\n", pcap_file);
        load_pcap_file(pcap_file, &pcap_info);
    }

    if (arguments.rate && arguments.tracelen) {
        int idle = compute_idle(&pcap_info, arguments.rate, LINK_SPEED);
        device->start(arguments.tracelen, idle);
        sleep(2);
        //device->stop();

         while(1) {
            int i;
            for ( i = 0 ; i < 3 ; i ++)  {
               device->read_pktbuf_debug(i);
               device->read_ring2mac_debug(i);
               device->read_mac2ring_debug(i);
            }
            sleep(2);
         }
    }

    return 0;
}
