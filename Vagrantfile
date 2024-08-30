# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.box_version = "20240426.0.0"
  config.ssh.insert_key = false

  config.vm.provider "virtualbox" do |v|
    v.cpus = 8
    v.memory = 32768
  end
  config.disksize.size = '200GB'  # requires 'vagrant plugin install vagrant-disksize'

  config.vm.define "manetu" do |node|
    node.vm.hostname = "manetu"
    node.vm.network "private_network", ip: "192.168.34.11"
    node.vm.provision "ansible" do |ansible|
      ansible.playbook = "ansible/deploy-demo.yml"
      ansible.extra_vars = "ansible/profiles/dev.yml"
      ansible.skip_tags = "upgrade"
      ansible.groups = {
        "k3s_primary" => ["manetu"],
        "config_host" => ["manetu"]
      }
      ansible.host_vars = {
        "manetu" => {
          "manetu_registry_username" => ENV['REGCRED_USER'],
          "manetu_registry_password" => ENV['REGCRED_PASSWORD'],
          "manetu_dns" => "manetu.192-168-34-11.sslip.io",
          "k3s_token" => "password",
          "k3s_external_ip" => "192.168.34.11",
          "cassandra_password" => "password",
          "cassandra_tls_store" => "password",
          "yugabyte_password" => "password",
          "minio_password" => "password",
          "mgmt_admin_password" => "password",
          "prsk_password" => "password",
          "manetu_platform_operator_email" => "admin@demo",
          "manetu_platform_operator_password" => "password"
        }
      }
    end
  end
end
