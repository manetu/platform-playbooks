# Deployment Playbooks

This repository contains automation tools for managing the lifecycle of a Manetu instance (deployment, upgrade, and teardown).

## Prerequisites

* [python](https://www.python.org/): Tested with v3.12
* [ansible](https://www.ansible.com/): Tested with v2.16.0
* [kubnernetes.core](https://galaxy.ansible.com/ui/repo/published/kubernetes/core/): Tested with v2.4.0
* [pwgen](https://linux.die.net/man/1/pwgen): Tested with v2.08
* [make](https://www.gnu.org/software/make/manual/make.html): Tested with GNU Make v4.4.1

## Setup

### Introduction

Setting up a new Manetu instance via this repository involves a few one-time steps.  The outline is as follows:

- Selecting a [Deployment Model](#deployment-model).
- Setting up an Ansible [Inventory](#inventory) in support of your chosen deployment model.

A responsible party, such as SecOps admins, should keep the inventory safe for future reference and use, such as upgrade and teardown operations.

### Deployment model

- [Embedded](./docs/embedded.md) - Deployment to shared-nothing bare-metal or virtual-machines.
- [Colocated](./docs/colocated.md) - Deployment to an existing Kubernetes environment, potentially alongside unrelated services.
- [Amazon EKS](./docs/eks.md) - Deployment to Amazon Elastic Kubernetes Service from scratch.
- [Amazon EC2](./docs/ec2.md) - Deployment to a single AWS EC2 instance, useful for low-cost POC/Demo environments.

### Setting up a New Inventory

Each deployment you manage should be represented by one [Ansible Inventory](https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html).  These inventories allow you to customize the hosts and [Ansible Variables](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html) that Ansible will leverage throughout your instance's lifecycle.

The playbooks provide sensible production-grade defaults, including considerations for security and reliability.    Therefore, this repository provides tools to help you quickly build an inventory that meets these goals.

Each instance of Manetu consists of sensitive (e.g., encryption passwords) and insensitive (e.g., the amount of disk space to allocate) variables.  Ansible provides a tool called [Ansible Vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html) to protect sensitive values.  Thus, these scripts will use this best practice to help keep your deployment safe by encrypting the sensitive values with an `Inventory Password`, which you will be responsible for storing securely and independently from the inventory.

> See [Secrets](#Secrets) for more information on the various sensitive fields used in a deployment.

The outline for creating a new inventory is as follows:

- Gather registry details, such as a URL and credentials for the Docker registry that houses the Manetu assets.
- Use './scripts/create-inventory.sh path/to/myinventory' to create a new inventory skeleton, dedicated for this specific instance.
- Note the inventory password generated and store it somewhere safe, such as a password manager shared with the ops team.
- Customize the inventory to your requirements
- Add your generated inventory to source control or another reliable repository shared with the ops team.
    - Be sure to keep the inventory password separate from the inventory storage.

#### Gather Registry Details

Manetu stores most deployable assets, such as Docker containers and Helm charts, within an [OCI](https://opencontainers.org/) compatible repository on a per-customer basis.  Manetu or the customer may host this repository.  In either case, you will need to gather the relevant details such as:

- The URL of the repository
- The login (username and password) credentials that minimally have read-only access to the repository.

Save the repository URL for later; you will need it to set it as a variable within your inventory.  Before running the scripts, you should also set the repository credentials for username and password in environment variables as REGCRED_USER and REGCRED_PASSWORD, respectively.

#### Generating the Inventory

Once you have set the REGCRED_xx environment variables, you should pick a location to store the inventory.  Manetu recommends choosing a location that can eventually support reliable storage and change control, such as an enterprise git repository with access controls and backups.

> For convenience, this repository supports storing inventory files under a directory named _inventories_, and thus ignores this path from git via the [.gitignore](.gitignore) file.

To run, you will need to execute the create-inventory script as so:

```shell
$ ./scripts/create-inventory.sh inventories/foo
Your inventory has been created at inventories/foo.

------------------------------------------------------------
 Inventory Password: egTxDckC6OWDa1jbvUdBWM6aPofErnIhjw6TGXbrwi7WBehPnDxzWphiOlf7ReFV

 Store it somewhere safe.  It will not be displayed again.
------------------------------------------------------------
```

As indicated, make a secure and reliable note of the inventory password, such as within a 1Password vault.

> N.B.  Loss or corruption of the inventory password may result in the inability to maintain or recover a Manetu instance.

You should now see that the script has created some files in the designated location:

```shell
$ tree inventories/foo/
inventories/foo/
├── group_vars
│   └── all
│       ├── passwords-vault.yml
│       ├── regcred-vault.yml
│       └── vars.yml
├── inventory.yml
└── platform-operator-credentials.p12
```

#### Customize the Inventory

You will need to customize the generated inventory.  For example, the DNS name assigned to your instance and the path to your docker repository will be unique.  You may discover the available tuning options by reviewing the variable defaults for each role under ./ansible/roles/.../defaults/main.yml within this repository.

You may use any valid Ansible Inventory technique to customize, such as editing the all.vars section in the inventory.yml file in the top directory of the generated inventory.  An example inventory may look as so:

```yaml
all:
  vars:
    manetu_platform_chart_ref: oci://registry.example.com/manetu
    manetu_platform_version: 2.2.0-v2.2.0.b26.8435
    manetu_dns: manetu.example.com
```

Note that some options are available in a pre-configured manner called [Profiles](#Profiles).

#### Configuration Host

You will need to designate a Configuration Host.  This host is where Ansible will run many of its commands, such as kubectl and Helm.  Typically, the Configuration Host is either the machine that you are running Ansible on or one of the designated inventory hosts, such as `node-1`

To use localhost:

``` yaml
config_host:
  hosts:
    localhost:
      ansible_connection: local
```

To use one of your nodes

``` yaml
config_host:
  hosts:
    node-1:
```

#### Store your inventory for safe keeping

Manetu strongly recommends storing your inventory in a reliable, change-control-managed repository for future use.  Authorized personnel will need access to the inventory configuration to manage or restore the instance in a disaster recovery scenario.

> N.B.  Loss or corruption of the inventory may result in the inability to maintain or recover a Manetu instance.

The inventory.yml and group_vars subdirectories are all related to your Ansible Inventory.  The platform-operator-credentials.p12 file is a PKCS12 certificate and key pair used to authenticate the _Platform Operator_ principal.  Any sensitive data (e.g., generated passwords, registry credentials, or platform operator credentials) have been encrypted with the noted password and are, therefore, safe to store in insecure locations such as a git repository.  As mentioned, maintain the generated password in a separate secure location that is accessible only to authorized parties.

### Setting up a new Configuration Host

These playbooks have a concept of a _Configuration Host_, which is an Ansible-managed node that, in turn, is used to drive Kubernetes operations such as [kubectl](https://kubernetes.io/docs/reference/kubectl/) and [Helm](https://helm.sh/) to the target cluster.  The Configuration Host will typically be your local workstation or a jumphost.

Ansible relies on Python in general, and these playbooks require specific Python dependencies to be available on the selected Configuration Host, such as [kubernetes](https://pypi.org/project/kubernetes/) and [botocore](https://pypi.org/project/botocore/).  Because of this, there are potential advantages to isolating the Python environment by dedicating a python [venv](https://docs.python.org/3/library/venv.html) to Ansible.

The following guide demonstrates how to do this.

#### Create a dedicated python venv

``` shell
export ANSIBLE_PYTHON_ENV=~/ansible/python
mkdir -p $ANSIBLE_PYTHON_ENV
python -m venv $ANSIBLE_PYTHON_ENV
```

#### Update PIP within the new environment

``` shell
$ANSIBLE_PYTHON_ENV/bin/python -m ensurepip --upgrade
```

#### Bootstrap ansible.pip with 'packaging'

``` shell
$ANSIBLE_PYTHON_ENV/bin/pip install packaging
```

#### Update your inventory to utilize the venv

Add an 'ansible_python_interpreter' clause to your inventory representing the Configuration Host.

Example:

``` shell
config_host:
  hosts:
    localhost:
      ansible_connection: local
      ansible_python_interpreter: /Users/ghaskins/ansible/python/bin/python
```


### Secrets

Each Manetu instance requires various secrets to maintain security.  Some secrets are common to all deployment models, while others are specific to your selected configuration options.

#### Secrets Reference

This section describes the shared secrets.  Please refer to any [Deployment Model](#deployment-model) particular instructions.

| Syntax                   | Type        | Description                                                         |
| ------------------------ | ----------- | ------------------------------------------------------------------- |
| cassandra_password       | Internal    | Authentication secret between Temporal and Cassandra                |
| cassandra_tls_store      | Internal    | Key Derivation password for cassandra TLS secrets                   |
| yugabyte_password        | Internal    | Authentication secret between Manetu and Yugabyte                   |
| minio_password           | Internal    | Authentication secret between Manetu and Minio                      |
| mgmt_admin_password      | External    | DevOps basic-auth password for accessing Traefik-based management UIs (e.g. grafana, yugabyte, longhorn, etc.) |
| vault_operator_password  | External    | SecOps basic-auth password for accessing the Hashicorp Vault UI for unsealing (unused if vault_enabled=false) or when customer provides vault |
| prsk_password (1)        | Internal    | Key Derivation password for the Platform Root Sealing Key used for bootstrapping Manetu Secure Enclave network |
| manetu_registry_username | External   | Username for docker registry access to Manetu charts/images         |
| manetu_registry_password | External   | Password for docker registry access to Manetu chart/images          |

(1): The mandatory KDF password protects the PRSK along with an optional Hashicorp Vault Transit Engine when [vault_enabled=true](./docs/vault.md).  Manetu recommends that the knowledge and storage of the prsk_password be maintained separately from the Hashicorp Transit Engine and Shamir Secrets for maximum security.

The reference implementation utilizes Kubernetes [EncryptionConfiguration](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/) to encrypt secrets via Etcd, such as the prsk_password to maintain this separation from Vault.  Take care if opting to use the Hashicorp Vault [Kubernetes Secret Engine](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-secrets-engine) instead of Etcd to avoid inadvertently colocating the engine containing the prsk_password and transit-engine together.  This configuration creates a single point of breach and permits unilateral bootstraping, violating core security features of the Manetu design.

## Usage

A typical deployment operation uses the [ansible-playbook](https://docs.ansible.com/ansible/latest/cli/ansible-playbook.html) command in a structure similar to the following:

``` shell
ansible-playbook ansible/deploy-embedded.yml -i inventories/myinventory/inventory.yml --ask-vault-pass
```

Consult your chosen [Deployment Model](#deployment-model) documentation for specifics.

> Warning: The deployment-level playbooks intend to orchestrate the initial installation.  Running the deployment playbooks against a previously deployed instance may result in unexpected/undesirable changes to your system, such as rebooting nodes or applying an incompatible change.  For example, the deploy-embedded playbooks may reboot Kubernetes nodes to apply operating-system level updates, and the variable 'temporal_history_shards' cannot be changed after the system has been previously deployed.  Note that incompatible changes may include explicit settings in your inventory or implicit changes by adopting a new profile (See [Profiles](#profiles) below).
>
> Thus, top-level redeployment via the deploy_xx playbooks for a running system is not supported.  For upgrades to the Manetu platform, see [Upgrade](#upgrade).

### Hardware Requirements

The Manetu Platform is a cloud-native microservice architecture that is horizontally scalable and fault-tolerant.  It is thus suitable for deployment to various environments and hardware depending on performance and reliability requirements.  However, given the combinatorial potential of all possible deployment configurations, this section outlines options that Manetu has tested and verified.

> N.B. Manetu recommends that new customers start with one of the prescribed configurations and verify performance before iteratively introducing any desired modifications, carefully testing in non-prod environments to ensure continued adherence to performance goals.

#### Compute

Manetu recommends a standardized hardware form factor consisting of an [amd64](https://en.wikipedia.org/wiki/X86-64) based 16-core node with 64Gi memory in various cluster configurations, depending on needs (see [Profiles](#profiles)).  These compute nodes are readily available in any infrastructure provider such as AWS ([m7i.4xlarge](https://aws.amazon.com/ec2/instance-types/m7i/)) or Azure ([D16s-v5](https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/general-purpose/dsv5-series?source=recommendations&tabs=sizebasic)).

#### Network

Manetu is designed to operate across [Availability Zones](https://en.wikipedia.org/wiki/Availability_zone) but will operate best when inter-az network traffic maintains a latency target below 150us under load.

#### Storage

Manetu relies upon various persistence layers, such as Apache Kafka and Cassandra.  These layers, in turn, depend upon disk storage and are sensitive to the latency and throughput offered by the storage layer.  For best results, Manetu recommends [NVMe-grade](https://en.wikipedia.org/wiki/NVM_Express) hardware that can sustain over 750 (1000+ recommended) synchronous IOPS.

> Warning: Hyperscalers such as AWS often take liberties with what they describe as IOPS.  While related, cloud provider "Provisioned" IOPS are not typically the same as Synchronous IOPS; the latter being critical to cluster performance.  See [Disk Performance](./docs/diskperformance.md) for a simple way to quantify the delivered Synchronous IOPS for your chosen solution.

### Profiles

Profiles are standardized Manetu deployment form-factors based on various cluster sizes designed to meet specific goals (e.g., high throughput and resilient production grade vs low resource consumption and convenience for development).  Each profile consists of a certain number of standard nodes and playbook value presets to optimize the deployment's ability to utilize the hardware capabilities provided automatically.

> Unless otherwise noted, each profile offers secure and resilient production-grade defaults without specific action or tuning when used as prescribed.

| Name            | Node Count | Description |
| --------------- | ---------- | ----------- |
| Small (default) | 3          | A production-grade deployment suitable for lower-throughput applications |
| Medium          | 6          | A production-grade deployment suitable for mid-tier performance |
| Large           | 18         | A production-grade deployment with sufficient resources to run scaled-up configurations of various components for high throughput applications. |
| Dev             | 1          | Helpful for development and testing scenarios because system requirements for running an instance are significantly reduced.  It is not suitable for production workloads due to a lack of resilience. |

#### Selecting a profile

Profiles are yaml files that override playbook defaults via the Ansible [--extra-vars](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html#id37) feature.

Example:

```shell
ansible-playbook ... --extra-vars @ansible/profiles/dev.yml
```

The collection of these factory presets are stored under ansible/profiles.

> Note that playbook defaults represent the `small` profile and thus do not require an explicit `--extra-vars`.  All others have a name that aligns with the profile from the table above.

> N.B. Ansible variables have [precedence rules](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html#variable-precedence-where-should-i-put-a-variable), and you should note that --extra-vars generally have the highest precedence.  One should exercise care to understand the implications of overriding variables in your inventory vs. including a profile or any other extra-vars-based mechanism.

## Operations

### Provision a Manetu Realm

The Platform Operator is responsible for inter-tenancy functions, such as creating new realms.

#### Prerequisites

- [curl](https://curl.se/)
- [jq](https://stedolan.github.io/jq/)
- [yq](https://github.com/mikefarah/yq)
- [Manetu Security Token](https://github.com/manetu/security-token)

#### Configure Environment Variables

##### DNS

Get your DNS name "manetu_dns" from your deployment inventory.

```yaml
all:
  vars:
    ...
    manetu_dns: manetu.example.com
    ...

```

Use the DNS name to set MANETU_URL

``` shell
export MANETU_URL=https://manetu.example.com
```

##### Inventory Password

``` shell
export INVENTORY_PASSWORD=egTxDckC6OWDa1jbvUdBWM6aPofErnIhjw6TGXbrwi7WBehPnDxzWphiOlf7ReFV
```

#### Run the 'create-realm' script

``` shell
./scripts/create-realm.sh --id piedpiper --name "Pied Piper" --inventory inventories/myinventory
```

Running the above should result in output similar to the following:

``` shell
Your realm has been created.

------------------------------------------------------------
 Administrator Password: Wviry78og2me3f9DGLrjSD29W3IrMmZ4

 Store it somewhere safe.  It will not be displayed again.
------------------------------------------------------------
```

Point your web browser to your instance (e.g., https://manetu.example.com), and log in using your realm ID, username 'admin,' and the password as indicated above.

### Upgrade

Manetu may periodically release updates to the platform, delivered as Helm charts and Docker images pushed to a Docker/OCI registry.

Upgrades are facilitated by Helm and orchestrated by Ansible.

#### Overview

At a high level, the steps are:

- Identifying the selected release version
- Updating the {{ manetu_platform_version }} in your inventory for the instance
- Perform the upgrade by running the appropriate playbook as prescribed

#### Identifying the Release

This process will vary from customer to customer.  Please consult with your Manetu Support Representative for details specific to your circumstances.  Ultimately, a release is designated by a string that looks like `2.0.0-v2.0.0.b34.7567`

#### Updating the inventory

You should define an Ansible variable `manetu_platform_version` somewhere in your inventory, such as under the all.vars section:

```yaml
all:
  vars:
    ...
    manetu_platform_version: 2.0.0-v2.0.0.b34.7567
    ...

...
```

#### Performing the upgrade

Under the covers, the upgrade playbooks leverage [helm upgrade](https://helm.sh/docs/helm/helm_upgrade/) to orchestrate and automate the upgrade of your system's components.  Using the playbook rather than Helm directly helps ensure that the upgrade is applied in a manner that is consistent with previous installation/upgrade operations.

> N.B.  One typically applies an upgrade against a live system without a service disruption.  However, a new release may occasionally require data migration (consult the release notes or your Manetu Support Representative).  The procedure for data migration is slightly different and involves a service outage, the duration of which depends on various factors, such as the nature of the migration and your specific data set.  Consider performing such upgrades during a scheduled maintenance window communicated to your users to minimize interruptions.  Manetu recommends testing all upgrades in lower-value environments, such as a parallel staging or UAT environment, before being promoted to production.

##### Online Upgrade (no data migration required)

To upgrade a Manetu instance when no data migration is required, run:

``` shell
ansible-playbook ansible/manetu.yml -i inventories/myinventory/inventory.yml --ask-vault-pass
```

Be sure to use the same options, if any, that you used to perform any prior playbook options, such as using `--extra-vars @ansible/profiles/large.yml.`

##### Data-Migration Upgrade

To upgrade a Manetu instance when data migration is required, run:

``` shell
ansible-playbook ansible/migrate-manetu.yml -i inventories/myinventory/inventory.yml --ask-vault-pass
```

Be sure to use the same options, if any, that you used to perform any prior playbook options, such as using `--extra-vars @ansible/profiles/large.yml.`

The playbook will ask you to confirm the operation before the upgrade commences.

``` shell
TASK [Confirm] ****************************************************************************************************************************************************************************************************
[Confirm]
Data migration requires taking the platform offline; thus, service will be unavailable during the upgrade window.  Press return to continue, or press Ctrl+c and then "a" to abort:
```

If you continue, the playbook will take the system offline, migrate it, and restore operation without further intervention.

The time to complete the migration will vary depending on the nature of the migration and your specific data set.  Simple and small data sets will migrate quickly, while complex and large data sets may take longer.  Consult with your Manetu Support Representative and Release Notes, and test thoroughly in lower-value environments to properly plan the Maintenance Window estimate.

### Teardown

Consult your chosen [Deployment Model](#deployment-model) documentation for specifics.

## Development

See [Development](./docs/development.md)
