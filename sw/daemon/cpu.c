#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <syscall.h>
#include <stdint.h>
#include <time.h>
#include <unistd.h>
#include <sys/types.h>
#include <sched.h>

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

    if (argc != 3) {
        fprintf(stderr, "usage: %s <cpu> <memory>\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    int i, j;
    int cpu = atoi(argv[1]);
    srand(time(NULL));
    
    uint64_t memory = atoi(argv[2]);         // given in MB

    memory = memory * 1024 * 1024 / 4;
    int * x = calloc(sizeof(int) , memory);

    dtp_set_cpu(cpu);
    dtp_get_cpu();

    while(1) {
//        int addr = rand() % G;
//        x[i] = rand();
        for ( i = 0 ; i < memory ; i ++ ) {
                if (i != 0)
                    x[i ] = rand();
                else
                    x[i] = rand() * x[i-1];
        }
    }

    return 0;
}
