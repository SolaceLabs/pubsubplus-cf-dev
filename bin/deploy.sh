#!/bin/bash

export SCRIPT=$(readlink -f "$0")
export SCRIPTPATH=$(dirname "$SCRIPT")

export LOG_FILE="/tmp/bosh_deploy.log"

set -e

GEN_NEW_MANIFEST_FILE=0
MANIFEST_FILE=${MANIFEST_FILE:-$WORKSPACE/bosh-solace-manifest.yml}
INSTALL_BROKER=1

CMD_NAME=`basename $0`
BASIC_USAGE="usage: $CMD_NAME [-m MANIFEST_FILE][-c CI_CONFIG_FILE][-s][-h]"

function showUsage() {
    read -r -d '\0' USAGE_DESCRIPTION << EOM
$BASIC_USAGE

Deploy BOSH VMRs.
Omitting -m and -c will execute a basic bosh-manifest generator.

Note: the -m and -c options cannot be used simultaneously.

optional arguments:
  -m MANIFEST_FILE
        Manifest that will be deployed
  -c CI_CONFIG_FILE
        A Concourse property file from which a new bosh-manifest will be generated
  -s    Install the service broker after the deployment is finished
  -h    Show this help message and exit
\0
EOM
    echo "$USAGE_DESCRIPTION"
}

while getopts :m:c:sh opt; do
    case $opt in
        m)
            EXISTING_MANIFEST_FILE="$OPTARG"
            echo "Will use bosh-lite manifest file $EXISTING_MANIFEST_FILE"
            cp $EXISTING_MANIFEST_FILE $MANIFEST_FILE
            echo "Copied $EXISTING_MANIFEST_FILE to $MANIFEST_FILE"
            echo
            GEN_NEW_MANIFEST_FILE=1;;
        c)
            CI_CONFIG_FILE="$OPTARG"
            echo "Will convert CI-config file, $OPTARG , to bosh-lite manifest file, $MANIFEST_FILE"
            $SCRIPTPATH/parser/converter.py --in-file="$CI_CONFIG_FILE" --out-file="$MANIFEST_FILE"
            echo
            GEN_NEW_MANIFEST_FILE=1;;
        s) INSTALL_BROKER=0;;
        h)
            showUsage
            exit 0;;
        \?)
            echo $BASIC_USAGE
            >&2 echo "Found bad option: -$OPTARG"
            exit 1;;
    esac
done

if [ -n "$EXISTING_MANIFEST_FILE" ] && [ -n "$CI_CONFIG_FILE" ]; then
    >&2 echo "The -m and -c options cannot be used simultaneously"
    exit 1
fi

if [ "$GEN_NEW_MANIFEST_FILE" -eq "0" ]; then
    echo "A new manifest will be generated..."
    echo
    $SCRIPTPATH/generateBoshManifest.py -h
    echo
    echo "MANIFEST_FILE set to $MANIFEST_FILE"
    echo
    read -p "Please indicate the options that will be used to generate this manifest (Will proceed with the default settings if none provided): " MANIFEST_GEN_OPTS
    echo
    $SCRIPTPATH/generateBoshManifest.py $MANIFEST_GEN_OPTS
    echo
fi

$SCRIPTPATH/optimizeManifest.py $MANIFEST_FILE
echo
$SCRIPTPATH/deployBoshManifest.sh $MANIFEST_FILE
echo

if [ "$INSTALL_BROKER" -eq "0" ]; then
    $SCRIPTPATH/installServiceBroker.sh
fi

echo
$SCRIPTPATH/updateServiceBrokerAppEnvironment.sh
