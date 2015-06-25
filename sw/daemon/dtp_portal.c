#include <linux/types.h>
#include "pcieportal.h"
#include "portal.h"
#include "GeneratedTypes.h"

#include "dtp.h"
#include "dtp_portal.h"

static volatile unsigned int * portal_request_base;
static volatile unsigned int * portal_indication_base;
static volatile unsigned int * portal_indication_status;

#define dtp_map_base(tboard, i)     ((volatile unsigned int *) (tboard->bar2io + i * PORTAL_BASE_OFFSET))
#define dtp_mapchannel(base, index) (&base[PORTAL_FIFO(index)])

#define portal_indication_index     0
#define portal_request_index        1

#define dtp_map_indication(index)   dtp_mapchannel(portal_indication_base, index)
#define dtp_map_request(index)      dtp_mapchannel(portal_request_base, index)
#define dtp_status_indication()     &dtp_map_base(dtp_board, dtp_indication_portal_index)[PORTAL_CTRL_IND_QUEUE_STATUS]

void dtp_portal_init(tBoard *board)
{
    portal_request_base = dtp_map_base(board, portal_request_index);
    portal_indication_base = dtp_map_base(board, portal_indication_index);
    portal_indication_status = &portal_indication_base[PORTAL_CTRL_IND_QUEUE_STATUS];
}

static inline uint32_t dtp_read_portal_32bit(volatile unsigned int * addr) 
{
    uint32_t tmp =0;
    tmp = *addr;
    return tmp;
}

static inline uint64_t dtp_read_portal_64bit(volatile unsigned int *addr)
{
    uint64_t tmp = 0;
    tmp = *addr;
    tmp <<= 32;
    tmp |= *addr;
    return tmp;
}

static inline void dtp_write_portal_32bit(volatile unsigned int *addr, const uint32_t value)
{
    *addr = value;
}

static inline void dtp_write_portal_64bit(volatile unsigned int *addr, const uint64_t value)
{
    *addr = value >> 32;
    *addr = value;
}

// return 1 when not empty, 0 when empty
uint32_t dtp_check_indication_queue(int channel)
{
    volatile unsigned int * dtp_res = dtp_map_indication(channel) ;
    uint32_t tmp;
    dtp_res++;

    tmp = *dtp_res;

    return tmp;
}

uint32_t dtp_read_version(void)
{
    uint32_t tmp;
    volatile unsigned int * dtp_req = dtp_map_request(CHAN_NUM_SonicUserRequest_dtp_read_version);
    volatile unsigned int * dtp_res = dtp_map_indication(CHAN_NUM_SonicUserIndication_dtp_read_version_resp);

    dtp_write_portal_32bit(dtp_req, 0);
    tmp = dtp_read_portal_32bit(dtp_res);

    __DTP_PRINT(1, "version = %d \n", tmp);
    return tmp;
}

void dtp_reset(const uint32_t port)
{
    volatile unsigned int *dtp_req = dtp_map_request(CHAN_NUM_SonicUserRequest_dtp_reset);

    __DTP_PRINT(1, "Reset %d\n", port);

    dtp_write_portal_32bit(dtp_req, port);
}

uint64_t dtp_read_cnt(const uint32_t port)
{
    uint64_t tmp;
    volatile unsigned int *dtp_req = dtp_map_request(CHAN_NUM_SonicUserRequest_dtp_read_cnt);
    volatile unsigned int *dtp_res = dtp_map_indication(CHAN_NUM_SonicUserIndication_dtp_read_cnt_resp);

    dtp_write_portal_32bit(dtp_req, port);
    tmp = dtp_read_portal_64bit(dtp_res);

    __DTP_PRINT(1, "read cnt of port %u = %llx \n", port, tmp);

    return tmp;
}

void dtp_set_cnt(const uint32_t port, const uint64_t c)
{
    volatile unsigned int *dtp_req = dtp_map_request(CHAN_NUM_SonicUserRequest_dtp_set_cnt);

    dtp_write_portal_32bit(dtp_req, port);
    dtp_write_portal_64bit(dtp_req, c);
    __DTP_PRINT(1, "set cnt of port %d = %llx\n", port, c);
}

uint32_t dtp_read_delay(const uint32_t port)
{
    volatile unsigned int *dtp_req = dtp_map_request(CHAN_NUM_SonicUserRequest_dtp_read_delay);
    volatile unsigned int *dtp_res = dtp_map_indication(CHAN_NUM_SonicUserIndication_dtp_read_delay_resp);
    uint32_t p, tmp;

    dtp_write_portal_32bit(dtp_req, port);
    p = dtp_read_portal_32bit(dtp_res);
    tmp = dtp_read_portal_32bit(dtp_res);

    __DTP_PRINT(1, "read delay of port %u %u = %u \n", port, p, tmp);

    return tmp;
}

