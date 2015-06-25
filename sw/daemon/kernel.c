/*
 * dtp daemon (Linux kernel module)
 *
 * Copyright (C) 2015 Ki Suh Lee <kslee@cs.cornell.edu>
 */

#include <linux/module.h>
#include <linux/cdev.h>
#include <linux/types.h>
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/moduleparam.h>
#include <linux/version.h>
#include <linux/inet.h>
#include <linux/mm.h>
#include <linux/udp.h>
#include <linux/fs.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <asm/uaccess.h>
#include <net/ip.h>
#include <net/tcp.h>
#include <linux/sched.h>
#include <linux/clocksource.h>
#include <linux/kthread.h>
#include <asm/msr.h>
#include <asm/i387.h>

#include "pcieportal.h"
#include "portal.h"
#include "GeneratedTypes.h"

#include "dtp.h"
#include "dtp_portal.h"
#define DEV_NAME "dtpd"

MODULE_AUTHOR("Ki Suh Lee");
MODULE_DESCRIPTION("DTP daemon");
MODULE_LICENSE("Dual BSD/GPL");

struct task_struct *dtp_daemon;
struct dtp_time *dtp_time;
static struct class * dtp_class = NULL;
static struct cdev dtp_cdev;
static dev_t dtp_dev;
static struct proc_dir_entry *dtp_proc;
static int ref_count=0;
static int cpun = 3;
int dtp_verbose=0;

// Modes: 0 (nothing) 1 (running) 
static int mode=1;      // running
module_param(mode, int, 0000);
static int logging[DTP_PORT_NUM] = {0};
module_param_array(logging, int, NULL, 0000);
static int sending[DTP_PORT_NUM] = {0};
module_param_array(sending, int, NULL, 0000);
static int counter[DTP_PORT_NUM+1] = {0}; // counter of interest
module_param_array(counter, int, NULL, 0000);

struct dtp_priv *dtp;

/* pcieportal */
tBoard *dtp_board;

void __test(void)
{
    int i, j;

    for ( i = 0 ; i < 4 ; i ++ ) {
        dtp_reset(i);
    }
//    dtp_drain_portal();

    for ( i = 0 ; i < 10 ; i ++ ) {
        dtp_read_version();
    
            
        for ( j = 0; j < 4 ; j ++ ) {
            dtp_read_cnt(j);

            dtp_read_delay(j);

            dtp_read_state(j);

            dtp_read_error(j);
        }

        __set_current_state(TASK_UNINTERRUPTIBLE);
        schedule_timeout(HZ * 1); // 1s
    }
}

static inline void dtp_insert_log(struct dtp_time *dtp_time, struct dtp_log *log)
{
    struct dtp_log *target;

    if (dtp_time->log_cnt >= dtp_time->log_max)
        return;

    target = &dtp_time->log[dtp_time->log_cnt];
    target->port = log->port;
    target->timestamp = log->timestamp;
    target->msg1 = log->msg1;
    target->msg2 = log->msg2;

    dtp_time->log_cnt++;
}

static inline void dtp_read_cnt_tsc(int port)
{
    cycle_t ret, ret2;
    uint64_t dtp=0;

    // read first tsc
    rdtsc_barrier();
    ret = (cycle_t)__native_read_tsc();

    /* read dtp counter */
    if (port == DTP_PORT_NUM)
        dtp = dtp_read_global_cnt();
    else if(port >= 0)
        dtp = dtp_read_local_cnt(port);  // FIXME: global counter or local counter

#if 0
    *dtp_req = 1;
    dtp = *dtp_res;
    dtp2 = *dtp_res;
#endif

    // read second tsc
    rdtsc_barrier();
    ret2 = (cycle_t)__native_read_tsc();

    dtp_time->dtp_cnt[port].tsc1 = ret;
    dtp_time->dtp_cnt[port].tsc2 = ret2;
    dtp_time->dtp_cnt[port].low = dtp;

//    dtp_time->tsc1 = ret;
//    dtp_time->tsc2 = ret2;
//    dtp_time->low = dtp;

    __DTP_PRINT(1,"%d %.16llx %.16llx %.16llx \n", port, ret, ret2, dtp);
}

static void dtp_send_log(void)
{
    int i;
    for ( i = 0 ; i < DTP_PORT_NUM ; i ++ ) {
        if (dtp->sending[i] && dtp->states[i].state == SYNC) {
            dtp_send_message(i, dtp->states[i].msg_cnt);
            dtp->states[i].msg_cnt++;
        }
    }
}

