# Deploying Manetu to a Colocated Kubernetes environment

The Colocated Manetu Specification (this document) is for situations where a customer wishes to manage the infrastructure components themselves or to colocate Manetu into an environment with other applications within the same Kubernetes cluster.

A Manetu deployment, regardless of type, consists minimally of a set of stateless microservices manufactured by Manetu and a set of stateful third-party components that Manetu relies upon for various types of persistence.  All of these services depend on infrastructure provided by the environment, such as sufficient compute/network resources, availability, reliable low-latency/high-bandwidth storage, log/metric collection and storage, telemetry visualization and alerting, service mesh capabilities (security, policy, identity, resilience, and monitoring), and network load-balancing.

## Prerequisites

### Compute
The persistence layers are the primary drivers of the overall performance requirements, particularly the Yugabyte and Temporal/Cassandra layers.  For configurations where all  third-party services are colocated with Manetu, the following compute resources are recommended:

- Kubernetes Node Specification available for Manetu-related use:
    - CPUs: 16
    - Memory: 64Gi
    - Networking: 10Gi+ low-latency interconnect
- Nodes should span AZs generally with a minimum of 3 AZs
- Scale:
    - Minimum: 3 for HA
    - Scale in odd numbers up to 7 (3, 5 or 7).
    - Beyond 7 can add single nodes for performance
    - Production Recommendation: 15+ nodes

### Networking

A typical deployment consists of 3 discrete Load-Balancers:

1. One for istio-ingressgateway to serve access to the Manetu product UI/API
2. One for Traefik ingress with basic-auth protection for most third-party application dashboards (e.g. yugabyte, temporal, etc.)
3. One for directly mapping to Hashicorp Vault UI for SecOps unsealing operations

It is assumed that the customer will provide access to their telemetry (grafana/prometheus/alertmanager/logging)

### Storage

#### Performance

Manetu microservices are stateless.  However, the third-party applications require reliable, low-latency, high-throughput Kubernetes Persistent Volumes provided by a customer-managed CSI to run well.

The following are the recommendations for the provided storage-class

