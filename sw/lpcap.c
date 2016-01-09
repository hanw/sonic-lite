#include "lpcap.h"

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

const char* get_exe_name(const char* argv0) {
    if (const char *last_slash = strrchr(argv0, '/')) {
        return last_slash + 1;
    }
    return argv0;
}