static void dtp_recv_log(void)
{
    int i;
    struct dtp_log log;
    for ( i = 0 ; i < DTP_PORT_NUM ; i ++ ) {
        if (dtp->logging[i] && dtp->states[i].state == SYNC) {
            log.port = i;
            
            // until log queue is empty
            while(!dtp_read_message(i, &log.timestamp, &log.msg1, &log.msg2)) {
                dtp_insert_log(dtp_time, &log); 
            }
        }
    }
}

static void dtp_update_configs(void)
{
    int i;
    if (mode != dtp->mode) {
        DTP_PRINT("Mode change detected %d -> %d\n", dtp->mode, mode);
        dtp->mode = mode;
    }

    for ( i = 0 ; i < DTP_PORT_NUM ; i ++) {
        dtp->logging[i] = logging [i];
        dtp->sending[i] = sending [i];
        dtp->counter[i] = counter [i];
    }
}

static void dtp_update_states(void)
{
    uint64_t tmp;
    int i;
    for ( i = 0 ; i < DTP_PORT_NUM ; i ++) {
        tmp = dtp_read_state(i);
        dtp->states[i].state = tmp;
        tmp = dtp_read_delay(i);
        dtp->states[i].delay = tmp;
        tmp = dtp_read_error(i);
        dtp->states[i].error = tmp;
        tmp = dtp_read_beacon_interval(i);
        dtp->states[i].beacon_interval = tmp;
        tmp = dtp_read_local_cnt(i);
        dtp->states[i].local_cnt = tmp;
        tmp = dtp_read_cnt(i);
        dtp->states[i].free_cnt = tmp;
    }
    tmp =dtp_read_global_cnt();
    dtp->global_cnt = tmp;
}

static int run_dtp_daemon(void * args) 
{
    unsigned long flags;
    int i;
    set_cpus_allowed (current, cpumask_of_cpu(cpun));

    while(1) {
        if (!dtp->mode)
            goto loop_end;

        kernel_fpu_begin(); // this disables preemption
        raw_local_irq_save(flags);

        // set flag to one: locking the structure
        dtp_time->flag = 1;
        dtp_time->log_cnt = 0;

        for ( i = 0 ; i <DTP_PORT_NUM +1 ; i ++) {
            if (dtp->counter[i])
                dtp_read_cnt_tsc(i);
        }

        dtp_send_log();

        dtp_recv_log();

        // set flag to zero: unlocking the structure
        dtp_time->flag = 0;

        // update parameters
        dtp_update_configs();

        // update states
        dtp_update_states();

        dtp_check_portal();

        raw_local_irq_restore(flags);
        kernel_fpu_end();   // this enables preempt

loop_end:
        __set_current_state(TASK_UNINTERRUPTIBLE);
        schedule_timeout(HZ * 1); // 1s

        if (kthread_should_stop())
            break;
    }

    return 0;
}

static int dtp_fs_open(struct inode *inode, struct file *file)
{
    ref_count += 1;
    return 0;
}

static int dtp_fs_release(struct inode *inode, struct file *file)
{
    ref_count -= 1;
    return 0;
}

static int dtp_fs_mmap(struct file *file, struct vm_area_struct *vma)
{
    DTP_PRINT("before remap\n");
    if (remap_pfn_range(vma, vma->vm_start, __pa(dtp_time) >> PAGE_SHIFT, vma->vm_end - vma->vm_start, vma->vm_page_prot))
        return -EAGAIN;
    vma->vm_flags |= VM_IO;

    DTP_PRINT("after remap\n");

    return 0;
}

static struct file_operations dtp_fops = {
    .open = dtp_fs_open,
    .release = dtp_fs_release,
    .owner = THIS_MODULE,
    .mmap = dtp_fs_mmap
};

static inline int __dtp_atoi(char *p)
{
    unsigned int tmp=0;
    int ret;
    if (*p == '\0')  {
        DTP_ERROR("Input error\n");
        return -1;
    }
    
    ret = sscanf(p, "%u", &tmp);
    if (ret <= 0 )  {
        DTP_ERROR("sscanf fails %d\n", ret);
        return -1;
    }

    return tmp;
}

