#!/bin/sh

set -ex

{% if vault_devmode is sameas true %}

vault operator raft join http://vault-0.vault-internal:8200

{% else %}

vault operator raft join \
      -address https://vault-$1.vault-internal:8200 \
      -leader-ca-cert="$(cat /vault/userconfig/tls/ca.crt)" \
      -leader-client-cert="$(cat /vault/userconfig/tls/tls.crt)" \
      -leader-client-key="$(cat /vault/userconfig/tls/tls.key)" \
      https://vault-0.vault-internal:8200

{% endif %}
