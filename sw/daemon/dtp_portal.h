#ifndef __DTP_PORTAL__
#define __DTP_PORTAL__
#include "pcieportal.h"

/* dtp_portal.c */
void dtp_portal_init(tBoard*);

uint32_t dtp_check_indication_queue(int);
uint32_t dtp_read_version(void);
void dtp_reset(const uint32_t );
uint64_t dtp_read_cnt(const uint32_t);
void dtp_set_cnt(const uint32_t, const uint64_t);
uint32_t dtp_read_delay(const uint32_t );
uint32_t dtp_read_state(const uint32_t );
uint64_t dtp_read_error(const uint32_t );
void dtp_send_message(const uint32_t , const uint64_t );
int dtp_read_message(const uint32_t , uint64_t *, uint64_t *, uint64_t *);
uint64_t dtp_read_local_cnt(const uint32_t);
uint64_t dtp_read_global_cnt(void);
void dtp_set_beacon_interval(const uint32_t, const uint32_t);
uint32_t dtp_read_beacon_interval(const uint32_t);
void dtp_check_portal(void);

#endif /* __DTP_PORTAL__ */
