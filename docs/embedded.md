# Manetu Embedded Deployments

## Introduction

Some customers wish to run their own Manetu instance, e.g., within their cloud or data center.  The Embedded deployment model is intended to enable such deployments by minimizing the external complexity required to install and operate such an instance.

Any deployment must meet a minimum standard of performance, availability, resilience, monitoring, and disaster recovery while being reasonably self-contained and automated whenever possible to avoid overburdening the customer.

This specification covers a single region FT/HA instance with an offsite DR-style strategy.  Other configurations (such as active/standby or active/active) are TBD.

## Prerequisites

Each instance will require the customer to provide the following:

### Compute

- A single small (1-2 vCPU, 4Gbi) Ubuntu Linux 22.04 host (bare-metal or VM)
used as a Configuration Host (ansible, helm, etc.).
- 1-7 (must be an odd number) of Ubuntu Linux 22.04 Linux Primary/Secondary Server Nodes (bare-metal or VM), with 3 being the minimum for HA configurations.
  - Minimum Recommended Specs
    - 16 vCPU, 64Gbi ram, 1TB+ SSD/NVME
    - 10Gbps+ low-latency inter-connection
  - It should be provisioned with a passwordless sudo account and an SSH public key from the Configuration Host.
  - An IP per host.
    - Must be SSH accessible from the Configuration Host
- Additional Agent Nodes with the same specs as Primary/Secondary Nodes may be added for performance scaling.
  - Performance configurations are recommended to have the total set of nodes (Servers + Agents) to meet or exceed 16 since services like Kafka, Yugabyte, Cassandra, and Temporal can be demanding at scale.
  - This number can typically be reduced if the customer runs the third-party services externally (e.g., managed services, existing/shared service, etc.).

### Storage

- An S3 target for artifact storage, backups, and logging.
  - Bucket configuration TBD
  - Must be DR compatible (distinct availability region from primary site)
- Local storage
  - 1TB+ space per node mounted under {{ longhorn_storage_path }} (defaults to /var/lib/longhorn) for use by [Longhorn](https://longhorn.io/) for persistent volumes within Kubernetes
      - [NVMe](https://en.wikipedia.org/wiki/NVM_Express) class devices with high IOPS and throughput are recommended and will work best.
          - Must be able to sustain 750+ Synchronous IOPS(1) for baseline performance.  1000+ Synchronous IOPS are recommended
      - Should be formatted with [XFS](https://en.wikipedia.org/wiki/XFS)
  - A minimum of 50GB available under /var/lib/rancher for use by Kubernetes (audit logging, etcd storage, etc).

(1) See [Disk Performance](./diskperformance.md)

### Networking
- Two IP addresses migratable/routable to any worker node
  - Optional but recommended DNS registration
    - One address will serve as the Manetu product access point and is suitable for simple A record registration, e.g., instance.manetu.example.com
    - The second address will serve as the access for all third-party components (e.g., grafana, alert-manager, etc) and should allow wild-carding, *.mgmt.manetu.example.com e.g. grafana.mgmt.manetu.example.com
  - May be public or private at the customer’s discretion.

### Container Registry

Customers opting for air-gapped installs must provide an accessible Docker container registry (e.g., Artifactory) with prescribed first and third-party artifacts pre-loaded as indicated or supplied by Manetu.

### Monitoring

Optionally provide alerting target(s) compatible with Prometheus:

- AlertManager
- PagerDuty
- OpsGenie
- Slack
- Email
- etc.

## Playbook Overview

Deployment in this embedded fashion involves two phases.

### Phase 1

Per the abovementioned prerequisites, a baseline environment consists of a set of servers running Ubuntu 22.04 accessible by SSH, an S3 target, and possibly a Docker registry (for air-gapped installs).  This phase is out of the scope of these playbooks.

### Phase 2

Phase 2 is where these playbooks take over to lay down a deployment, given an inventory of resources provided by Phase 1.

#### Secrets

Each Manetu instance requires various secrets in order to maintain security.  Some secrets are common to all deployment models, while others are specific to configuration options.  This section describes secrets specific to the Embedded Deployment model.  Please also refer to any [common](../README.md#Secrets) variables.

| Syntax                   | Type        | Description                                                         |
| ------------------------ | ----------- | ------------------------------------------------------------------- |
| k3s_token                | Internal    | Authentication between K3s nodes                |
| s3_access_key_id         | External    | ACCESS_KEY_ID to external S3 instance to be used for backups/logging         |
| s3_secret_access_key     | External    | SECRET_ACCESS_KEY to external S3 instance to be used for backups/logging         |

The playbooks will automatically employ best practices, such as enabling [Wireguard](https://docs.k3s.io/installation/network-options) and [Secrets Encryption](https://docs.k3s.io/security/secrets-encryption) without explict configuration or action.

#### Inventory requirements

The embedded configuration has a few extra requirements over other deployment models related to K3s node role assignments:

Be sure to minimally specify one node as part of the 'k3s_primary' group, and place others in k3s_secondary or k3s_agent to taste.  You will also want to set 'k3s_primary_host' var to point to your designated k3s_primary node so that the other nodes may connect to it.

``` yaml
all:
  hosts:
    node-1:
      ansible_host: 10.20.32.34
    node-2:
      ansible_host: 10.20.32.35
    node-3:
      ansible_host: 10.20.32.36
  vars:
    k3s_primary_host: 10.20.32.34
    ...

k3s_primary:
  hosts:
    node-1:

k3s_secondary:
  hosts:
    node-[2:3]:
```

##### Telemetry

Telemetry features such as metrics, alerts, and tracing are disabled by default.  To enable, please add the following variables to your inventory:

``` yaml
all:
  vars:
    monitoring_enabled: true
    alerts_enabled: true
    tracing_enabled: true
```
