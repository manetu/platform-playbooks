#!/bin/bash

export SSL_CERTFILE=/home/yugabyte/cert-manager/ca.crt

newpassword=$1

function invoke {
    ycqlsh --ssl yugabyte-yb-tservers -u cassandra -p $1 -e "$2"
}

function check_connection {
    invoke $1 "DESC KEYSPACES;" 2>&1 > /dev/nul
}

check_connection $newpassword
if [  $? == 0 ]; then
    echo "Success: password is already updated"
    exit 2
fi

check_connection "cassandra"
if [  $? != 0 ]; then
    echo "Error: Failure to connect"
    exit 1
fi

invoke "cassandra" "ALTER ROLE 'cassandra' WITH PASSWORD = '$newpassword' ;"
if [  $? == 0 ]; then
    echo "Success: password was updated"
    exit 0
else
    echo "Error: unknown failure updating password"
    exit $?
fi
