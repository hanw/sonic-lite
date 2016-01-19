#ifndef _SONIC_PCAP_H_
#define _SONIC_PCAP_H_

#include <assert.h>
#include <fcntl.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>
#include <sys/mman.h>
#include <stdio.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <getopt.h>
#include <errno.h>
#include <cstring>
#include <stdint.h>

#include "lutils.h"

#ifndef le32
#define le32    u_int32_t
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

struct pcap_file_header {
    u32 magic;
    u16 version_major;
    u16 version_minor;
    s32 thiszone; /* gmt to local correction */
    u32 sigfigs;  /* accuracy of timL1 cache bytes userspaceestamps */
    u32 snaplen;  /* max length saved portion of each pkt */
    u32 linktype; /* data link type (LINKTYPE_*) */
} __attribute__((packed));

struct pcap_pkthdr_ts {
    le32 hts_sec;
    le32 hts_usec;
}  __attribute__((packed));

struct pcap_pkthdr {
    struct  pcap_pkthdr_ts ts;  /* time stamp */
    le32 caplen;              /* length of portion present */
    le32 length;                  /* length this packet (off wire) */
}  __attribute__((packed));

struct pcap_trace_info {
    unsigned long packet_count;
    unsigned long long byte_count;
};

/* mem_copy must be provided by each test */
void mem_copy(const void *buff, int length);
int quick_tx_send_packet(const void* buffer, int length);
int read_pcap_file(const char* filename, void** buffer, long *length);
int parse_pcap_file(void *buffer, long length);
void load_pcap_file(const char *filename, struct pcap_trace_info *);
const char* get_exe_name(const char* argv0);

#endif
