#ifndef _SONIC_PCAP_H_
#define _SONIC_PCAP_H_

#include <errno.h>

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

/* mem_copy must be provided by each test */
void mem_copy(const void *buff, int length);

/**
 * Send packet on quick_tx device
 * @param qtx       pointer to a quick_tx structure
 * @param buffer   full packet data starting at the ETH frame
 * @param length  length of packet (must be over 0)
 * @return           length of packet if it was successfully queued, QTX_E_EXIT if a critical error occurred
 *                  and close needs to be called
 */
int quick_tx_send_packet(const void* buffer, int length) {
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

int load_pcap_file(void *buffer, long length) {
    struct pcap_pkthdr* pcap_hdr;
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
    return 0;
}

#endif
