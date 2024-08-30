# Development Usage

Development follows the [Embedded](./embedded.md) model, where the infrastructure is provided by developer friendly virtualization, such as Vagrant.

## Prerequisites

In addition to the general prerequisites, development use will also need either Vagrant/Virtualbox OR access to a Proxmox cluster:

* [Single node](./setup/vagrant/README.md): Simplest
* [Vagrant](./setup/vagrant/README.md): *Preferred*
* [Proxmox](./setup/proxmox/README.md): More complex but also more flexible option.

### Setup

Setting up for development via this repository involves a few initial steps.  The outline is as follows:

- Provisioning phase 1 infrastructure, such as with vagrant or proxmox
- Taking an initial 'pre-install' snapshot of the phase 1 infrastructure to provide a convenient rollback point for iteration.
  - vagrant: 'vagrant snapshot save pre-install'
  - proxmox: see proxmox README

## Usage

### Vagrant

#### Single Node

##### Deploy

``` shell
ansible-playbook ansible/deploy-embedded.yml -u ubuntu --key-file ~/.ssh/<target-key> -i setup/single-node/ansible-inventory.yml --extra-vars @ansible/profiles/dev.yml --skip-tags upgrade
```

#### Simulated Cluster

##### Deploy

``` shell
ansible-playbook ansible/deploy-embedded.yml -u vagrant --key-file ~/.vagrant.d/insecure_private_key -i setup/vagrant/ansible-inventory.yml --skip-tags upgrade
```

#### Restore
```shell
vagrant snapshot restore pre-install
```

### Proxmox

#### Deploy

``` shell
ansible-playbook ansible/deploy-embedded.yml -i path/to/inventory.yml --ask-vault-pass
```

#### Restore

```shell
ansible-playbook setup/proxmox/restore.yml -i path/to/inventory.yml
```
