# Deploying Manetu to a Colocated Kubernetes environment

The Colocated Manetu Specification (this document) is for situations where a customer wishes to manage the infrastructure components themselves or to colocate Manetu into an environment with other applications within the same Kubernetes cluster.

A Manetu deployment, regardless of type, consists minimally of a set of stateless microservices manufactured by Manetu and a set of stateful third-party components that Manetu relies upon for various types of persistence.  All of these services depend on infrastructure provided by the environment, such as sufficient compute/network resources, availability, reliable low-latency/high-bandwidth storage, log/metric collection and storage, telemetry visualization and alerting, service mesh capabilities (security, policy, identity, resilience, and monitoring), and network load-balancing.

## Prerequisites

### Compute
The persistence layers are the primary drivers of the overall performance requirements, particularly the Yugabyte and Temporal/Cassandra layers.  Manetu recommends the following compute resources for configurations that colocate third-party services with the Manetu service within the same cluster:

- Kubernetes Node Specification available for Manetu-related use:
    - CPUs: 16
    - Memory: 64Gi
    - Networking: 10Gi+ low-latency interconnect
- Nodes should span AZs generally with a minimum of 3 AZs
- Scale:
    - Minimum: 3 for HA
    - Production Recommendation: 18+ nodes

### Networking

A typical deployment consists of 2-3 discrete Load-Balancers:

1. One for istio-ingressgateway to serve access to the Manetu product UI/API
2. One for Traefik ingress with basic-auth protection for most third-party application dashboards (e.g. yugabyte, temporal, etc.)
3. When enabled, one for directly mapping to Hashicorp Vault UI for SecOps unsealing operations.

The customer is responsible for providing access to their telemetry (grafana/prometheus/alertmanager/logging) infrastructure.

### Storage

#### Performance
Manetu microservices are stateless.  However, for third-party applications to run well, they require reliable, low-latency, high-throughput Kubernetes Persistent Volumes provided by a customer-managed CSI.

The following are the recommendations for the provided storage-class