uint32_t dtp_read_state(const uint32_t port)
{
    volatile unsigned int *dtp_req = dtp_map_request(CHAN_NUM_SonicUserRequest_dtp_read_state);
    volatile unsigned int *dtp_res = dtp_map_indication(CHAN_NUM_SonicUserIndication_dtp_read_state_resp);
    uint32_t p, tmp;

    dtp_write_portal_32bit(dtp_req, port);
    p = dtp_read_portal_32bit(dtp_res);
    tmp = dtp_read_portal_32bit(dtp_res);

    __DTP_PRINT(1, "read state of port %u %u= %u \n", port, p, tmp);

    return tmp;
}

uint64_t dtp_read_error(const uint32_t port)
{
    volatile unsigned int *dtp_req = dtp_map_request(CHAN_NUM_SonicUserRequest_dtp_read_error);
    volatile unsigned int *dtp_res = dtp_map_indication(CHAN_NUM_SonicUserIndication_dtp_read_error_resp);
    uint32_t p;
    uint64_t tmp;

    dtp_write_portal_32bit(dtp_req, port);
    p = dtp_read_portal_32bit(dtp_res);
    tmp = dtp_read_portal_64bit(dtp_res);

    __DTP_PRINT(1, "read error of port %u %u = %llu \n", port, p, tmp);

    return tmp;
}

void dtp_send_message(const uint32_t port, const uint64_t message)
{
    volatile unsigned int *dtp_req = dtp_map_request(CHAN_NUM_SonicUserRequest_dtp_logger_write_cnt);

    dtp_write_portal_32bit(dtp_req, port);
    dtp_write_portal_64bit(dtp_req, message);

    __DTP_PRINT(1, "send message %llu to %u\n", message, port);
}

int dtp_read_message(const uint32_t port, uint64_t *ts, uint64_t *msg1, uint64_t *msg2)
{
    volatile unsigned int *dtp_req = dtp_map_request(CHAN_NUM_SonicUserRequest_dtp_logger_read_cnt);
    volatile unsigned int *dtp_res = dtp_map_indication(CHAN_NUM_SonicUserIndication_dtp_logger_read_cnt_resp);
    uint32_t p;
    uint64_t tmp;

    // check queue
    dtp_write_portal_32bit(dtp_req, port);

    // check queue
    if (!dtp_check_indication_queue(CHAN_NUM_SonicUserIndication_dtp_logger_read_cnt_resp)) {
        __DTP_PRINT(1, "There is no message %d\n", port);
        return -1;
    }

    p = dtp_read_portal_32bit(dtp_res);
    tmp = dtp_read_portal_64bit(dtp_res);
    *ts = tmp;
    tmp = dtp_read_portal_64bit(dtp_res);
    *msg1 = tmp;
    tmp = dtp_read_portal_64bit(dtp_res);
    *msg2 = tmp;

    __DTP_PRINT(1, "received message at port %d: %llu %llu %llu\n", p, *ts, *msg1, *msg2);

    return 0;
}

uint64_t dtp_read_local_cnt(const uint32_t port)
{
    volatile unsigned int *dtp_req = dtp_map_request(CHAN_NUM_SonicUserRequest_dtp_read_local_cnt);
    volatile unsigned int *dtp_res = dtp_map_indication(CHAN_NUM_SonicUserIndication_dtp_read_local_cnt_resp);
    uint32_t p;
    uint64_t tmp;

    dtp_write_portal_32bit(dtp_req, port);
    p = dtp_read_portal_32bit(dtp_res);
    tmp = dtp_read_portal_64bit(dtp_res);

    __DTP_PRINT(1, "read local cnt %d: %llu\n", p, tmp);

    return tmp;
}

uint64_t dtp_read_global_cnt(void)
{
    volatile unsigned int *dtp_req = dtp_map_request(CHAN_NUM_SonicUserRequest_dtp_read_global_cnt);
    volatile unsigned int *dtp_res = dtp_map_indication(CHAN_NUM_SonicUserIndication_dtp_read_global_cnt_resp);
    uint64_t tmp;

    dtp_write_portal_32bit(dtp_req, 0);
    tmp = dtp_read_portal_64bit(dtp_res);

    __DTP_PRINT(1, "read global cnt %llu\n", tmp);

    return tmp;
}

