# Deploying Manetu to Amazon Elastic Kubernetes Service

This document outlines how to use the playbooks to deploy to [Amazon Elastic Kubernetes Service](https://aws.amazon.com/pm/eks).  These playbooks will set up an entire environment, including VPC, subnets, internet gateways, Route53 DNS, EKS, and EC2 instances, and all of the infrastructure, third-party, and Manetu components within.

## Defining an Inventory

Example

```yaml
all:
  vars:
    aws_region: us-east-2
    aws_instance_name: perflab
    aws_route53_zone: dev.manetu.io
    aws_instance_types:
      - m7i.4xlarge
    aws_capacity_type: 'ON_DEMAND' ## 'ON_DEMAND' or 'SPOT'
    aws_disk_size: 100
    aws_scaling_config:
      min_size: 1
      max_size: 16
      desired_size: 16

    manetu_dns: manetu.perflab.dev.manetu.io
    mgmt_dns_suffix: perflab.dev.manetu.io
    manetu_platform_version: 2.0.0-v2.0.0.b25.7468
    monitoring_enabled: true
    alerts_enabled: true
    s3_enabled: false
    s3_insecure: false
    vault_enabled: false
    cassandra_storage_size: 100Gi
    yugabyte_master_storage_size: 10Gi
    yugabyte_tserver_storage_size: 100Gi
    kafka_storage_size: 100Gi
    minio_persistence_size: 100Gi

config_host:
  hosts:
    localhost:
      ansible_connection: local
```

## Operations

### Deployment

```shell
ansible-playbook -i path/to/inventory.yml ansible/deploy-eks.yml --ask-vault-pass --extra-vars @ansible/profiles/bigiron.yml
```

### Teardown

```shell
ansible-playbook -i path/to/inventory.yml ansible/teardown-eks.yml --ask-vault-pass
```

N.B. Use extreme caution since this will destroy the entire cluster.
