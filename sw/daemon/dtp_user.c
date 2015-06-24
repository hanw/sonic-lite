#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <sched.h>
#include <string.h>
#include <fcntl.h>
#include <errno.h>
#include <stdint.h>
#include <inttypes.h>
#include <sys/types.h>
#include <sys/mman.h>
#include <unistd.h>
#include <syscall.h>
#include <time.h>

#include "dtp.h"

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

FILE * dtp_file_open(char * fname)
{
    if (fname) {
        time_t t = time(NULL);
        struct tm tm= * localtime(&t);
        char * dtp_fname = calloc(1,17 + strlen(fname));
        snprintf(dtp_fname, 17 + strlen(fname), "%s_%d%02d%02d_%02d%02d%02d", fname, 
                tm.tm_year + 1900,tm.tm_mon+1,tm.tm_mday,tm.tm_hour,tm.tm_min,tm.tm_sec);
        printf("Start writing %s\n", dtp_fname);

        return fopen(dtp_fname, "w");
    }
    else
        return stdout;
}

void dtp_file_close(FILE *f)
{
    if (f != stdout)
        fclose(f);
}

void __loop (int interval, int cpu, char *fname, char *address)
{

    FILE *fout = NULL;

    struct dtp_time *dtp_time = (struct dtp_time *) address;
    //unsigned long long tsc1, ptsc=0, tsc2;
    //unsigned long long dtp;
    unsigned long long ptsc=0;
    int log_max = (getpagesize() - sizeof(struct dtp_time)) / sizeof(struct dtp_log);
    struct dtp_log *log = calloc(log_max, sizeof(struct dtp_log));

    int msleep = interval / 3;
    int count=0, log_cnt = 0, i, j;
    volatile unsigned int * flag = &dtp_time->flag;
    struct dtp_cnt cnt[DTP_PORT_NUM+1];

//  for ( i =0 ; i < 10 ; i ++) {
    while(1) {

        while(*flag == 1) 
            ;

        for ( j = 0 ; j < DTP_PORT_NUM+1 ; j ++) {
            cnt[j].tsc1 = dtp_time->dtp_cnt[j].tsc1;
            cnt[j].tsc2 = dtp_time->dtp_cnt[j].tsc2;
            cnt[j].low = dtp_time->dtp_cnt[j].low;
        }

        for ( i = 0 ; i < dtp_time->log_cnt ; i++) {
            log[i].port = dtp_time->log[i].port;
            log[i].timestamp = dtp_time->log[i].timestamp;
            log[i].msg1 = dtp_time->log[i].msg1;
            log[i].msg2 = dtp_time->log[i].msg2;
        }

        log_cnt = dtp_time->log_cnt;

        if (*flag == 1)
            continue;

        if (cnt[0].tsc1 != ptsc) {  // FIXME
            if (count == 0) {
                fout = dtp_file_open(fname);
            }

            count ++;
            ptsc = cnt[0].tsc1;
            for ( j = 0 ; j < DTP_PORT_NUM+1; j ++) {
                fprintf(fout, "%d %.16"PRIx64" %.16"PRIx64" %.16"PRIx64"\n", j, cnt[j].tsc1, cnt[j].tsc2, cnt[j].low);
    //            printf("%.16llx %.16llx %.16llx\n", tsc1, tsc2, dtp);
            }

            for ( i = 0 ; i < log_cnt ; i ++ ) {
                fprintf(fout, "   %d %.16"PRIx64" %.16"PRIx64" %.16"PRIx64"\n",
                        log[i].port, log[i].timestamp,
                        log[i].msg1, log[i].msg2);
            }

            if (count == 60 * 60 * 24) {
            //if (count == 10) {
                fclose(fout);
                count = 0;
            }

        }

        if (msleep >= 1000000)
            sleep(msleep / 1000000);
        else
            usleep(msleep);
    }

}

int main(int argc, char **argv)
{
    if (argc < 3) {
        fprintf(stderr, "usage: %s <interval us> <cpu>\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    int interval=atoi(argv[1]); // in microsecond
    int cpu = atoi(argv[2]);
    char *fname = NULL;
    if (argc == 4) 
        fname = argv[3];

    dtp_set_cpu(cpu);

    int fd;
    fd = open ("/dev/dtpd", O_RDONLY);
    if (fd < 0) {
        fprintf(stderr, "%s\n", strerror(errno));
        return -1;
    }

    char *address = NULL;
    address = mmap(NULL, getpagesize(), PROT_READ, MAP_SHARED, fd, 0);
    if (address == MAP_FAILED) {
        fprintf(stderr, "%s\n", strerror(errno));
        return -1;
    }

    __loop(interval, cpu, fname, address);

    munmap(address, getpagesize());

    close(fd);

    return 0;

}