- [NVMe](https://en.wikipedia.org/wiki/NVM_Express) class devices with high IOPS and throughput are recommended and will work best.
    - Must be able to sustain 750+ Synchronous IOPS(1) for baseline performance.  1000+ Synchronous IOPS are recommended
    - When using AWS EBS, the minimum recommended spec for storage is GP3 with 16k provisioned IOPS and 1Gbs throughput.
- [XFS](https://en.wikipedia.org/wiki/XFS): The storage-class should be formatted with XFS for maximum performance, when available.

(1) See [Disk Performance](./diskperformance.md)


## Setup

As noted in the [General Setup](../README.md#setup), an instance requires an inventory file.  The inventory for a colocated deployment is relatively simple since it consists solely of the Configuration Host.  An example inventory for colocated deployment follows:

```yaml
all:
  vars:
    manetu_namespace: manetu-platform
    manetu_dns: manetu.example.com
    manetu_platform_chart_ref: oci://example.jfrog.io/manetu-docker-local/manetu-platform
    manetu_platform_version: 2.0.0-v2.0.0.b32.7524
    s3_enabled: false
    s3_insecure: false
    vault_enabled: false

    temporal_server_replicas: 5
    temporal_frontend_replicas: 5
    temporal_matching_replicas: 16
    temporal_worker_replicas: 5

    temporal_history_replicas: 16
    temporal_history_resources: {}
    temporal_history_shards: 3000

    cassandra_storage_size: 200Gi
    cassandra_resources:
      requests:
        memory: 8Gi
        cpu: 4
      limits:
        memory: 24Gi
        cpu: 12

    kafka_storage_size: 200Gi
    kafka_resources:
      requests:
        memory: 8Gi
        cpu: 4
      limits:
        memory: 16Gi
        cpu: 8

    zookeeper_resources:
      requests:
        memory: 4Gi
        cpu: 1
      limits:
        memory: 4Gi
        cpu: 2

    minio_persistence_size: 200Gi

    yugabyte_master_storage_size: 10Gi
    yugabyte_tserver_storage_size: 200Gi
    yugabyte_resources:
      master:
        requests:
          cpu: 1
          memory: 2Gi
        limits:
          cpu: 2
          memory: 2Gi
      tserver:
        requests:
          cpu: 4
          memory: 8Gi
        limits:
          cpu: 12
          memory: 24Gi

config_host:
  hosts:
    localhost:
      ansible_connection: local
      ansible_python_interpreter: /home/gregory_haskins1/python/bin/python
```

## Deployment

Deployment follows similar patterns from the primary documentation, with the primary difference being the utilization of the deploy-colocated playbook, as so:

``` shell
ansible-playbook ansible/deploy-colocated.yml -i inventories/myinventory/inventory.yml --ask-vault-pass
```

## Telemetry

### Logging
Manetu pods emit logs to stdout, as is typical with Kubernetes solutions.  The customer is expected to have a Kubernetes log aggregating infrastructure, such as Fluentd or Loki.

### Metrics
Manetu and Third-Party pods adhere to the Prometheus ServiceMonitor/PodMonitor CRD method of registering metric endpoints.  The customer is responsible for installing and operating a suitable Prometheus Operator infrastructure compatible with the CRDs.  The following ansible variables configure the installation of the Manetu-specific monitors:

| Variable                     | Type | Default | Description |
| ---------------------------- | ---- | ------- | ----------- |
| monitoring_enabled           | bool | 'false'  | Top-level switch for installing metrics, alerts, and/or dashboards |
| prometheus_monitor_labels    | dict | {}      | Optional additional labels to apply to any Service/PodMonitors |

#### Granting Access

The Manetu Platform prohibits inter-namespace access via [NetworkPolicy](https://kubernetes.io/docs/concepts/services-networking/network-policies/), which limits the ability of other applications within your cluster from directly connecting to Manetu pods.  There are implications for your Prometheus monitoring infrastructure, which must be white-listed to scrape the registered metrics endpoints within the Manetu namespace successfully.  You accomplish this with a [label](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/) 'access.manetu.io/manetu=true' applied to the namespace that Prometheus is running in.

For example, if your Prometheus infrastructure runs in the namespace 'prometheus', you may add the label with the following command:

``` shell
kubectl label namespace prometheus access.manetu.io/manetu=true
```

#### Alerts
Manetu curates a set of proprietary and third-party Prometheus AlertManager rules available for integration into the customer's Prometheus infrastructure via the PrometheusRule CRDs.  The following ansible variables configure the installation of the Manetu-specific alert rules:

| Variable                     | Type | Default | Description |
| ---------------------------- | ---- | ------- | ----------- |
| monitoring_enabled           | bool | 'false'  | Top-level switch for installing metrics, alerts, and/or dashboards |
| alerts_enabled               | bool | 'false'  | Option to enable the installation of PrometheusRule objects |

### Dashboards
Manetu curates a collection of proprietary and third-party Grafana dashboards that may be integrated into the customer’s Prometheus/Grafana stack.  Most third-party dashboards are available in the [public regitstry](https://grafana.com/grafana/dashboards/?pg=docs-grafana-latest-dashboards).  A few third-party dashboards are available via URL.  Lastly, Manetu-supplied dashboards are available in this repository.

The colocated install method lacks the means to install the dashboards automatically at the time of writing.  Therefore, this section guides the manual installation of dashboards that must be undertaken as a step outside of playbook execution.  Note that the dashboards referenced below generally require installed and available metrics; thus, monitoring_enabled='true' is a prerequisite.

#### Manetu-sourced Dashboards

| Name                                  | Download Link | Description     |
| ------------------------------------- | ---------- | --------------- |
| Cluster Overview | [link](../ansible/roles/monitoring/files/status-page.json) | General pod health dashboard, suggested as the Home/Landing page |
| RED Dashboard | [link](../ansible/roles/monitoring/files/red.json) |  Requests/Errors/Duration Dashboard for key performance metrics |

#### Third Party

Manetu leverages several third-party components as part of its stack, and monitoring them is a critical function of operating and tuning the system.  The following dashboards are recommended to help assist in this effort:

##### Kubernetes

https://kubernetes.io/

| Name                            | Grafana ID | Description |
| ------------------------------- | ---------- | ------------ |
| Kubernetes / Views / Global     | 15757      | A modern 'Global View' dashboard for your Kubernetes cluster(s) |
| Kubernetes / Views / Namespaces | 15758      | A modern 'Namespaces View' dashboard for your Kubernetes cluster(s) |
| Kubernetes / Views / Nodes      | 15759      | A modern 'Nodes View' dashboard for your Kubernetes cluster(s) |
| Kubernetes / Views / Pods       | 15760      | A modern 'Pods View' dashboard for your Kubernetes cluster(s) |

##### Istio

https://istio.io/

| Name                            | Grafana ID | Description |
| ------------------------------- | ---------- | ------------ |
| Istio Control Plane Dashboard   | 7645       | Monitors Istio itself |
| Istio Mesh Dashboard            | 7639       | Monitors components using Istio at the mesh level |
| Istio Performance Dashboard     | 11829      | Monitors performance metrics (request rate, throughput, latency, and errors) |
| Istio Service Dashboard         | 7636       | Monitors components at the Service level |
| Istio Workload Dashboard        | 7630       | Monitors components at the Workload level |

##### Hashicorp Vault

https://www.vaultproject.io/

| Name                            | Grafana ID | Description |
| ------------------------------- | ---------- | ------------ |
| Hashicorp Vault                 | 12904      | Monitors sealed/unsealed status and other key vault metrics |

##### Yugabyte

https://www.yugabyte.com/

| Name                            | Grafana ID | Description |
| ------------------------------- | ---------- | ------------ |
| YugabyteDB                      | 12620      | Provides a range of metrics to quickly understand the performance and health of YugabyteDB |

##### Minio

https://min.io/

| Name                                  | Grafana ID | Description     |
| ------------------------------------- | ---------- | --------------- |
| Minio Overview                        | 10946      | |
| MinIO Cluster Replication Dashboard   | 15305      | |


##### Kafka

https://kafka.apache.org/

| Name                                  | Download Link | Description     |
| ------------------------------------- | ---------- | --------------- |
| Strimzi Kafka | [link](https://raw.githubusercontent.com/strimzi/strimzi-kafka-operator/main/examples/metrics/grafana-dashboards/strimzi-kafka.json) | Main Kafka Broker Dashboards |
| Strimzi Client Exporter | [link](https://raw.githubusercontent.com/strimzi/strimzi-kafka-operator/main/examples/metrics/grafana-dashboards/strimzi-kafka-exporter.json) | Client Metrics |
| Strimzi Operator   | [link](https://raw.githubusercontent.com/strimzi/strimzi-kafka-operator/main/examples/metrics/grafana-dashboards/strimzi-operators.json)      | Operator Dashboards |
| Strimzi ZooKeeper | [link](https://raw.githubusercontent.com/strimzi/strimzi-kafka-operator/main/examples/metrics/grafana-dashboards/strimzi-zookeeper.json) | ZooKeeper Dashboards |

## Backup / Disaster Recovery
The customer is responsible for backing up any PVs requested by the third-party applications or restoring them in the event of a DR scenario.  Backups should be as close to atomically synchronized as possible for the available CSI.

The customer is also responsible for securely storing the inventory and secrets generated in the [setup](../README.md#setup).

The restored PVs, inventory, and secrets may be used to re-deploy a recovered Manetu instance in the same or different location.

## Teardown

Tearing down a colocated instance may require care for the cases where other applications within the shared cluster are to remain intact.

The following playbook may be used to remove the primary components of Manetu from a colocated instance:

``` shell
ansible-playbook ansible/teardown-manetu.yml -i inventories/myinventory/inventory.yml --ask-vault-pass
```

NB Use with extreme caution since this will be destructive to the Manetu components and their PVs within whatever instance your inventory points to.

NB.  This playbook only removes manetu-* prefixed namespaces, but may leave other artifacts such as istio-system and cert-manager in place even if the deploy-colocated playbook previously installed them.  This is a conservative step to protect your system if these services were installed by something other than the Manetu playbooks.

## Integration

### Internal DNS

By their nature, colocated installs often have other applications running within the same cluster.  While these applications typically can access the Manetu Platform using the external DNS via a load balancer, a more direct connection that avoids extra network hops may be more optimal.  For these cases, application developers may utilize an alternative DNS name available only to adjacent applications within the same Kubernetes cluster.

By default, these playbooks install a [Kubernetes Service](https://kubernetes.io/docs/concepts/services-networking/service/) alongside the Manetu deployment that creates a DNS CNAME record such as 'ingress.manetu-platform', or 'ingress.manetu-platform.svc.cluster.local'.  This service registration creates a stable relative address for your in-cluster applications.  Referencing this endpoint transparently redirects callers through the Istio Ingress Gateway registered with Manetu without requiring an external hop through a load-balancer.

N.B. the Istio Ingress Gateway is configured for TLS regardless of external or internal request origination.  Thus, client applications may need to be configured to trust the certificate-authority of the gateway for cases where the gateway is not part of a public-key infrastructure (PKI).

You may control the name of the CNAME record via the 'manetu_internal_dns' Ansible variable, which defaults to 'ingress.'