void dtp_set_beacon_interval(const uint32_t port, const uint32_t interval)
{
    volatile unsigned int *dtp_req = dtp_map_request(CHAN_NUM_SonicUserRequest_dtp_set_beacon_interval);

    dtp_write_portal_32bit(dtp_req, port);
    dtp_write_portal_32bit(dtp_req, interval);

    __DTP_PRINT(1, "set beacon interval of port %d to %d\n", port, interval);
}

uint32_t dtp_read_beacon_interval(const uint32_t port)
{
    volatile unsigned int *dtp_req = dtp_map_request(CHAN_NUM_SonicUserRequest_dtp_read_beacon_interval);
    volatile unsigned int *dtp_res = dtp_map_indication(CHAN_NUM_SonicUserIndication_dtp_read_beacon_interval_resp);
    uint32_t p, tmp;

    dtp_write_portal_32bit(dtp_req, port);
    p = dtp_read_portal_32bit(dtp_res);
    tmp = dtp_read_portal_32bit(dtp_res);

    __DTP_PRINT(1, "read beacon interval %d: %d\n", p, tmp);

    return tmp;
}

void dtp_check_portal(void)
{
    //volatile unsigned int *statp = &portal_base_indication[PORTAL_CTRL_IND_QUEUE_STATUS];
    //volatile unsigned int *statp = dtp_status_indication();
    uint32_t queue_status;

    if (dtp_verbose < 2)
        return;

    queue_status = dtp_read_portal_32bit(portal_indication_status);
    __DTP_PRINT(2, "queue_status = %d\n", queue_status);
    queue_status = dtp_check_indication_queue(CHAN_NUM_SonicUserIndication_dtp_read_version_resp);
    __DTP_PRINT(2, "read_version status = %d\n", queue_status);
    queue_status = dtp_check_indication_queue(CHAN_NUM_SonicUserIndication_dtp_read_delay_resp);
    __DTP_PRINT(2, "read_delay status = %d\n", queue_status);
    queue_status = dtp_check_indication_queue(CHAN_NUM_SonicUserIndication_dtp_read_state_resp);
    __DTP_PRINT(2, "read_state status = %d\n", queue_status);
    queue_status = dtp_check_indication_queue(CHAN_NUM_SonicUserIndication_dtp_read_error_resp);
    __DTP_PRINT(2, "read_error status = %d\n", queue_status);
    queue_status = dtp_check_indication_queue(CHAN_NUM_SonicUserIndication_dtp_read_cnt_resp);
    __DTP_PRINT(2, "read_cnt status = %d\n", queue_status);
    queue_status = dtp_check_indication_queue(CHAN_NUM_SonicUserIndication_dtp_logger_read_cnt_resp);
    __DTP_PRINT(2, "read_message status = %d\n", queue_status);
    queue_status = dtp_check_indication_queue(CHAN_NUM_SonicUserIndication_dtp_read_local_cnt_resp);
    __DTP_PRINT(2, "read_local_cnt status = %d\n", queue_status);
    queue_status = dtp_check_indication_queue(CHAN_NUM_SonicUserIndication_dtp_read_global_cnt_resp);
    __DTP_PRINT(2, "read_global_cnt status = %d\n", queue_status);
    queue_status = dtp_check_indication_queue(CHAN_NUM_SonicUserIndication_dtp_read_beacon_interval_resp);
    __DTP_PRINT(2, "read_beacon_interval status = %d\n", queue_status);

    // FIXME check request queue   
    #if 0
    while((queue_status = dtp_read_portal_32bit(statp))) {
        break;
        addr = dtp_map_indication(queue_status -1);

        switch(queue_status-1) {
        case CHAN_NUM_SonicUserIndication_dtp_read_version_resp:
            tmp32 = dtp_read_portal_32bit(addr);
            break;
        case CHAN_NUM_SonicUserIndication_dtp_read_delay_resp:
        case CHAN_NUM_SonicUserIndication_dtp_read_state_resp:
            tmp32 = dtp_read_portal_32bit(addr);
            tmp32 = dtp_read_portal_32bit(addr);
            break;
        case CHAN_NUM_SonicUserIndication_dtp_read_error_resp:
            tmp32 = dtp_read_portal_32bit(addr);
        case CHAN_NUM_SonicUserIndication_dtp_read_cnt_resp:
            tmp64 = dtp_read_portal_64bit(addr);
        break;
        case CHAN_NUM_SonicUserIndication_dtp_logger_read_cnt_resp:
            tmp32 = dtp_read_portal_32bit(addr);
            tmp64 = dtp_read_portal_64bit(addr);
            tmp64 = dtp_read_portal_64bit(addr);
            tmp64 = dtp_read_portal_64bit(addr);
        break;
        default:
            printk("Not possible\n");
        }
    }
    #endif
}
