#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <stdint.h>

#include "SchedulerTopIndication.h"
#include "SchedulerTopRequest.h"
#include "GeneratedTypes.h"

#define DEBUG_SCHEDULER 1
//#define DEBUG 1

static SchedulerTopRequestProxy *device = 0;

class SchedulerTopIndication : public SchedulerTopIndicationWrapper
{
public:
#ifdef DEBUG
    virtual void test_func_resp() {
        printf("SUCCESS\n");
    }
#endif

#ifdef DEBUG_SCHEDULER
    virtual void set_start_time_result(uint8_t op_outcome) {
        if (op_outcome == 1) {
            fprintf(stderr, "Start time successfully set\n");
        } else {
            fprintf(stderr, "Error while trying to set the start time. Stop the scheduler if it is currently running.\n");
        }
    }

        virtual void get_start_time_result(uint64_t start_time, uint8_t op_outcome) {
            if (op_outcome == 1) {
                fprintf(stderr, "start time = %lu\n", start_time);
            } else {
                fprintf(stderr, "Error while trying to get the start time\n");
            }
        }

        virtual void set_interval_result(uint8_t op_outcome) {
            if (op_outcome == 1) {
                fprintf(stderr, "Slot interval successfully set\n");
            } else {
                fprintf(stderr, "Error while trying to set the slot interval. Stop the scheduler if it is currently running.\n");
            }
        }

        virtual void get_interval_result(uint64_t interval, uint8_t op_outcome) {
            if (op_outcome == 1) {
                fprintf(stderr, "slot interval = %lu\n", interval);
            } else {
                fprintf(stderr, "Error while trying to get the slot interval\n");
            }
        }

        virtual void insert_result(uint8_t op_outcome) {
            if (op_outcome == 1) {
                fprintf(stderr, "Insert successful\n");
            } else {
                fprintf(stderr, "Error while trying to insert into the table. Stop the scheduler if it is currently running.\n");
            }
        }

        virtual void display_result(uint32_t server_ip, uint64_t server_mac, uint8_t op_outcome) {
            if (op_outcome == 1) {
                fprintf(stderr, "IP = %u  MAC = %lu\n", server_ip, server_mac);
            }
        }
#endif

    SchedulerTopIndication(unsigned int id) : SchedulerTopIndicationWrapper(id) {}
};

#ifdef DEBUG_SCHEDULER
void test_scheduler(SchedulerTopRequestProxy* device) {
    device->set_start_time(2000);
    device->get_start_time();
}
#endif

int main(int argc, char **argv)
{
    SchedulerTopIndication echoIndication(IfcNames_SchedulerTopIndicationH2S);
    device = new SchedulerTopRequestProxy(IfcNames_SchedulerTopRequestS2H);

#ifdef DEBUG
    device->test_func();
#endif

#ifdef DEBUG_SCHEDULER
    test_scheduler(device);
#endif
    while(1);
    return 0;
}
