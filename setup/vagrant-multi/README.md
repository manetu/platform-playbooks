# [Vagrant](https://www.vagrantup.com/) based setup

For development, we include a [Vagrantfile](../../Vagrantfile) and related [inventory](./ansible-inventory.yml) to allow development to iterate quickly by automating the prerequisites (worker nodes, etc) along with the ability to invoke the deployment playbook.

## Requirements

Install vagrant-disksize plugin:
``` shell
vagrant plugin install vagrant-disksize
```

Install ansible kubernetes.core
```shell
ansible-galaxy collection install kubernetes.core
```

## Usage

N.B. All commands should be run from the same directory as the Vagrantfile

### Create environment

``` shell
vagrant up
```

### Destroy environment

``` shell
vagrant destroy -f
```

## Troubleshooting

If you see an error similar to:

```
The IP address configured for the host-only network is not within the
allowed ranges. Please update the address used to be within the allowed
ranges and run the command again.

  Address: 192.168.34.11
  Ranges: 192.168.56.0/21

Valid ranges can be modified in the /etc/vbox/networks.conf file.
```

You may need to create a file named ``` networks.conf ``` at ```/etc/vbox ```. In the file copy the following:

```
* 10.0.0.0/8 192.168.0.0/16
* 2001::/64
```
