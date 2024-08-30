set -e

export INSTALL_K3S_VERSION={{ k3s_version }}

curl -sfL https://get.k3s.io | sh -s - {{ k3s_role }} \
{%- if k3s_role == "server" and k3s_primary %}
   --cluster-init \
{% else %}
   --server=https://{{ k3s_primary_host }}:6443 \
{% endif -%}
   --token={{ k3s_token }} \
{% if not servicelb_enabled %}
   --disable servicelb \
{% endif -%}
   --disable traefik \
{% if not local_storage_enabled %}
   --disable local-storage \
{% endif -%}
   --disable-cloud-controller \
   --disable-helm-controller \
{% if k3s_cluster_enabled %}
   --flannel-backend=wireguard-native \
   --node-ip={{ ansible_ssh_host }} \
{% endif -%}
{% if k3s_external_ip %}
   --node-ip={{ k3s_external_ip }} \
   --node-external-ip={{ k3s_external_ip }} \
{% endif -%}
{% if k3s_cluster_iface %}
   --flannel-iface={{ k3s_cluster_iface }} \
{% endif -%}
   --cluster-cidr={{ k3s_cluster_cidr }} \
   --node-name=$(hostname -f) \
   --write-kubeconfig-mode=644
