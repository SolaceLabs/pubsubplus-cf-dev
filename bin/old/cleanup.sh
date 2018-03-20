#!/bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export WORKSPACE=${WORKSPACE:-"$HOME/workspace"}
mkdir -p $WORKSPACE
export LOG_FILE=${LOG_FILE:-"$WORKSPACE/cleanup.log"}

set -e

CMD_NAME=`basename $0`
BASIC_USAGE="usage: $CMD_NAME [-s][-h]"

function showUsage() {
    read -r -d '\0' USAGE_DESCRIPTION << EOM
$BASIC_USAGE

Cleanup the entire bosh deployment and uninstalls the service-broker.

optional arguments:
  -h            show this help message and exit
\0
EOM
    echo "$USAGE_DESCRIPTION"
}

while getopts ":h" arg; do
    case "$arg" in
        h)
            showUsage
            exit 0;;
        \?) echo $BASIC_USAGE && >&2 echo "Found bad option: -$OPTARG" && exit 1;;
        :) echo $BASIC_USAGE && >&2 echo "Missing argument for option: -$OPTARG" && exit 1;;
    esac
done

$SCRIPTPATH/cleanupBoshDeployment.sh
