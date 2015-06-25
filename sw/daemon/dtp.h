#ifndef __DTP_DAEMON
#define __DTP_DAEMON

#include "pcieportal.h"
#ifndef __KERNEL__
#include <stdint.h>
#endif /* __KERNEL__*/

#define __DTP_PRINT(level, msg, args...)                      \
    do {                                                        \
        if (level <= dtp_verbose)                               \
            printk(KERN_INFO "DTP: [%s] " msg, __func__, ##args); \
    } while (0)

#define DTP_ERROR(msg, args...)                               \
    do {                                                        \
        printk(KERN_ERR "DTP: [%s] " msg, __func__, ##args);  \
    } while (0)

#define DTP_PRINT(...) __DTP_PRINT(0, __VA_ARGS__)

#define DTP_PORT_NUM        4

#ifdef __KERNEL__
extern tBoard *dtp_board;
#endif
extern int dtp_verbose;

struct dtp_log {
    int port;
    uint64_t timestamp;
    uint64_t msg1;
    uint64_t msg2;
};

struct dtp_cnt {
    uint64_t tsc1;
    uint64_t tsc2;
    uint64_t low;
    uint64_t high;
};

struct dtp_time {
    uint32_t flag;
    uint32_t reserved;

    // dtp global counter
    float rate;
    struct dtp_cnt dtp_cnt[DTP_PORT_NUM+1];

    // TODO
    int log_cnt;
    int log_max;
    struct dtp_log log[0];
};

struct dtp_state {
    uint32_t msg_cnt;
    uint32_t state; // 0: INIT, 1: SENT: 2: SYNC
    uint32_t delay;
    uint32_t beacon_interval;
    uint64_t error;
    uint64_t local_cnt;
    uint64_t free_cnt;
};

//typedef tBoard;

struct dtp_priv {
    int mode;
    int polling_interval;

    int logging [DTP_PORT_NUM];
    int sending [DTP_PORT_NUM];
    int counter [DTP_PORT_NUM+1];

    uint64_t global_cnt;
    struct dtp_state states[DTP_PORT_NUM];

#ifdef __KERNEL__
    tBoard *board;
#endif
};

enum {INIT, SENT, SYNC};

#endif /* __DTP_DAEMON */
