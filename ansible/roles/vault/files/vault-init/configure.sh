#!/bin/sh

set -ex

export SCRIPT_PATH=$(dirname $0)
export VAULT_TOKEN=${1:-root}
export VAULT_DEVMODE=$2
export K8S_CA_CERT=$3
export VAULT_OPERATOR_PASSWORD=$4

if [ $VAULT_DEVMODE == "true" ]; then
    export VAULT_ADDR=http://localhost:8200
else
    export VAULT_ADDR=https://localhost:8200
    export VAULT_CACERT=/vault/userconfig/tls/ca.crt
    export VAULT_TLSCERT=/vault/userconfig/tls/tls.crt
    export VAULT_TLSKEY=/vault/userconfig/tls/tls.key
fi                                                

echo "Executing from $SCRIPT_PATH"

##### Secrets Engines
vault secrets enable -path=rskm/ transit

##### Create PRSK outer encryption key
vault write rskm/keys/prsk-wrapper dervived=false exportable=false allow_plaintext_backup=false type=aes256-gcm96

##### Policy
vault policy write rskm         $SCRIPT_PATH/policy/rskm.hcl
vault policy write prometheus-metrics $SCRIPT_PATH/policy/prometheus-metrics.hcl
vault policy write seal-unseal $SCRIPT_PATH/policy/seal-unseal.hcl

##### K8s Auth
vault auth enable kubernetes
vault write auth/kubernetes/role/rskm bound_service_account_names=mcp-keycustodian-service-rskm* bound_service_account_namespaces=* policies=rskm ttl=1h
vault write auth/kubernetes/config kubernetes_host="https://kubernetes.default:443" kubernetes_ca_cert="$K8S_CA_CERT"

##### Vault Auth
vault auth enable -path="vault-manage" userpass
vault write auth/vault-manage/users/vault-operator password="$VAULT_OPERATOR_PASSWORD" policies="seal-unseal"