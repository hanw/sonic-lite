#ifndef __DTP_DAEMON
#define __DTP_DAEMON

#ifndef __KERNEL__
#include <stdint.h>
#endif /* __KERNEL__*/

#define __DTP_PRINT(level, msg, args...)                      \
    do {                                                        \
        printk(KERN_INFO "DTP: [%s] " msg, __func__, ##args); \
    } while (0)

#define DTP_ERROR(msg, args...)                               \
    do {                                                        \
        printk(KERN_ERR "DTP: [%s] " msg, __func__, ##args);  \
    } while (0)

#define DTP_PRINT(...) __DTP_PRINT(0, __VA_ARGS__)

struct dtp_time {
    int flag;

    uint64_t high;
    uint64_t low;

    uint64_t tsc1;
    uint64_t tsc2;

    float rate;
    // TODO

};


#endif
