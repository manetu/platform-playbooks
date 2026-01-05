# Deploying Manetu to Amazon Elastic Kubernetes Service

This document outlines how to use the playbooks to deploy to [Amazon Elastic Kubernetes Service](https://aws.amazon.com/pm/eks).  These playbooks will set up an entire environment, including VPC, subnets, internet gateways, Route53 DNS, EKS, and EC2 instances, and all of the infrastructure, third-party, and Manetu components within.

## Prerequisites

In addition to the [general prerequisites](../README.md#prerequisites), EKS deployments require:

### Ansible Galaxy Collections for AWS

The following additional Ansible Galaxy collections are required for EKS deployments:

* [amazon.aws](https://galaxy.ansible.com/ui/repo/published/amazon/aws/): Tested with v9.5.0
* [community.aws](https://galaxy.ansible.com/ui/repo/published/community/aws/): Tested with v9.3.0

Install the required collections:

```shell
ansible-galaxy collection install amazon.aws:==9.5.0 community.aws:==9.3.0
```

### Python Dependencies

The AWS collections require the following Python packages on your Configuration Host:

```shell
pip install boto3 botocore
```

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
## Notes on naming
The value for the key `all.vars.aws_instance_name:` is used to name a number of aws objects in the deployment including the VPC, the eks cluster, security groups, and aws policies. 

The value of the key: `all.vars.aws_route_53_zone:` is a hosted Route 53 zone which will hold a number of DNS entries associated with the deployment. The zone must already exist and the IAM entity executing the playbook should have write access to the zone.

The value for the key `all.vars.manetu_dns:` is the fully qualified DNS name to be associated with the platform ingress port load balancer. This entry will be a CNAME record added to the Route53 zone specifed by `all.vars.aws_route53_zone`. In the attached example the platform ingress will be accessed at https://manetu.perflab.dev.manetu.io.

The value of the key `all.vars.mgmt_dns_suffix:` is used to create a DNS wildcard entry to associate with the management interface ingress port load balancer. This entry will be a CNAME record added to the Route53 zone specifed by `all.vars.aws_route53_zone`. In the attached example a wildcard CNAME entry `*.perflab.dev.manetu.io` will be created. Various management UIs will be accessible via this suffix, e.g. `https://grafana.perflab.dev.manetu.io`

## Operations

### Deployment

```shell
ansible-playbook -i path/to/inventory.yml ansible/deploy-eks.yml --ask-vault-pass --extra-vars @ansible/profiles/large.yml
```

### Teardown

```shell
ansible-playbook -i path/to/inventory.yml ansible/teardown-eks.yml --ask-vault-pass
```

N.B. Use extreme caution since this will destroy the entire cluster.
