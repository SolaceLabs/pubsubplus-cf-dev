#!/bin/bash

export SCRIPT=$(readlink -f "$0")
export SCRIPTPATH=$(dirname "$SCRIPT")

export LOG_FILE="/tmp/bosh_cleanup.log"

set -e

UNINSTALL_BROKER=1
CMD_NAME=`basename $0`
BASIC_USAGE="usage: $CMD_NAME [-s][-h]"

function showUsage() {
    read -r -d '\0' USAGE_DESCRIPTION << EOM
$BASIC_USAGE

Cleanup the entire bosh deployment and update the service-broker app's environment.

optional arguments:
  -s            uninstall the service broker after deployment cleanup
  -h            show this help message and exit
\0
EOM
    echo "$USAGE_DESCRIPTION"
}

while getopts ":sh" arg; do
    case "$arg" in
        s) UNINSTALL_BROKER=0;;
        h)
            showUsage
            exit 0;;
        \?)
            echo $BASIC_USAGE
            >&2 echo "Found bad option: -$OPTARG"
            exit 1;;
    esac
done

$SCRIPTPATH/cleanupBoshDeployment.sh

if [ "$UNINSTALL_BROKER" -eq "0" ]; then
    $SCRIPTPATH/uninstallServiceBroker.sh
else
    $SCRIPTPATH/updateServiceBrokerAppEnvironment.sh -r
fi
