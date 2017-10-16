#!/bin/bash

export SCRIPT=$(readlink -f "$0")
export SCRIPTPATH=$(dirname "$SCRIPT")

export LOG_FILE="/tmp/bosh_deploy.log"

set -e

export MANIFEST_FILE=${MANIFEST_FILE:-$WORKSPACE/bosh-solace-manifest.yml}

export GEN_NEW_MANIFEST_FILE=true
export INTERACTIVE=false

export TILE_METADATA_FILE=${TILE_METADATA_MANIFEST_FILE:-$WORKSPACE/metadata/solace-messaging.yml}

## Default using Evaluation edition
export EDITION_OPT="evaluation"

export CMD_NAME=`basename $0`
export BASIC_USAGE="usage: $CMD_NAME [-m MANIFEST_FILE][-c CI_CONFIG_FILE][-i][-h]"

function showUsage() {
    read -r -d '\0' USAGE_DESCRIPTION << EOM
$BASIC_USAGE

Deploy BOSH VMRs.

Default: A basic bosh-lite manifest will be generated and deployed with 1 instance of Shared-VMR, the service broker will be installed.

Note 1: the -i option does nothing if -m or -c is given
Note 2: the -m and -c options cannot be used simultaneously

optional arguments:
  -e    Indicates to use the enterprise edition
  -m MANIFEST_FILE
        Manifest that will be deployed
  -c CI_CONFIG_FILE
        A Concourse property file from which a new bosh-manifest will be generated
  -i    Will be prompted to interactively provide options to generate a bosh-lite manifest
  -h    Show this help message and exit
\0
EOM
    echo "$USAGE_DESCRIPTION"
}

while getopts :m:ec:ih opt; do
    case $opt in
        e) 
	    EDITION_OPT="enterprise"
	    echo "Using VMR Enterprise Edition"
	    ;;
        m)
            EXISTING_MANIFEST_FILE="$OPTARG"
            echo "Will use bosh-lite manifest file $EXISTING_MANIFEST_FILE"
	    echo "With VMR Enterprise: $EDITION_OPT"
            if ! [ "$EXISTING_MANIFEST_FILE" -ef "$MANIFEST_FILE" ]; then
                cp $EXISTING_MANIFEST_FILE $MANIFEST_FILE
                echo "Copied $EXISTING_MANIFEST_FILE to $MANIFEST_FILE"
            fi
            echo
            GEN_NEW_MANIFEST_FILE=false
	    ;;
        c)
            CI_CONFIG_FILE="$OPTARG"
            echo "Will convert CI-config file to bosh-lite manifest file:"
            echo "    Input CI-Config:      $OPTARG"
            echo "    Output Bosh Manifest: $MANIFEST_FILE"
            $SCRIPTPATH/parser/converter.py --edition="$EDITION_OPT" --in-file="$CI_CONFIG_FILE" --in-meta-file=$TILE_METADATA_FILE --out-file="$MANIFEST_FILE"
            echo
            GEN_NEW_MANIFEST_FILE=false
	    ;;
        i)  INTERACTIVE=true
	    ;;
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
exit 1
$SCRIPTPATH/pcf_prepare.sh
echo
$SCRIPTPATH/optimizeManifest.py $MANIFEST_FILE
echo
$SCRIPTPATH/deployBoshManifest.sh $MANIFEST_FILE