// from userspace to kernel
static ssize_t dtp_proc_write(struct file *filp, const char __user *buff, 
        size_t count, loff_t *pos)
{
    char buf[32];
    int tmp;

    if (count > sizeof(buf)) {
        DTP_ERROR("message is too long\n");
        return -EFAULT;
    }

    if(copy_from_user(buf, buff, count))
        return -EFAULT;
    buf[count] = '\0';

    if (!strncmp(buf, "reset=", 6)) {
        if ((tmp = __dtp_atoi(buf + strlen("reset=")))< 0)
            return -EFAULT;
#if 0
        if (tmp > 4) {
            DTP_ERROR("Unknown port number %d\n", tmp);
            return -EFAULT;
        }
#endif
        dtp_reset(tmp);
#if 0
    } else if (!strncmp(buf, "mode=", 5)) {
        if ((tmp = __dtp_atoi(buf + strlen("mode=")))< 0)
            return -EFAULT;
        
        if (tmp > 3) {
            DTP_ERROR("Unknown mode %d\n", tmp);
            return -EFAULT;
        }
        dtp_change_mode(tmp);
#endif
    } else if (!strncmp(buf, "beacon=", 7)) {
        if((tmp = __dtp_atoi(buf + strlen("beacon=")))<0)
            return -EFAULT;
        DTP_PRINT("Beacon interval = %d\n", tmp);
        //TODO
    } else if (!strncmp(buf, "polling=", 8)) {
        if((tmp = __dtp_atoi(buf + strlen("polling=")))<0)
            return -EFAULT;
        DTP_PRINT("Polling interval = %d\n", tmp);
        //TODO
    } else if (!strncmp(buf, "logging=", 8)) {
        if ((tmp = __dtp_atoi(buf + strlen("logging=")))<0)
            return -EFAULT;
        DTP_PRINT("Logging enable/disable port %d\n", tmp);
        if (tmp >= DTP_PORT_NUM) {
            DTP_ERROR("Unknown port %d\n", tmp);
            return -EFAULT;
        }
        logging[tmp] = logging[tmp] ? 0 : 1;
    } else if (!strncmp(buf, "sending=", 8)) {
        if ((tmp = __dtp_atoi(buf + strlen("sending=")))<0)
            return -EFAULT;
        DTP_PRINT("Sending enable/disable port %d\n", tmp);
        if (tmp >= DTP_PORT_NUM) {
            DTP_ERROR("Unknown port %d\n", tmp);
            return -EFAULT;
        }
        sending[tmp] = sending[tmp] ? 0 : 1;
    } else if (!strncmp(buf, "counter=", 8)) {
        if ((tmp = __dtp_atoi(buf + strlen("counter=")))<0)
            return -EFAULT;
        DTP_PRINT("Counter port %d\n", tmp);
        if (tmp > DTP_PORT_NUM) {
            DTP_ERROR("Unknown port %d\n", tmp);
            return -EFAULT;
        }
        counter[tmp] = counter[tmp] ? 0 : 1;
    } else if (!strncmp(buf, "verbose=", 8)) {
        if ((tmp = __dtp_atoi(buf + strlen("sending=")))<0)
            return -EFAULT;
        DTP_PRINT("Setting verbose level to %d\n", tmp);
        dtp_verbose = tmp;
    } else if (!strncmp(buf, "stop", 4)) {
        DTP_PRINT("Stop\n");
        mode = 0;
    } else if (!strncmp(buf, "start", 5)) {
        DTP_PRINT("Start\n");
        mode = 1;
    } else {
        DTP_ERROR("Unknown Command %s %lu\n", buf, count);
        return -EFAULT;
    }

    return count;
}

static void * dtp_seq_proc_start (struct seq_file *s, loff_t *pos)
{
    return *pos == 0  ? pos : NULL;
}

static void * dtp_seq_proc_next (struct seq_file *s, void *v, loff_t *pos)
{
    *pos = (*pos) + 1;
    return *pos < 5 ? pos : NULL;
}

static void dtp_seq_proc_stop (struct seq_file *s, void *v)
{
}

static int dtp_seq_proc_show (struct seq_file *s, void *v)
{
    int *idx = (int *) v;
    if (*idx == 0) {
        seq_printf(s, "DTP mode = %d, Global counter = %.16llx\n", 
                dtp->mode, dtp->global_cnt);
    } else {
        struct dtp_state *state = &dtp->states[(*idx) - 1];
        seq_printf(s, "Port %d : logging = %d, sending = %d counter = %d\n"
                "state = %u, delay = %u, beacon_interval = %u\n"
                "Local counter = %016llx, Free counter = %016llx\n"
                "Error = %016llx\n",
                (*idx)- 1, dtp->logging[(*idx) - 1], dtp->sending[(*idx) -1],
                dtp->counter[(*idx) - 1], 
                state->state, state->delay, state->beacon_interval,
                state->local_cnt, state->free_cnt, state->error);
    }

    return 0;
}

