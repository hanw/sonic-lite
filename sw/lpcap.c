#include "lpcap.h"

void device_writePacketData(uint64_t* data, uint8_t* mask, int sop, int eop);

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

int read_pcap_file(const char* filename, void** buffer, long *length) {
    FILE *infile;
    long length_read;

    infile = fopen(filename, "r");
    if(infile == NULL) {
        printf("File does not exist!\n");
        exit(-1);
    }

    fseek(infile, 0L, SEEK_END);
    *length = ftell(infile);
    fseek(infile, 0L, SEEK_SET);
    *buffer = (char*)calloc(*length, sizeof(char));

    /* memory error */
    if(*buffer == NULL) {
        printf("Could not allocate %ld bytes of memory!\n", *length);
        exit(-1);
    }

    length_read = fread(*buffer, sizeof(char), *length, infile);
    *length = length_read;
    fclose(infile);

    return 0;
}

int parse_pcap_file(void *buffer, long length, struct pcap_trace_info *info) {
    struct pcap_pkthdr* pcap_hdr;
    unsigned long packet_count = 0;
    unsigned long long byte_count = 0;
    void* offset = static_cast<char *>(buffer) + sizeof(struct pcap_file_header);
    while(offset < static_cast<char *>(buffer) + length) {
        pcap_hdr = (struct pcap_pkthdr*) offset;
        offset = static_cast<char *>(offset) + sizeof(struct pcap_pkthdr);
        if ((quick_tx_send_packet((const void*)offset, pcap_hdr->caplen)) < 0) {
            printf("An error occurred while trying to send a packet\n");
            exit(-1);
        }
        offset = static_cast<char *>(offset) + pcap_hdr->caplen;
        packet_count ++;
        byte_count += pcap_hdr->caplen;
    }

    info->packet_count = packet_count;
    info->byte_count = byte_count;
    return 0;
}

void load_pcap_file(const char *filename, struct pcap_trace_info *info) {
    long length=0;
    void *buffer=NULL;
    read_pcap_file(filename, &buffer, &length);
    parse_pcap_file(buffer, length, info);
}

const char* get_exe_name(const char* argv0) {
    if (const char *last_slash = strrchr(argv0, '/')) {
        return last_slash + 1;
    }
    return argv0;
}

void mem_copy(const void *buff, int packet_size) {

    int i, sop, eop;
    uint64_t data[2];
    uint8_t mask[2];
    int numBeats;

    numBeats = packet_size / 8; // 16 bytes per beat for 128-bit datawidth;
    if (packet_size % 8) numBeats++;
    PRINT_INFO("nBeats=%d, packetSize=%d\n", numBeats, packet_size);
    for (i=0; i<numBeats; i++) {
        data[i%2] = *(static_cast<const uint64_t *>(buff) + i);
        if (packet_size > 8) {
            mask[i%2] = 0xff;
            packet_size -= 8; // 64-bit
        } else {
            mask[i%2] = ((1 << packet_size) - 1) & 0xff;
            packet_size = 0;
        }
        sop = (i/2 == 0);
        eop = (i/2 == (numBeats-1)/2);
        if (i%2) {
            device_writePacketData(data, mask, sop, eop);
            PRINT_INFO("%016lx %016lx %0x %0x %d %d\n", data[1], data[0], mask[1], mask[0], sop, eop);
        }

        // last beat, padding with zero
        if ((numBeats%2!=0) && (i==numBeats-1)) {
            sop = (i/2 == 0) ? 1 : 0;
            eop = 1;
            data[1] = 0;
            mask[1] = 0;
            device_writePacketData(data, mask, sop, eop);
            PRINT_INFO("%016lx %016lx %0x %0x %d %d\n", data[1], data[0], mask[1], mask[0], sop, eop);
        }
    }
}

/* from NOX */
std::string long_options_to_short_options(const struct option* options)
{
    std::string short_options;
    for (; options->name; options++) {
        const struct option* o = options;
        if (o->flag == NULL && o->val > 0 && o->val <= UCHAR_MAX) {
            short_options.push_back(o->val);
            if (o->has_arg == required_argument) {
                short_options.push_back(':');
            } else if (o->has_arg == optional_argument) {
                short_options.append("::");
            }
        }
    }
    return short_options;
}


