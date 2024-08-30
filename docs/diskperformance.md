# Measuring Disk Performance

The Manetu platform requires high-throughput and low-latency disks to maximize transaction throughput.  The most critical aspect of the storage system is the Synchronous Input/Output per Second (Synchronous IOPS).  This measurement can be performed using an open-source tool [fio](https://linux.die.net/man/1/fio).  This document outlines the use of the Fio tool to measure synchronous IOPS in a Kubernetes cluster.

## Performing the measurement

Run 'kubectl apply -f' against the following file after adjusting the 'storageClassName' to match your environment.

``` yaml
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: fio-job-config
data:
  fio.job: |-
    [global]
    randrepeat=0
    verify=0
    direct=1
    gtod_reduce=1
    time_based
    ramp_time=2s
    runtime=60s
    size=10G

    [sequential-write-iops]
    name=sequential_write_iops
    ioengine=sync
    fdatasync=1
    readwrite=write
    iodepth=1
    bs=4k
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fio
  labels:
    app: fio
spec:
  replicas: 1
  selector:
    matchLabels:
      app: fio
  template:
    metadata:
      labels:
        app: fio
    spec:
      containers:
      - name: fio
        image: joshuarobinson/fio:3.19
        command: ["sh"]
        args: ["-c", "echo ${HOSTNAME} && mkdir -p /scratch/${HOSTNAME} && fio /configs/fio.job --eta=never --directory=/scratch/${HOSTNAME}"]
        volumeMounts:
        - name: fio-config-vol
          mountPath: /configs
        - name: fio-data
          mountPath: /scratch
        imagePullPolicy: Always
      restartPolicy: Always
      volumes:
      - name: fio-config-vol
        configMap:
          name: fio-job-config
      - name: fio-data
        persistentVolumeClaim:
          claimName: fio-claim
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: fio-claim
spec:
  storageClassName: local
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
```

Once this is running, you may obtain the job report with 'kubectl logs -f <podname>".  Note that the job will run for 'runtime' seconds (60s using the above config) before displaying output.

## Obtaining Results

A typical result will look as follows:

``` shell
$ kubectl logs -f fio-5846bb9545-g45p4
fio-5846bb9545-g45p4
sequential_write_iops: (g=0): rw=write, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=sync, iodepth=1
fio-3.19
Starting 1 process
sequential_write_iops: Laying out IO file (1 file / 10240MiB)

sequential_write_iops: (groupid=0, jobs=1): err= 0: pid=9: Wed Jan  3 20:22:53 2024
  write: IOPS=894, BW=3580KiB/s (3665kB/s)(210MiB/60001msec); 0 zone resets
   bw (  KiB/s): min= 2976, max= 4056, per=100.00%, avg=3583.81, stdev=227.93, samples=119
   iops        : min=  744, max= 1014, avg=895.92, stdev=57.01, samples=119
  cpu          : usr=0.57%, sys=3.29%, ctx=163691, majf=0, minf=58
  IO depths    : 1=200.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=0,53694,0,0 short=53694,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=1

Run status group 0 (all jobs):
  WRITE: bw=3580KiB/s (3665kB/s), 3580KiB/s-3580KiB/s (3665kB/s-3665kB/s), io=210MiB (220MB), run=60001-60001msec

Disk stats (read/write):
    dm-4: ios=0/110849, merge=0/0, ticks=0/55984, in_queue=55984, util=99.89%, aggrios=0/110853, aggrmerge=0/2, aggrticks=0/52669, aggrin_queue=52668, aggrutil=99.86%
  sde: ios=0/110853, merge=0/2, ticks=0/52669, in_queue=52668, util=99.86%
```

The most important is the line that looks like:

``` shell
 write: IOPS=894, BW=3580KiB/s
```

In this case, our Synchronous IOPS was measured to be 894.

## Interpreting your results

Manetu recommends IOPS > 1000+ for production systems, typically achievable with NVMe class hardware.  Values of 750+ are considered the baseline for reasonable performance.  Values below 750 are not recommended for production use.
