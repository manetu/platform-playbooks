# Deployment Playbooks

This repository is a collection of automation tools for managing a Manetu instance lifecycle (deployment, upgrade, and teardown).

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

Each deployment you manage should be represented by one [Ansible Inventory](https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html).  These inventories allow you to declare various hosts that Ansible will manage.  They also allow you to customize the deployment by setting [Ansible Variables](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html).

Any given deployment consists of sensitive (e.g., an encryption password) and insensitive variables (e.g., the amount of disk space to allocate).  You should avoid storing sensitive values in your inventory as plaintext.  Ansible provides a mechanism to protect sensitive values: [Ansible Vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html).  See [Secrets](#Secrets) for more information.

These playbooks aim to provide sensible production-grade defaults, including considerations such as security and reliability.  Therefore, scripts and methods are provided to help you easily build an inventory that meets these goals while leveraging best practices, such as encrypting sensitive values using Ansible Vault.

The outline for creating a new inventory is as follows:

- Gather any external secrets required, such as credentials for the Docker registry that houses the Manetu assets.
- Use './scripts/create-inventory.sh path/to/myinventory' to create a new inventory skeleton, dedicated for this specific instance.
- Make a note of the password generated and store it somewhere safe, such as a password manager shared with the ops team.
- Customize the inventory to your requirements
- Add the path/to/myinventory to source control or another reliable repository shared with the ops team.
    - Be sure to keep the inventory password separate from the inventory storage.

#### Gather External Secrets

Your installation will require access to a Docker registry to pull Manetu assets such as containers and helm charts.  These secrets should be stored in environment variables before running the scripts.

| Name                | Description                                                    |
| ------------------- | -------------------------------------------------------------- |
| REGCRED_USER        | Username for docker registry access to Manetu charts/images    |
| REGCRED_PASSWORD    | Password for docker registry access to Manetu chart/images     |

#### Generating the Inventory

Once the environment variables are set, you should pick a location to store the inventory.  Manetu recommends that this location be something that can eventually support reliable storage and change control, such as an enterprise git repository with access controls and backups.  Manetu does not recommend committing the inventories directly to this repository since future playbook updates may collide with your changes.

For convenience, this repository supports storing inventory files under a directory named _inventories_, which has been excluded from git via the [.gitignore](.gitignore) file.  This feature is helpful for dev/testing or initial deployment, but production instances should move this to reliable storage as outlined above as soon as possible.

To run, you will need to execute the create-inventory script as so:

```shell
$ ./scripts/create-inventory.sh inventories/foo
Your inventory has been created at inventories/foo.

------------------------------------------------------------
 Password: egTxDckC6OWDa1jbvUdBWM6aPofErnIhjw6TGXbrwi7WBehPnDxzWphiOlf7ReFV

 Store it somewhere safe.  It will not be displayed again.
------------------------------------------------------------
```

As indicated, make a secure and reliable note of the password, such as within a 1Password vault.

**NB.  Loss or corruption of the decryption password may result in the inability to maintain or recover a Manetu instance.**

You should now see some files were created in the designated location:

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

You will likely need to customize the generated inventory to your requirements.  For example, the DNS name assigned to your instance will probably be unique.  The available options to tune can generally be found under ./ansible/roles/.../defaults/main.yml for the roles provided.

You may use any valid Ansible Inventory technique to customize, such as editing the all.vars section in the inventory.yml file in the top directory of the generated inventory.  An example inventory may look as so:

```yaml
all:
  hosts:
    node-1:
      ansible_host: 10.20.32.40
    node-2:
      ansible_host: 10.20.32.42
    node-3:
      ansible_host: 10.20.32.41
    node-4:
      ansible_host: 10.20.32.43
  vars:
    manetu_platform_version: 2.0.0-v2.0.0.b31.7505
    manetu_dns: manetu.example.com

config_host:
  hosts:
    node-1:

k3s_primary:
  hosts:
    node-1:

k3s_secondary:
  hosts:
    node-[2:3]:

k3s_agents:
  hosts:
    node-4:
```

Note that some options are available in a pre-configured manner called [Profiles](#Profiles).

(1) Not all Ansible groups depicted above are relevant for all [Deployment Models](#deployment-model), so consult the model documentation for specifics.

#### Configuration Host

You will need to designate a Configuraiton Host.  This host is where ansible will run many of its commands such as kubectl and helm.  Typically this is either the machine that you are running ansible on, or one of the designated hosts, typically node-1

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

#### Store your inventory for safekeeping

Manetu strongly recommends storing your inventory in a reliable, change-control-managed repository for future use.  Authorized personnel will need access to the inventory configuration to manage or restore the instance in a disaster recovery scenario.

**NB.  Loss or corruption of the inventory may result in the inability to maintain or recover a Manetu instance.**

The inventory.yml and group_vars subdirectories are all related to your Ansible Inventory.  The platform-operator-credentials.p12 file is a PKCS12 certificate and key pair used to authenticate the _Platform Operator_ principal.  Any sensitive data, such as generated passwords, registry credentials, or platform operator credentials, have been encrypted with the noted password and are, therefore, safe to store in insecure locations such as a git repository.  As previously mentioned, maintain the generated password in a separate secure location accessible only to authorized parties.

### Setting up a new Configuration Host

These playbooks have a concept of a _Configuration Host_, which is an Ansible-managed node that, in turn, is used to drive Kubernetes operations such as [kubectl](https://kubernetes.io/docs/reference/kubectl/) and [Helm](https://helm.sh/) to the target cluster.  The Configuration Host will often be your local workstation or a customer-provided jumphost.

Ansible relies on Python in general, and these playbooks require specific Python dependencies to be available on the selected Configuration Host such as [kubernetes](https://pypi.org/project/kubernetes/) and [botocore](https://pypi.org/project/botocore/).  Because of this, there are potential advantages to isolating the Python environment by dedicating a python [venv](https://docs.python.org/3/library/venv.html) to Ansible.

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

Each Manetu instance requires various secrets to maintain security.  Some secrets are common to all deployment models, while others are specific to configuration options.

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

The reference implementation utilizes Kubernetes [EncryptionConfiguration](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/) to encrypt secrets via Etcd such as the prsk_password to maintain this separation from Vault.  Take care if opting to use the Hashicorp Vault [Kubernetes Secret Engine](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-secrets-engine) instead of Etcd to avoid inadvertently colocating the engine containing the prsk_password and transit-engine together.  This configuration creates a single point of breach and permits unilateral bootstraping, violating core security features of the Manetu design.

## Usage

A typical deployment operation uses the [ansible-playbook](https://docs.ansible.com/ansible/latest/cli/ansible-playbook.html) command in a structure similar to the following:

``` shell
ansible-playbook ansible/deploy-embedded.yml -i inventories/myinventory/inventory.yml --ask-vault-pass
```

Consult your chosen [Deployment Model](#deployment-model) documentation for specifics.

> Warning: Deployment-level playbooks are intended to orchestrate the initial installation.  Running the deployment playbooks against a previously deployed instance may result in unexpected/undesirable changes to your system, such as rebooting nodes or applying an incompatible change.  For example, the deploy-embedded playbooks may reboot Kubernetes nodes to apply operating-system level updates, and the variable 'temporal_history_shards' cannot be changed after the system has been deployed.  Note that incompatible changes may include explicit settings in your inventory, or implicit changes by adopting a new profile (See [Profiles](#profiles) below).
>
> Thus, top-level redeployment via the deploy_xx playbooks for a running system is not supported.  For upgrades to the Manetu platform, see [Upgrades](#Upgrades).

### Profiles

The playbooks and roles employ secure and resilient defaults without specific tuning.  These defaults should be suitable for production use on small to mid-sized clusters with only moderate scaling requirements.

Profiles are a set of Ansible variables conveniently pre-configured and available for everyday use cases extending beyond the abovementioned defaults.  Profiles are yaml files that override playbook defaults via the Ansible [--extra-vars](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html#id37) feature.

Example:

```shell
ansible-playbook ... --extra-vars @ansible/profiles/dev.yml
```

- **dev**: This profile is helpful for development and testing scenarios because it substantially decreases the system requirements necessary to run an instance.  It achieves this by eliminating most HA/scaling features; thus, it is unsuitable for production workloads.

- **mid**: This profile is helpful for a mid-tier production instance.  It is tested with 6 m7i.4xlarge (16 vcpu / 64Gi ram) nodes running in AWS across three availability zones and provides moderate performance while maintaining a secure and reliable posture.

- **bigiron**: This profile is helpful for more significant production instances with sufficient resources to run scaled-up configurations of various components.  It also serves as a demonstration of the essential tuning knobs for scaling.  We have tested this profile with clusters with at least 18 nodes consisting of 16 vcpu / 64Gi ram each.

NB Ansible variables have [precedence rules](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html#variable-precedence-where-should-i-put-a-variable) and it should be noted that --extra-vars generally have the highest precedence.  You shoud exercise care to understand the implications between overriding variables in your inventory vs. including a profile or any other extra-vars-based mechanism.

## Operations

### Provision a Manetu Realm

The Platform Operator is responsible for inter-tenancy functions, such as creating new realms.

#### Prerequisites

- [curl](https://curl.se/)
- [jq](https://stedolan.github.io/jq/)
- [yq](https://github.com/mikefarah/yq)
- [Manetu Security Token](https://github.com/manetu/security-token)

#### DNS

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

#### Access Token

Get a JSON Web Token (JWT) for the platform operator via the manetu-security-token tool.

You will need the password for your inventory

``` shell
export INVENTORY_PASSWORD=egTxDckC6OWDa1jbvUdBWM6aPofErnIhjw6TGXbrwi7WBehPnDxzWphiOlf7ReFV
```

``` shell
export MANETU_TOKEN=$(manetu-security-token login --insecure pem --path --p12 inventories/myinventory/platform-operator-credentials.p12 --password $INVENTORY_PASSWORD)
```

#### Invoke the GraphQL API

``` shell
cat <<EOF | yq -r -o=json - | curl --insecure --data-binary @- --silent --show-error --fail --header 'Content-Type: application/json' --header "Authorization: Bearer $MANETU_TOKEN" $MANETU_URL/graphql | jq
query: |
  mutation {
    create_realm(
      id: "piedpiper",
      iam_admin_password: "somepassword",
      data: { name: "Pied Piper", logo_uri: "/static/mock/pied-piper-logo.png" }
    )
  }
EOF
```

Point your web browser to your instance (e.g., https://manetu.example.com) and log in.

NB.  The --insecure flag is needed only for testing/development when utilizing self-signed certificates.

### Upgrade

Manetu may release updates to the platform from time to time.  These updates are delivered as Helm charts and Docker images pushed to a Docker/OCI registry.

Upgrades are facilitated by Helm and orchestrated by Ansible.

#### Overview

At a high level, the steps are:

- Identifying the selected release version
- Updating the {{ manetu_platform_version }} in your inventory for the instance
- Perform the upgrade by running the appropriate playbook as prescribed

#### Identifying the Release

This process will vary from customer to customer.  Please consult with your Manetu Support Representative for details specific to your circumstances.  Ultimately, a release is referenced by a string that looks like `2.0.0-v2.0.0.b34.7567`

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

Under the covers, the upgrade playbooks are leveraging [helm upgrade](https://helm.sh/docs/helm/helm_upgrade/) to orchestrate and automate the upgrade of the components in your system.  Using the playbook rather than Helm directly helps to ensure that the upgrade is applied in a manner that is consistent with previous installation/upgrade operations.

N.B. Performing an upgrade is normally applied against a live system without any service outage.  Occasionally, a new release may require a data migration (consult the release notes or your Manetu Support Representative).  The procedure for data migration is slightly different and involves a service outage, the duration of which depends on various factors such as the nature of the migration and your specific data set.  Consider performing such upgrades during a scheduled maintenance window communicated to your users to minimize interruptions.  Manetu recommends testing all upgrades in lower-value environments, such as a parallel staging or UAT environment, before being promoted to production.

##### Online Upgrade (no data migration required)

To upgrade a Manetu instance when no data migration is required, run:

``` shell
ansible-playbook ansible/manetu.yml -i inventories/myinventory/inventory.yml --ask-vault-pass
```

Be sure to use the same options, if any that you used to perform any prior playbook options, such as using `--extra-vars @ansible/profiles/bigiron.yml.`

##### Data-Migration Upgrade

To upgrade a Manetu instance when data migration is required, run:

``` shell
ansible-playbook ansible/migrate-manetu.yml -i inventories/myinventory/inventory.yml --ask-vault-pass
```

Be sure to use the same options, if any that you used to perform any prior playbook options, such as using `--extra-vars @ansible/profiles/bigiron.yml.`

You will be asked to confirm the operation before the upgrade commences.

``` shell
TASK [Confirm] ****************************************************************************************************************************************************************************************************
[Confirm]
Data migration requires taking the platform offline; thus, service will be unavailable during the upgrade window.  Press return to continue, or press Ctrl+c and then "a" to abort:
```

If you opt to continue, the system will be taken offline, migrated, and restored without any further intervention.

The time to complete the migration will vary with factors such as the nature of the migration and your specific data set.  Simple and small data sets will migrate quickly.  Complex and large data sets may take longer.  Consult with your Manetu Support Representative and Release Notes, and test thoroughly in lower-value environments to properly plan the Maintenance Window estimate.

### Teardown

Consult your chosen [Deployment Model](#deployment-model) documentation for specifics.

## Development

See [Development](./docs/development.md)
