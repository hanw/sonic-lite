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

#include <assert.h>
#include <fcntl.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>
#include <stdio.h>
#include <sys/mman.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <getopt.h>
#include <pcap.h>

#include "MemServerIndication.h"
#include "P4TopIndication.h"
#include "P4TopRequest.h"
#include "GeneratedTypes.h"
#include "utils.h"

#ifndef le32
#define le32    int32_t
#endif

#ifndef u32
#define u32     u_int32_t
#endif

#ifndef u16
#define u16     u_int16_t
#endif

#ifndef s32
#define s32     int32_t
#endif

#define DATA_WIDTH 128

//struct pcap_file_header {
//    u32 magic;
//    u16 version_major;
//    u16 version_minor;
//    s32 thiszone; /* gmt to local correction */
//    u32 sigfigs;  /* accuracy of timL1 cache bytes userspaceestamps */
//    u32 snaplen;  /* max length saved portion of each pkt */
//    u32 linktype; /* data link type (LINKTYPE_*) */
//} __attribute__((packed));
//
//struct pcap_pkthdr_ts {
//    le32 hts_sec;
//    le32 hts_usec;
//}  __attribute__((packed));
//
//struct pcap_pkthdr {
//    struct  pcap_pkthdr_ts ts;  /* time stamp */
//    le32 caplen;              /* length of portion present */
//    le32 length;                  /* length this packet (off wire) */
//}  __attribute__((packed));
//
void mem_copy(const void *buff, int length);

static P4TopRequestProxy *device = 0;

class P4TopIndication : public P4TopIndicationWrapper
{
public:
    virtual void sonic_read_version_resp(uint32_t a) {
        fprintf(stderr, "version %d\n", a);
    }
    virtual void cam_search_result(uint64_t a) {
        fprintf(stderr, "cam search %lx\n", a);
    }
    virtual void read_setram_result(uint64_t a) {
        fprintf(stderr, "setram %lx\n", a);
    }
    virtual void match_table_resp(uint32_t a) {
    	fprintf(stderr, "match table");
    }
    virtual void matchTableResponse(uint64_t key, uint32_t value) {
        fprintf(stderr, "GET : key = %lu  value = %u\n", key, value);
    }

    P4TopIndication(unsigned int id) : P4TopIndicationWrapper(id) {}
};

class MemServerIndication : public MemServerIndicationWrapper
{
public:
    virtual void error(uint32_t code, uint32_t sglId, uint64_t offset, uint64_t extra) {
        fprintf(stderr, "memServer Indication.error=%d\n", code);
    }

    virtual void addrResponse ( const uint64_t physAddr ) {
        fprintf(stderr, "phyaddr=%lx\n", physAddr);
    }
    virtual void reportStateDbg ( const DmaDbgRec rec ) {
        fprintf(stderr, "rec\n");
    }
    virtual void reportMemoryTraffic ( const uint64_t words ) {
        fprintf(stderr, "words %lx\n", words);
    }
    MemServerIndication(unsigned int id) : MemServerIndicationWrapper(id) {}
};

void mem_copy(const void *buff, int packet_size) {

    int i, sop, eop;
    uint64_t data[2];
    int numBeats;

    numBeats = packet_size / 8; // 16 bytes per beat for 128-bit datawidth;
    if (packet_size % 8) numBeats++;
    PRINT_INFO("nBeats=%d, packetSize=%d\n", numBeats, packet_size);
    for (i=0; i<numBeats; i++) {
        data[i%2] = *(static_cast<const uint64_t *>(buff) + i);
        sop = (i/2 == 0);
        eop = (i/2 == (numBeats-1)/2);
        if (i%2) {
            device->writePacketData(data, sop, eop);
            PRINT_INFO("%016lx %016lx %d %d\n", data[1], data[0], sop, eop);
        }

        // last beat, padding with zero
        if ((numBeats%2!=0) && (i==numBeats-1)) {
            sop = (i/2 == 0) ? 1 : 0;
            eop = 1;
            data[1] = 0;
            device->writePacketData(data, sop, eop);
            PRINT_INFO("%016lx %016lx %d %d\n", data[1], data[0], sop, eop);
        }
    }
}

/**
 * Send packet on quick_tx device
 * @param qtx       pointer to a quick_tx structure
 * @param buffer   full packet data starting at the ETH frame
 * @param length  length of packet (must be over 0)
 * @return           length of packet if it was successfully queued, QTX_E_EXIT if a critical error occurred
 *                  and close needs to be called
 */
