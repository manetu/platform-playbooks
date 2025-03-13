#!/bin/bash

set -eu

#set -x

#GLOBALS
DIR=$1

# Pre-load envvars so we trip the unbounded variable error before encryption
registry_username=$REGCRED_USER
registry_password=$REGCRED_PASSWORD

while [ $# -gt 0 ]
do
    case "$1" in
        --debug)
            set -x
            ;;
    esac
    shift
done

pwgen! () {
    echo $(pwgen -s 64 1)
}

create_gitignore () {
    cat <<EOF
password
operator.key
EOF
    
}

create_passwords () {
    cat <<EOF
k3s_token: $(pwgen!)
cassandra_password: $(pwgen!)
cassandra_tls_store: $(pwgen!)
yugabyte_password: $(pwgen!)
temporal_elasticsearch_password: $(pwgen!)
minio_password: $(pwgen!)
longhorn_password: $(pwgen!)
mgmt_admin_password: $(pwgen!)
vault_operator_password: $(pwgen!)
prsk_password: $(pwgen!)
EOF
}

create_regcreds () {
    cat <<EOF
manetu_registry_username: $registry_username
manetu_registry_password: $registry_password
EOF
}

create_inventory () {
    cat <<EOF
all:
  vars:
    manetu_dns: manetu.example.com
    manetu_platform_version: 2.0.0-v2.0.0.b32.7524

config_host:
  hosts:
    localhost:
      ansible_connection: local
EOF
}

create_vars () {
    cat <<EOF
manetu_platform_operator_cert: $(cat $1 | base64)
EOF
}

if [ -d "$DIR" ]; then
    echo "ERROR: $DIR exists"
    exit -1
fi

PASSWORD=$(pwgen!)

mkdir -m 700 -p $DIR
create_gitignore > $DIR/.gitignore

touch $DIR/password $DIR/operator.key
chmod 600 $DIR/password $DIR/operator.key
echo $PASSWORD > $DIR/password

GROUP_VARS=$DIR/group_vars/all
mkdir -p $GROUP_VARS
create_passwords | ansible-vault encrypt --vault-id $DIR/password > $GROUP_VARS/passwords-vault.yml
create_regcreds | ansible-vault encrypt --vault-id $DIR/password > $GROUP_VARS/regcred-vault.yml

openssl ecparam -genkey -name prime256v1 -noout -out $DIR/operator.key
openssl req -new -x509 -key $DIR/operator.key -out $DIR/operator.cert -days 3600 -subj "/O=manetu.io"
openssl pkcs12 -password file:$DIR/password -export -inkey $DIR/operator.key -in $DIR/operator.cert -out $DIR/platform-operator-credentials.p12

create_vars $DIR/operator.cert > $GROUP_VARS/vars.yml
create_inventory > $DIR/inventory.yml

rm $DIR/operator.* $DIR/password

echo "Your inventory has been created at $DIR."
echo ""
echo "------------------------------------------------------------"
echo " Inventory Password: $PASSWORD"
echo ""
echo " Store it somewhere safe.  It will not be displayed again."
echo "------------------------------------------------------------"
