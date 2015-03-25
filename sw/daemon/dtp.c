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
#include <net/ip.h>
#include <net/tcp.h>
#include <linux/sched.h>
#include <linux/clocksource.h>
#include <linux/kthread.h>
#include <asm/msr.h>
#include <asm/i387.h>

#include "pcieportal.h"
#include "portal.h"

#include "dtp.h"
#define DEV_NAME "dtpd"

MODULE_AUTHOR("Ki Suh Lee");
MODULE_DESCRIPTION("DTP daemon");
MODULE_LICENSE("Dual BSD/GPL");

struct task_struct *dtp_daemon;
struct dtp_time *dtp_time;
static struct class * dtp_class = NULL;
static struct cdev dtp_cdev;
static dev_t dtp_dev;
static int ref_count=0;
static int cpun = 3;

/* pcieportal */
tBoard *dtp_board;

#define dtp_map_base(tboard, i)     ((volatile unsigned int *) (tboard->bar2io + i * PORTAL_BASE_OFFSET))
#define dtp_mapchannel(base, index) (&base[PORTAL_IND_FIFO(index)])

static int run_dtp_daemon(void * args) 
{
    cycle_t ret, ret2;
    unsigned long flags;
    uint64_t dtp=0, dtp2=0;
    int i;

    /* XXX: be careful */
    volatile unsigned int *map_base_ind = dtp_map_base(dtp_board, 0);
    volatile unsigned int *map_base_req = dtp_map_base(dtp_board, 1);

    volatile unsigned int * dtp_req = dtp_mapchannel(map_base_req, 0);
    volatile unsigned int * dtp_res = dtp_mapchannel(map_base_ind, 0);

//    volatile unsigned long long *dtp_res2 = dtp_res;


    set_cpus_allowed (current, cpumask_of_cpu(cpun));

#if 0
    for ( i = 0 ; i < 10 ; i ++ ) {
        *dtp_req = 1;
        dtp = *dtp_res;
        dtp2= *dtp_res;
        
        DTP_PRINT("%.8llx %.8llx\n", dtp, dtp2);

        __set_current_state(TASK_UNINTERRUPTIBLE);
        schedule_timeout(HZ * 1);

    }
#endif

//    for ( i = 0 ; i < 10 ; i ++ ) {
    while(1) {

        kernel_fpu_begin(); // this disables preempt
        raw_local_irq_save(flags);

        // lock the structure
        dtp_time->flag = 1; 

        // read first tsc
        rdtsc_barrier();
        ret = (cycle_t)__native_read_tsc();

        /* read dtp counter */
        *dtp_req = 1;
        dtp = *dtp_res;
        dtp2 = *dtp_res;

        // read second tsc
        rdtsc_barrier();
        ret2 = (cycle_t)__native_read_tsc();

        dtp_time->tsc1 = ret;
        dtp_time->tsc2 = ret2;
        dtp_time->low = dtp << 32 | dtp2;

        // unlock the structure
        dtp_time->flag = 0;

        raw_local_irq_restore(flags);
        kernel_fpu_end();   // this enables preempt

//        DTP_PRINT("%.16llx %.16llx %.16llx %d\n", ret, ret2, dtp<<32 | dtp2);

        __set_current_state(TASK_UNINTERRUPTIBLE);
        schedule_timeout(HZ * 1); // 1s
//	msleep(10);

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
static int __init dtp_init(void)
{
    int status = 0;

    DTP_PRINT("dtp_init\n"); 

    dtp_board = get_pcie_portal_descriptor();
    if (!dtp_board) {
        DTP_ERROR("dtp board not null!\n");
        return -EINVAL;
    }

    dtp_class = class_create(THIS_MODULE, "dtpd");
    if (IS_ERR(dtp_class)) {
        DTP_ERROR("class create failed\n");
        status = PTR_ERR(dtp_class);
        goto error;
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
error:
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
}

module_init(dtp_init);
module_exit(dtp_exit);