- [NVMe](https://en.wikipedia.org/wiki/NVM_Express) class devices with high IOPS and throughput are recommended and will work best.
    - Must be able to sustain 750+ Synchronous IOPS(1) for baseline performance.  1000+ Synchronous IOPS are recommended
    - When using AWS EBS, the minimum recommended spec for storage is GP3 with 16k provisioned IOPS and 1Gbs throughput.
- [XFS](https://en.wikipedia.org/wiki/XFS): The storage-class should be formatted with XFS for maximum performance, when available.

(1) See [Disk Performance](./diskperformance.md)


## Setup
As noted in the [General Setup](../README.md#setup), an instance requires an inventory file.  The inventory for a colocated deployment is relatively simple since it consists solely of the Configuration Host plus any variable overrides required.  An example inventory for colocated deployment follows:

```yaml
all:
  vars:
    manetu_dns: manetu.example.com
    manetu_platform_chart_ref: oci://example.jfrog.io/manetu-docker-local/manetu-platform
    manetu_platform_version: 2.2.0-v2.2.0.b27.8471
    s3_enabled: false
    s3_insecure: false
    vault_enabled: false

config_host:
  hosts:
    localhost:
      ansible_connection: local
      ansible_python_interpreter: /home/greg/python/bin/python
```

## Deployment
Deployment follows similar patterns from the primary documentation, with the primary difference being the utilization of the deploy-colocated playbook, as so:

``` shell
ansible-playbook ansible/deploy-colocated.yml -i inventories/myinventory/inventory.yml --ask-vault-pass
```

## Telemetry

### Logging
Manetu pods emit logs to stdout, as is typical with Kubernetes solutions.  The customer is responsible for providing Kubernetes log aggregating infrastructure, such as Fluentd or Loki.

### Metrics
Manetu and Third-Party pods adhere to the [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/user-guides/getting-started.md) ServiceMonitor/PodMonitor CRD method of registering metric endpoints.  When enabling monitoring (See `monitoring_enabled` below), the customer is responsible for installing and operating a suitable Prometheus Operator-based infrastructure compatible with the CRDs.  The following ansible variables configure the installation of the Manetu-specific monitors:

| Variable                     | Type | Default | Description |
| ---------------------------- | ---- | ------- | ----------- |
| monitoring_enabled           | bool | 'false'  | Top-level switch for installing metrics, alerts, and/or dashboards |
| prometheus_monitor_labels    | dict | {}      | Optional additional labels to apply to any Service/PodMonitors |

#### Granting Access
The Manetu Platform prohibits inter-namespace access via [NetworkPolicy](https://kubernetes.io/docs/concepts/services-networking/network-policies/), which limits the ability of other applications within your cluster from directly connecting to Manetu pods.  There are implications for your Prometheus monitoring infrastructure, which must be white-listed to successfully scrape the registered metrics endpoints within the Manetu namespace.  You accomplish this with a [label](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/) 'access.manetu.io/manetu=true' applied to the namespace that Prometheus is running in.

For example, if your Prometheus infrastructure runs in the namespace 'prometheus', you may add the label with the following command:

``` shell
kubectl label namespace prometheus access.manetu.io/manetu=true
```

#### Alerts
Manetu curates a set of proprietary and third-party Prometheus AlertManager rules that are available for integration into the customer's Prometheus infrastructure via the PrometheusRule CRDs.  The following ansible variables configure the installation of the Manetu-specific alert rules:

| Variable                     | Type | Default | Description |
| ---------------------------- | ---- | ------- | ----------- |
| monitoring_enabled           | bool | 'false'  | Top-level switch for installing metrics, alerts, and/or dashboards |
| alerts_enabled               | bool | 'false'  | Option to enable the installation of PrometheusRule objects |

### Dashboards
Manetu curates a collection of proprietary and third-party Grafana dashboards available for integration into the customer’s Prometheus/Grafana stack.  Most third-party dashboards are available in the [public regitstry](https://grafana.com/grafana/dashboards/?pg=docs-grafana-latest-dashboards).  A few third-party dashboards are available via URL.  Lastly, Manetu-supplied dashboards are available in this repository.

At the time of writing, the colocated install method does not have the means to install the dashboards automatically.  Therefore, this section guides the manual installation of dashboards that must be undertaken as a step outside playbook execution.  Note that the dashboards referenced below generally require installed and available metrics; thus, monitoring_enabled='true' is a prerequisite.

#### Manetu-sourced Dashboards

| Name                                  | Download Link | Description     |
| ------------------------------------- | ---------- | --------------- |
| Cluster Overview | [link](../ansible/roles/monitoring/files/status-page.json) | General pod health dashboard, suggested as the Home/Landing page |
| RED Dashboard | [link](../ansible/roles/monitoring/files/red.json) |  Requests/Errors/Duration Dashboard for key performance metrics |

#### Third Party
Manetu leverages several third-party components as part of its stack, and monitoring them is a critical function of operating and tuning the system.  We strongly encourage the installation of the following dashboards to help assist in this effort:

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
| YugabyteDB                      | 12620      | Provides a range of metrics to understand the performance and health of YugabyteDB quickly |

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

##### Temporal

https://temporal.io/

| Name                                                    | Download Link | Description     |
| ------------------------------------- | --------------- | --------------- |
| Temporal Server                                  | [link](https://raw.githubusercontent.com/temporalio/dashboards/helm/server/server-general.json) | Main Temporal Service Dashboard |
 | Temporal SDK                                     | [link](https://raw.githubusercontent.com/temporalio/dashboards/helm/sdk/sdk-general.json) | Temporal Client metrics |
 | Temporal Frontend                              | [link](https://raw.githubusercontent.com/temporalio/dashboards/helm/misc/frontend-service-specific.json) | Temporal Frontend Service Dashboard |
 | Temporal History                                 | [link](https://raw.githubusercontent.com/temporalio/dashboards/helm/misc/history-service-specific.json) | Temporal History Service Dashboard |
 | Temporal Matching                              | [link](https://raw.githubusercontent.com/temporalio/dashboards/helm/misc/matching-service-specific.json) | Temporal Matching Service Dashboard |

## Backup / Disaster Recovery
The customer is responsible for backing up any PVs requested by third-party applications or restoring them in a disaster recovery scenario.

> N.B. Backups are ideally atomically synchronized between PVs when supported by the underlying CSI.

The customer is also responsible for securely storing the inventory and secrets generated in the [setup](../README.md#setup).

In the event of a disaster, you may use the restored PVs, inventory, and secrets to re-deploy a recovered Manetu instance in the same or a different location.

## Teardown
Tearing down a colocated instance may require care in cases where other applications within the shared cluster must remain intact.

You may use the following playbook to remove the primary components of Manetu from a colocated instance:

``` shell
ansible-playbook ansible/teardown-manetu.yml -i inventories/myinventory/inventory.yml --ask-vault-pass
```

> N.B.  Use this playbook with extreme caution, as it will destroy the Manetu components and their PVs within whatever instance your inventory points to.

> N.B.  This playbook only removes manetu-* prefixed namespaces but may leave other artifacts, such as istio-system and cert-manager, in place even if the deploy-colocated playbook previously installed them.  This precaution is a conservative step to protect your system in cases where these services were installed by something other than the Manetu playbooks.

## Integration

### Internal DNS
By their nature, colocated installs often have other applications running within the same cluster.  While these applications typically have the option to access the Manetu Platform using the external DNS via a load balancer, a more direct connection that avoids extra network hops may be ideal.  For these cases, application developers may utilize an alternative DNS name available only to adjacent applications within the same Kubernetes cluster.

By default, these playbooks install a [Kubernetes Service](https://kubernetes.io/docs/concepts/services-networking/service/) alongside the Manetu deployment that creates a DNS CNAME record such as 'ingress.manetu-platform', or 'ingress.manetu-platform.svc.cluster.local'.  This service registration creates a stable relative address for your in-cluster applications.  The service transparently redirects requests to this endpoint through the Istio Ingress Gateway registered with Manetu without requiring an external hop through a load-balancer.

> N.B.  The Istio Ingress Gateway is configured for TLS regardless of external or internal request origination.  Thus, client applications may need to be configured to trust the gateway's certificate authority in cases where the gateway is not part of a public-key infrastructure (PKI).

You may control the name of the CNAME record via the 'manetu_internal_dns' Ansible variable, which defaults to 'ingress.'
