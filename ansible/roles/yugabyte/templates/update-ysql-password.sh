#!/bin/bash

export SSL_CERTFILE=/home/yugabyte/cert-manager/ca.crt

DEFAULTPASSFILE=$(mktemp)
UPDATEDPASSFILE=$(mktemp)

clean_up () {
    ARG=$?
    rm $DEFAULTPASSFILE $UPDATEDPASSFILE
    exit $ARG
} 
trap clean_up EXIT

echo "localhost:5433:*:yugabyte:yugabyte" > $DEFAULTPASSFILE
echo "localhost:5433:*:yugabyte:$1" > $UPDATEDPASSFILE

function invoke {
    PGPASSFILE=$1 ysqlsh -U yugabyte -c "$2"
}

function check_connection {
    invoke $1 "\dt" 2>&1 > /dev/nul
}

check_connection $UPDATEDPASSFILE
if [  $? == 0 ]; then
    echo "Success: password is already updated"
    exit 2
fi

check_connection $DEFAULTPASSFILE
if [  $? != 0 ]; then
    echo "Error: Failure to connect"
    exit 1
fi

invoke $DEFAULTPASSFILE "ALTER ROLE yugabyte PASSWORD '$1' ;"
if [  $? == 0 ]; then
    echo "Success: password was updated"
    exit 0
else
    echo "Error: unknown failure updating password"
    exit $?
fi