static inline int quick_tx_send_packet(const void* buffer, int length) {
    assert(buffer);
    assert(length > 0);

#ifdef EXTRA_DEBUG
    printf("[quick_tx] Copying data from %p buffer, length = %d\n",
                (buffer, length);
#endif
    mem_copy(buffer, length);

    return length;
}

bool read_pcap_file(const char* filename, void** buffer, long *length) {
    FILE *infile;
    long length_read;

    infile = fopen(filename, "r");
    if(infile == NULL) {
            printf("File does not exist!\n");
            return false;
        }

    fseek(infile, 0L, SEEK_END);
    *length = ftell(infile);
    fseek(infile, 0L, SEEK_SET);
    *buffer = (char*)calloc(*length, sizeof(char));

    /* memory error */
    if(*buffer == NULL) {
            printf("Could not allocate %ld bytes of memory!\n", *length);
            return false;
        }

    length_read = fread(*buffer, sizeof(char), *length, infile);
    *length = length_read;
    fclose(infile);

    return true;
}

void test_setram(P4TopRequestProxy *device) {
    device->writeSetRam(0x11, 0xff);
    device->readSetRam(0x11);
}

void test_bcam(P4TopRequestProxy *device) {
    fprintf(stderr, "Insert CAM\n");
    device->camInsert(0x0, 0x0);
    device->camInsert(0x1, 0x1);
    device->camInsert(0x2, 0x2);
    device->camInsert(0x3, 0x3);
    device->camSearch(0x0);
    device->camSearch(0x1);
    device->camSearch(0x2);
    device->camSearch(0x3);
    //device->camInsert(0x303, 0x24);
}

void test_mtable(P4TopRequestProxy *device) {
    device->matchTableRequest(10, 15, 1); //PUT(10,15)
    device->matchTableRequest(10, 0, 0);  //GET(10) should print k=10 v=15
/*    device->matchTableRequest(10, 20, 2); //UPDATE(10,20)
    device->matchTableRequest(29, 0, 3);  //REMOVE(29)
    device->matchTableRequest(10, 0, 0);  //GET(10) should print k=10 v=20
    device->matchTableRequest(10, 0, 3);  //REMOVE(10)
    device->matchTableRequest(10, 0, 0);  //GET(10) should not print anything
    device->matchTableRequest(10, 30, 2); //UPDATE(10,30) should not update
    device->matchTableRequest(10, 0, 0);  //GET(10) should not print anything
    device->matchTableRequest(10, 45, 1); //PUT(10,45)
    device->matchTableRequest(10, 0, 0);  //GET(10) should print k=10 v=45
    
    device->matchTableRequest(20, 15, 1); //PUT(20,15)
    device->matchTableRequest(20, 0, 3);  //REMOVE(20)
    device->matchTableRequest(20, 0, 0);  //GET(20) should not print anyting
    
    device->matchTableRequest(20, 15, 1); //PUT(20,15)
    device->matchTableRequest(20, 0, 3);  //REMOVE(20)
    device->matchTableRequest(20, 60, 1); //PUT(20,15)
    device->matchTableRequest(20, 0, 0);  //GET(20) should print k=20 v=60
*/
}

const char* get_exe_name(const char* argv0) {
    if (const char *last_slash = strrchr(argv0, '/')) {
        return last_slash + 1;
    }
    return argv0;
}

void usage (const char *program_name) {
    printf("%s: p4fpga tester\n"
     "usage: %s [OPTIONS] \n",
     program_name, program_name);
    printf("\nOther options:\n"
    " -b, --shared-buffer-demo              demo shared buffer\n"
    " -p, --parser-demo=FILE                demo parsing pcap log\n"
    " -m, --match-table-demo=FILE           demo match table\n"
    " -f, --full-pipeline-demo=FILE         demo full pipeline\n");
}

int main(int argc, char **argv)
{
    const char *program_name = get_exe_name(argv[0]);
    const char *pcap_file="";
    void *buffer;
    long length;
    struct pcap_pkthdr* pcap_hdr;
    int c, option_index;

    bool run_basic = true;
    bool load_pcap = false;
    bool shared_buff_test = false;
    bool parser_test = false;
    bool match_table_test = false;
    bool full_test = false;

    for (;;) {
        static struct option long_option [] = {
            {"shared-buffer-test",  no_argument, 0, 'b'},
            {"help",                no_argument, 0, 'h'},
            {"parser-test",         required_argument, 0, 'p'},
            {"match-table-test",    required_argument, 0, 'm'},
            {"full-test",           required_argument, 0, 'f'},
            {0, 0, 0, 0}
        };
        c = getopt_long(argc, argv, "bhpmf", long_option, &option_index);

        if (c == -1)
            break;

        switch (c) {
            case 'b':
                shared_buff_test = true;
                break;
            case 'h':
                usage(program_name);
                run_basic = false;
                break;
            case 'p':
                load_pcap = true;
                parser_test = true;
                pcap_file = optarg;
                break;
            case 'm':
                load_pcap = true;
                match_table_test = true;
                pcap_file = optarg;
                break;
            case 'f':
                load_pcap = true;
                full_test = true;
                pcap_file = optarg;
                break;
            default:
                run_basic = false;
                break;
        }
    }

    if (run_basic) {
        P4TopIndication echoIndication(IfcNames_P4TopIndicationH2S);
        MemServerIndication memServerIndication(IfcNames_MemServerIndicationH2S);
        device = new P4TopRequestProxy(IfcNames_P4TopRequestS2H);

        device->sonic_read_version();
    }

    if (load_pcap) {
        fprintf(stderr, "Attempts to read pcap file %s\n", argv[1]);
        if (!read_pcap_file(pcap_file, &buffer, &length)) {
            perror("Failed to read file!");
            exit(-1);
        }

        void* offset = static_cast<char *>(buffer) + sizeof(struct pcap_file_header);
        while(offset < static_cast<char *>(buffer) + length) {
            pcap_hdr = (struct pcap_pkthdr*) offset;
            offset = static_cast<char *>(offset) + sizeof(struct pcap_pkthdr);
            if ((quick_tx_send_packet((const void*)offset, pcap_hdr->caplen)) < 0) {
                printf("An error occurred while trying to send a packet\n");
                exit(-1);
            }
            offset = static_cast<char *>(offset) + pcap_hdr->caplen;
        }
    }

    if (shared_buff_test) {
        device->writePacketBuffer(0, 0xFACEBABE);
        device->readPacketBuffer(0);
    }

    if (parser_test) {
        
    }

    if (match_table_test) {
    
    }

    if (full_test) {
    
    }

    if (run_basic) {
        sleep(1);
        printf("done!");
    }
    return 0;
}
