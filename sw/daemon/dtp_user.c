#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <sched.h>
#include <string.h>
#include <fcntl.h>
#include <errno.h>
#include <stdint.h>
#include <sys/types.h>
#include <sys/mman.h>
#include <unistd.h>
#include <syscall.h>

#include "dtp.h"

#define PAGE_SIZE 4096

int dtp_get_cpu()
{
    int i;
    pid_t tid;
    cpu_set_t cpu_set;
    CPU_ZERO(&cpu_set);

    tid = syscall(SYS_gettid);

    if (sched_getaffinity(tid, sizeof(cpu_set), &cpu_set) < 0) {
        fprintf(stderr, "get_cpu error\n");
        exit(EXIT_FAILURE);
    }

    for ( i = 0 ; i < CPU_SETSIZE ; i ++ ) {
        if (CPU_ISSET(i, &cpu_set)) {
            fprintf(stderr, "CPU running on %d\n", i);
            break;
        }
    }

    return i;
}

int dtp_set_cpu(int cpun)
{
    pid_t tid;
    cpu_set_t cpu_set;
    CPU_ZERO(&cpu_set);
    CPU_SET(cpun, &cpu_set);

    tid = syscall(SYS_gettid);
    if (sched_setaffinity(tid, sizeof(cpu_set), &cpu_set) < 0) {
        fprintf(stderr, "set_cpu error\n");
        exit(EXIT_FAILURE);
    }

return 0;
}

int main(int argc, char **argv)
{
    if (argc != 4) {
        fprintf(stderr, "usage: %s <fname> <interval> <cpu>\n", argv[0]);
        exit(EXIT_FAILURE);
    }


    const char * fname = argv[1];
    int interval=atoi(argv[2]); // in microsecond
    int cpu = atoi(argv[3]);

    dtp_set_cpu(cpu);

    int fd;
    fd = open ("/dev/dtpd", O_RDONLY);
    if (fd < 0) {
        fprintf(stderr, "%s\n", strerror(errno));
        return -1;
    }

    char *address = NULL;
    address = mmap(NULL, PAGE_SIZE, PROT_READ, MAP_SHARED, fd, 0);
    if (address == MAP_FAILED) {
        fprintf(stderr, "%s\n", strerror(errno));
        return -1;
    }

    FILE *fout = fopen(fname, "a");

    const struct dtp_time *dtp_time = (struct dtp_time *) address;

    unsigned long long tsc1, ptsc=0, tsc2;
    unsigned long long dtp, pdtp;

    int msleep = interval / 3;
    int i;

//  for ( i =0 ; i < 10 ; i ++) {
    while(1) {
        do {
            tsc1 = dtp_time->tsc1;
            tsc2 = dtp_time->tsc2;
            dtp = dtp_time->low;
        } while (dtp_time->flag == 1);

        if (tsc1 != ptsc) {
            ptsc = tsc1;
            pdtp = dtp;
            fprintf(fout, "%.16llx %.16llx %.16llx\n", tsc1, tsc2, dtp);
//            printf("%.16llx %.16llx %.16llx\n", tsc1, tsc2, dtp);
        }

        if (msleep >= 1000000)
            sleep(msleep / 1000000);
        else
            usleep(msleep);
    }

    munmap(address, PAGE_SIZE);

    return 0;

}
