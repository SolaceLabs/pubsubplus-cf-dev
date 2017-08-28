#!/bin/bash

export SCRIPT=$(readlink -f "$0")
export SCRIPTPATH=$(dirname "$SCRIPT")

export LOG_FILE="/tmp/bosh_deploy.log"

set -e

export MANIFEST_FILE=${MANIFEST_FILE:-$WORKSPACE/bosh-solace-manifest.yml}
GEN_NEW_MANIFEST_FILE=true
INTERACTIVE=false
INSTALL_BROKER=false

CMD_NAME=`basename $0`
BASIC_USAGE="usage: $CMD_NAME [-m MANIFEST_FILE][-c CI_CONFIG_FILE][-i][-s][-h]"

function showUsage() {
    read -r -d '\0' USAGE_DESCRIPTION << EOM
$BASIC_USAGE

Deploy BOSH VMRs.

Default: A basic bosh-lite manifest will be generated and deployed with 1 instance of Shared-VMR

Note 1: the -i option does nothing if -m or -c is given
Note 2: the -m and -c options cannot be used simultaneously

optional arguments:
  -m MANIFEST_FILE
        Manifest that will be deployed
  -c CI_CONFIG_FILE
        A Concourse property file from which a new bosh-manifest will be generated
  -i    Will be prompted to interactively provide options to generate a bosh-lite manifest
  -s    Install the service broker after the deployment is finished
  -h    Show this help message and exit
\0
EOM
    echo "$USAGE_DESCRIPTION"
}

while getopts :m:c:ish opt; do
    case $opt in
        m)
            EXISTING_MANIFEST_FILE="$OPTARG"
            echo "Will use bosh-lite manifest file $EXISTING_MANIFEST_FILE"
            if ! [ "$EXISTING_MANIFEST_FILE" -ef "$MANIFEST_FILE" ]; then
                cp $EXISTING_MANIFEST_FILE $MANIFEST_FILE
                echo "Copied $EXISTING_MANIFEST_FILE to $MANIFEST_FILE"
            fi
            echo
            GEN_NEW_MANIFEST_FILE=false;;
        c)
            CI_CONFIG_FILE="$OPTARG"
            echo "Will convert CI-config file to bosh-lite manifest file:"
            echo "    Input CI-Config:      $OPTARG"
            echo "    Output Bosh Manifest: $MANIFEST_FILE"
            $SCRIPTPATH/parser/converter.py --in-file="$CI_CONFIG_FILE" --out-file="$MANIFEST_FILE"
            echo
            GEN_NEW_MANIFEST_FILE=false;;
        i)  INTERACTIVE=true;;
        s)  INSTALL_BROKER=true;;
        h)
            showUsage
            exit 0;;
        \?) echo $BASIC_USAGE && >&2 echo "Found bad option: -$OPTARG" && exit 1;;
        :) echo $BASIC_USAGE && >&2 echo "Missing argument for option: -$OPTARG" && exit 1;;
    esac
done

if [ -n "$EXISTING_MANIFEST_FILE" ] && [ -n "$CI_CONFIG_FILE" ]; then
    showUsage
    >&2 echo "The -m and -c options cannot be used simultaneously"
    exit 1
fi

if $GEN_NEW_MANIFEST_FILE; then
    echo "A new manifest will be generated..."
    echo
    $INTERACTIVE && $SCRIPTPATH/generateBoshManifest.py -h && echo
    echo "MANIFEST_FILE set to $MANIFEST_FILE"
    echo

    if $INTERACTIVE; then
        read -p "Please indicate the options that will be used to generate this manifest (Will proceed with the default settings if none provided): generateBoshManifest.py " MANIFEST_GEN_OPTS
    else
        echo "-i option was not given, manifest will be generated using default settings..."
    fi

    echo
    $SCRIPTPATH/generateBoshManifest.py $MANIFEST_GEN_OPTS
    echo
fi

$SCRIPTPATH/deployBoshManifest.sh $MANIFEST_FILE
echo
$INSTALL_BROKER && $SCRIPTPATH/installServiceBroker.sh
echo
$SCRIPTPATH/updateServiceBrokerAppEnvironment.sh
