# Deploying Manetu to a single Amazon EC2 instance

This document outlines how to use the playbooks to deploy to [Amazon Elastic Compute Cloud](https://aws.amazon.com/ec2/).  These playbooks will set up an entire environment, including VPC, subnet, internet gateways, Route53 DNS, EC2 instances, and all of the infrastructure, third-party, and Manetu components to a single instance VM, useful for demonstration purposes where cost/simplicity is more important than performance/reliability.

> This deployment lacks redundancy/backups and is only suited for a demonstration instance of Manetu.

## Prerequisites

You will require the following:

- aws cli access to a region (see {{ aws_region }} below)
- An accessible SSH key pair
   - You must ensure that you register the public key in the region noted above (see {{ aws_key_name }}).

## Defining an Inventory

Example

```yaml
all:
  vars:
    aws_region: us-east-2
    aws_instance_name: gregtest
    aws_route53_zone: dev.manetu.io
    aws_key_name: greg-sandbox
    aws_key_file: /Users/ghaskins/.ssh/gregs-aws-sandbox
    aws_route53_ttl: 300

    manetu_dns: manetu.gregtest.dev.manetu.io
    mgmt_dns_suffix: gregtest.dev.manetu.io

awsctl_host:
  hosts:
    localhost:
      ansible_connection: local
```

## Operations

### Deployment

```shell
ansible-playbook -i path/to/inventory.yml ansible/deploy-ec2.yml --ask-vault-pass --extra-vars @ansible/profiles/dev.yml
```

### Teardown

```shell
ansible-playbook -i path/to/inventory.yml ansible/teardown-ec2.yml --ask-vault-pass
```

N.B. Use extreme caution since this will destroy the entire cluster.
