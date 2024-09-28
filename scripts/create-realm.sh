#!/bin/bash

set -eu

#set -x

#GLOBALS
ID="piedpiper"
NAME="Pied Piper"

while [ $# -gt 0 ]
do
    case "$1" in
        --debug)
            set -x
            ;;
        --id)
            ID="$2"
            ;;
        --name)
            NAME="$2"
            ;;
        --inventory)
            INVENTORY="$2"
            ;;
    esac
    shift
done

pwgen! () {
    echo $(pwgen -s 32 1)
}


PASSWORD=$(pwgen!)

export MANETU_TOKEN=$(manetu-security-token login --insecure pem --path --p12 $INVENTORY/platform-operator-credentials.p12 --password $INVENTORY_PASSWORD)

echo "Creating realm $ID ($NAME) on $MANETU_URL"

cat <<EOF | yq -r -o=json - | curl --insecure --data-binary @- --silent --show-error --fail --header 'Content-Type: application/json' --header "Authorization: Bearer $MANETU_TOKEN" $MANETU_URL/graphql | jq
query: |
  mutation {
    create_realm(
      id: "$ID",
      iam_admin_password: "$PASSWORD",
      data: { name: "$NAME" }
    )
  }
EOF

if [ $? -eq 0 ]; then
  echo "Your realm has been created."
  echo ""
  echo "------------------------------------------------------------"
  echo " Administrator Password: $PASSWORD"
  echo ""
  echo " Store it somewhere safe.  It will not be displayed again."
  echo "------------------------------------------------------------"
fi
