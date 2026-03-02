set -e
export INSTALL_K3S_VERSION={{ k3s_version }}
curl -sfL https://get.k3s.io | sh -s -
