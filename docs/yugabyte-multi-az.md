# Yugabyte Multi-AZ Deployment

## Introduction

By default, Yugabyte is deployed as a single-zone cluster within one namespace. For environments that require data distribution across multiple availability zones, the playbooks support a multi-AZ deployment mode that deploys separate Helm releases per zone while maintaining a unified service endpoint for consumers.

## How It Works

When `yugabyte_multi_az_enabled` is set to `true`, the playbooks deploy N separate Helm releases (one per zone) into a single shared namespace. Each release uses a zone-specific name (e.g., `yb-zone-a`, `yb-zone-b`) to avoid resource collisions, while Yugabyte's built-in `isMultiAz` mode coordinates the releases into a single logical cluster.

Key characteristics:

- **Single namespace** - All zone releases deploy to `yugabyte_namespace`, simplifying NetworkPolicy configuration.
- **Unified service endpoint** - A headless Kubernetes Service (`yugabyte-yb-tservers`) selects tserver pods across all zones, providing a single DNS name identical to the single-zone deployment. Consumers (Temporal, Manetu) require no configuration changes.
- **Zone-aware placement** - Each zone's masters and tservers receive placement gflags, and a post-deployment `modify_placement_info` command configures replica distribution across zones.
- **Shared TLS CA** - A single cert-manager CA certificate and issuer are created in the namespace, shared by all zone releases.

## Prerequisites

### Storage Class

The storage class used for Yugabyte PVCs must have `volumeBindingMode: WaitForFirstConsumer` to ensure persistent volumes are provisioned in the correct availability zone. Most cloud provider default storage classes already use this binding mode. Verify with:

```shell
kubectl get storageclass -o custom-columns=NAME:.metadata.name,BINDING:.volumeBindingMode
```

### Node Labels

Nodes must be labeled with availability zone information. By default, the playbooks use the standard Kubernetes topology label `topology.kubernetes.io/zone`, which is automatically set by most cloud providers (AWS, GCP, Azure). For bare-metal or custom environments, apply labels manually:

```shell
kubectl label node <node-name> topology.kubernetes.io/zone=<zone-name>
```

Or override the label key via `yugabyte_zone_node_selector_key`.

## Configuration

### Variables

Add the following variables to your inventory to enable multi-AZ mode:

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `yugabyte_multi_az_enabled` | `false` | Enable multi-AZ deployment mode |
| `yugabyte_zones` | `[]` | List of zone definitions (see below) |
| `yugabyte_placement_cloud` | `"kubernetes"` | Cloud identifier for placement gflags |
| `yugabyte_placement_region` | `"default"` | Region identifier for placement gflags |
| `yugabyte_zone_master_replicas` | `1` | Number of master replicas per zone |
| `yugabyte_zone_tserver_replicas` | `1` | Default number of tserver replicas per zone |
| `yugabyte_zone_node_selector_key` | `"topology.kubernetes.io/zone"` | Node label key used for zone scheduling |

### Zone Definitions

Each entry in `yugabyte_zones` requires:

| Field | Required | Description |
| ----- | -------- | ----------- |
| `name` | Yes | Identifier used in the Helm release name (e.g., `zone-a` produces release `yb-zone-a`) |
| `zone` | Yes | Availability zone value matching the node label and used in placement gflags |
| `node_selector` | No | Override the default node selector for this zone |
| `tserver_replicas` | No | Override `yugabyte_zone_tserver_replicas` for this zone |

### Examples

#### Minimal (AWS, 3 zones)

```yaml
yugabyte_multi_az_enabled: true
yugabyte_placement_cloud: "aws"
yugabyte_placement_region: "us-east-1"
yugabyte_zones:
  - name: zone-a
    zone: us-east-1a
  - name: zone-b
    zone: us-east-1b
  - name: zone-c
    zone: us-east-1c
```

#### Scaled Tservers

```yaml
yugabyte_multi_az_enabled: true
yugabyte_placement_cloud: "aws"
yugabyte_placement_region: "us-east-1"
yugabyte_zone_tserver_replicas: 2
yugabyte_zones:
  - name: zone-a
    zone: us-east-1a
  - name: zone-b
    zone: us-east-1b
    tserver_replicas: 3  # override for this zone
  - name: zone-c
    zone: us-east-1c
```

#### Custom Node Selectors (bare-metal)

```yaml
yugabyte_multi_az_enabled: true
yugabyte_placement_cloud: "custom"
yugabyte_placement_region: "dc1"
yugabyte_zone_node_selector_key: "my-label/rack"  # not used when node_selector is overridden
yugabyte_zones:
  - name: rack-1
    zone: rack-1
    node_selector:
      my-label/rack: rack-1
  - name: rack-2
    zone: rack-2
    node_selector:
      my-label/rack: rack-2
  - name: rack-3
    zone: rack-3
    node_selector:
      my-label/rack: rack-3
```

## Consumer Integration

Multi-AZ deployments are transparent to consumers. The playbooks create a unified headless Service named `yugabyte-yb-tservers` that selects all tserver pods across zones via the shared label `app.kubernetes.io/name: yb-tserver`. This produces the same DNS name used in single-zone mode:

```
yugabyte-yb-tservers.<namespace>.svc.cluster.local
```

Temporal and Manetu connect to this service without any configuration changes. YugabyteDB smart drivers handle topology-aware routing automatically.

## Backward Compatibility

When `yugabyte_multi_az_enabled` is `false` (the default), the deployment behavior is unchanged. Existing inventories and profiles work without modification.