static struct seq_operations dtp_seq_proc_ops = {
    .start = dtp_seq_proc_start,
    .next = dtp_seq_proc_next,
    .stop = dtp_seq_proc_stop,
    .show = dtp_seq_proc_show
};

static int dtp_proc_open(struct inode *inode, struct file *file)
{
    return seq_open(file, &dtp_seq_proc_ops);
}

static struct file_operations dtp_proc_fops = {
    .open  = dtp_proc_open,
    .read = seq_read,
    .llseek = seq_lseek,
    .write = dtp_proc_write,
    .release = seq_release
};

static int __init dtp_init(void)
{
    int status = 0, i;

    DTP_PRINT("dtp_init\n"); 

    dtp = kzalloc(sizeof(struct dtp_priv), GFP_KERNEL);
    if (!dtp) {
        DTP_ERROR("Memory error\n");
        return -ENOMEM;
    }

    // parameters
    dtp->mode = mode;
    for (i = 0 ; i < DTP_PORT_NUM ; i ++ ) {
        if (logging[i])
            dtp->logging[i] = 1;
        if (sending[i])
            dtp->sending[i] = 1;
        if (counter[i])
            dtp->counter[i] = 1;
    }
    if (counter[i])
        dtp->counter[i] = 1;

    dtp_board = get_pcie_portal_descriptor();
    if (!dtp_board) {
        DTP_ERROR("dtp board not null!\n");
        goto error_dtp;
    }

    dtp->board = dtp_board;

    dtp_portal_init(dtp_board);

    dtp_set_beacon_interval(0, 250);
    dtp_set_beacon_interval(1, 500);
    dtp_set_beacon_interval(2, 750);

#if 0
    __test();
    return 0;
#endif

    /* setting Proc file */
    if (!(dtp_proc = proc_create("dtp", 00666, NULL, &dtp_proc_fops))) {
        DTP_ERROR("Proc fs\n");
        goto error_dtp;
    }

    /* setting character device for mmap */
    dtp_class = class_create(THIS_MODULE, "dtpd");
    if (IS_ERR(dtp_class)) {
        DTP_ERROR("class create failed\n");
        status = PTR_ERR(dtp_class);
        goto error_proc;
    }

    if (alloc_chrdev_region(&dtp_dev, 0, 1, DEV_NAME) < 0) {
        DTP_ERROR("alloc_chrdev_retion failed\n");
        status = -EINVAL;
        goto error_class;
    }

    cdev_init(&dtp_cdev, &dtp_fops);
    if ((status = cdev_add(&dtp_cdev, dtp_dev, 1)) < 0) {
        DTP_ERROR("cdev_add failed\n");
        goto error_region;
    }   

    if (!device_create(dtp_class, NULL, dtp_dev, NULL, DEV_NAME) ) {
        DTP_ERROR("device_create failed\n");
        status = -1;
        goto error_cdev;
    }

    dtp_time = (struct dtp_time *) get_zeroed_page(GFP_KERNEL);
    if (!dtp_time) {
        DTP_ERROR("Memory error\n");
        status = -ENOMEM;
        goto error_device;
    }
    dtp_time->log_max = (PAGE_SIZE - sizeof(struct dtp_time)) / sizeof(struct dtp_log);
    
    // start kernel daemon
    dtp_daemon = kthread_run(run_dtp_daemon, NULL, "dtpd");
    if (!dtp_daemon) {
        DTP_ERROR("creating daemon failed\n");
        status = -ENOMEM;
        goto error_mem;
    }

    return 0;
error_mem:
    kfree(dtp_time);
error_device:
    device_destroy(dtp_class, dtp_dev);
error_cdev:
    cdev_del(&dtp_cdev);
error_region:
    unregister_chrdev_region(dtp_dev, 1);
error_class:
    class_destroy(dtp_class);
error_proc:
    remove_proc_entry("dtp", NULL);
error_dtp:
    kfree(dtp);
    return status;
}

static void __exit dtp_exit(void)
{
    int status;
    DTP_PRINT("dtp_exit\n");

    status = kthread_stop(dtp_daemon);
    if (status) 
        DTP_ERROR("Something bad happened during killing the daemon\n");

    free_page((unsigned long)dtp_time);

    device_destroy(dtp_class, dtp_dev);

    cdev_del(&dtp_cdev);

    unregister_chrdev_region(dtp_dev, 1);

    class_destroy(dtp_class);

    remove_proc_entry("dtp", NULL);

    kfree(dtp);
}

module_init(dtp_init);
module_exit(dtp_exit);
