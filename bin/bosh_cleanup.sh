#!/bin/bash

export SCRIPT=$(readlink -f "$0")
export SCRIPTPATH=$(dirname "$SCRIPT")

export LOG_FILE="/tmp/bosh_cleanup.log"

set -e

CMD_NAME=`basename $0`
BASIC_USAGE="usage: $CMD_NAME [-h]"

function showUsage() {
    read -r -d '\0' USAGE_DESCRIPTION << EOM
$BASIC_USAGE

Cleanup the entire bosh deployment and update the service-broker app's environment.

optional arguments:
  -h            show this help message and exit
\0
EOM
    echo "$USAGE_DESCRIPTION"
}

while getopts ":h" arg; do
    case "$arg" in
        h) showHelp && exit 0;;
        \?)
            echo $BASIC_USAGE
            >&2 echo "Found bad option: -$OPTARG"
            exit 1;;
    esac
done

$SCRIPTPATH/teardownBoshDeployment.sh
$SCRIPTPATH/updateServiceBrokerAppEnvironment.sh -r
