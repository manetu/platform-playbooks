# Hashicorp Vault Integration Requirements for Manetu

## Introduction

The Manetu Platform optionally leverages Hashicorp Vault to add additional security.  Manetu has a critical secret known as the Platform Root Sealing Key (PRSK), which is used to boot-strap its distributed Secure Enclave network.  The PRSK is always minimally protected by a Password-Based Key Derivation Function (PBKDF).  It may also be optionally protected by a Hashicorp Vault [Transit Engine](https://developer.hashicorp.com/vault/docs/secrets/transit).  

Using a PBKDF and Transit Engine together allows for multi-lateral protection of the PRSK secret, wherein control of the PBKDF password and Shamir-Shares for the Transit Engine can be split over multiple SecOps personnel.  Security is further enhanced by logical partitioning of PBKDF and Transit Engine functions by separating processes and policies restricting access to the Transit Engine exclusively to the Manetu Root Sealing Key Manager (RSKM).  For these reasons, production instances of Manetu are encouraged to leverage a Hashicorp Vault-based configuration wherever practical.

This document outlines the requirements for deployments in which the environment outside Manetu control provides the Hashicorp Vault instance.  The steps outlined below are handled automatically for deployments that leverage a Manetu-managed Vault instance.

## Requirements

It is assumed that the provided Hashicorp Vault instance is generally configured following all [best practices for production hardening](https://developer.hashicorp.com/vault/tutorials/operations/production-hardening).  It is additionally recommended that [Shamir's Secret Sharing via PGP](https://developer.hashicorp.com/vault/tutorials/operations/pgp-encrypted-key-shares) be used.

The setup of Hashicorp Vault specific for Manetu use as a PRSK protection layer involves the following additional steps:

1.  Provisioning a Transit Engine dedicated to a specific Manetu instance.

    a.  Default path is "rskm/"

    b.  Can be prefixed to support multiple instances e.g. "manetu/us-east-2/rskm".

2.  Installing an Vault Role and accompanying HCL policy with the following properties:

    a.  Grants exclusive "update" access to the Transit Engine in (1) to the identity established in (3) representing the RSKM.

    b.  Denies all other identities and operations, including privileged human operators.

3.  Establish an [authentication method](https://developer.hashicorp.com/vault/docs/auth) that is suitable for verifying the identity of the Manetu Root-Sealing-Key-Manager instance running in Kubernetes

    a.  Manetu supports the [Kubernetes](https://developer.hashicorp.com/vault/docs/auth/kubernetes) and [Token](https://developer.hashicorp.com/vault/docs/auth/token) Auth Methods

4.  Deploy a Kubernetes ConfigMap into the Manetu Namespace that configures Manetu's Vault client to connect with your Vault instance.

### Transit Engine Provisioning

The following steps must be performed once by a privileged user.

```
##### Secrets Engines

vault secrets enable -path=rskm/ transit

##### Create PRSK outer encryption key

vault write rskm/keys/prsk-wrapper dervived=false exportable=false allow_plaintext_backup=false type=aes256-gcm96
```

### Vault Role

Create a new role "rskm" in Vault

```
vault policy write rskm rskm.hcl
```

Where the policy definition  is:

```
# Root Sealing-Key Manager access to Transit Engine

path "rskm/*" {

capabilities = ["update"]

}
```

### Authentication Methods

An identity for the RSKM must be established within Vault using a supported method (Token or Kubernetes).  

#### Kubernetes Auth Method

The following steps may be applied assuming Manetu is installed in the default namespace location:

```
##### K8s Auth

vault auth enable kubernetes

vault write auth/kubernetes/role/rskm bound_service_account_names=mcp-keycustodian-service-rskm* bound_service_account_namespaces=manetu-platform policies=rskm ttl=1h

vault write auth/kubernetes/config kubernetes_host="https://kubernetes.default:443" kubernetes_ca_cert="$K8S_CA_CERT"
```

### Configure Manetu

You must install a Kubernetes Config Map in the Manetu namespace (defaults to "manetu-platform") named "vault-config" that adheres to the following:

The supported variables are as follows:

-   **VAULT_ADDR**: The URL to your vault instance

-   **VAULT_TLS_ENABLED**: Boolean "true" or "false" depending on whether TLS is enabled in your instance.  

-   **VAULT_CACERT**: A base64+PEM encoded CA certificate for the Vault instance TLS when TLS is enabled and the CA is not part of a public PKI

-   **VAULT_KEYSPACE** (default: nil): Optional path prefix for Transit Engine mount-point

    -   For cases where the Vault instance is shared with multiple Manetu instances, multiple Transit Engines will need to be provisioned.  The KEYSPACE mechanism allows the Vault Admin to mount the Transit Engine with arbitrary hierarchy.

    -   Example: for a Transit Engine mounted to "manetu/us-east-2/rskm", the KEYSPACE would be "manetu/us-east-2".

-   **VAULT_AUTHMOD**E (default "k8s"): Supports the following options

    -   _k8s_: Uses the [Kubernetes Auth Method](https://developer.hashicorp.com/vault/docs/auth/kubernetes) to authenticate to Vault.  See VAULT_K8S_ROLE and K8s_TOKEN_PATH for further configuration.

    -   _token_: Uses the [Token Auth Method](https://developer.hashicorp.com/vault/docs/auth/token) to authenticate to Vault.   This method also requires injecting a VAULT_TOKEN variable via a Secret that is not yet fully supported but can be added upon request.

-   **VAULT_K8S_ROLE** (default "rskm"): Must match the role provisioned in Vault.

-   **K8S_TOKEN_PATH** (default: "/var/run/secrets/kubernetes.io/serviceaccount/token"): The path to the Kubernetes Service Account JWT.

-   **VAULT_PATH_PREFIX** (default: "rskm"): The prefix for the Transit Engine after the KEYSPACE prefix.

    -   For a Transit Engine mounted at "manetu/us-east-2/rskm", The KEYSPACE is "manetu/us-east-2" and the PATH_PREFIX is "rskm".

#### Example

```
apiVersion: v1
kind: ConfigMap
metadata:
  name: vault-config
  namespace: manetu-platform
data:
  VAULT_ADDR: https://vault.manetu-hashicorp:8200
  VAULT_CACERT: LS0tLS1CRUdJT..0tCg==
  VAULT_TLS_ENABLED: "true"
```
