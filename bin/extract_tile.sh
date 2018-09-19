#!/bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKSPACE=${WORKSPACE:-$SCRIPTPATH/../workspace}

source $SCRIPTPATH/common.sh

export CMD_NAME=`basename $0`

export BASIC_USAGE_PARAMS="-t solace-pubsub*.pivotal "

export TEMP_DIR=$(mktemp -d)

function cleanupTemp() {
 if [ -d $TEMP_DIR ]; then
    rm -rf $TEMP_DIR
 fi
}
trap cleanupTemp EXIT INT TERM HUP

function showUsage() {
  echo
  echo "Usage: $CMD_NAME $BASIC_USAGE_PARAMS " $1
  echo
}

function missingRequired() {
  echo
  echo "Some required argument(s) were missing."
  echo 

  showUsage
  exit 1
}

if (($# == 0)); then
  missingRequired
fi

while getopts :t:h opt; do
    case $opt in
      t)
        export TILE_FILE=$OPTARG
      ;;
      h)
        showUsage
        exit 0
      ;;
      \?)
      echo
      echo "Invalid option: -$OPTARG" >&2
      echo
      showUsage
      exit 1
      ;;
      :)
      echo
      echo "Option -$OPTARG requires an argument." >&2
      echo
      case $OPTARG in
          A)
    	    showUsage "$OPTIONAL_USAGE_PARAMS"
          ;;
          N)
            showUsage "$OPTIONAL_USAGE_PARAMS"
          ;;
          \?)
            showUsage
          ;;
      esac
      exit 1
      ;;
  esac
done

missing_required=0

if [ -z $TILE_FILE ]; then
   echo
   echo "A Tile file name is missing"
   missing_required=1;
fi

if [ ! -f $TILE_FILE ]; then
   echo
   echo "The tile file $TILE_FILE does not exist?!"
   missing_required=1;
fi

## Derived values

export TILE_VERSION=$( basename $TILE_FILE | sed 's/solace-pubsub-//g' | sed 's/-enterprise//g' | sed 's/\.pivotal//g' | sed 's/\[.*\]//' )
export TEMPLATE_VERSION=$( echo $TILE_VERSION | awk -F\- '{ print $1 }' )
export TEMPLATE_DIR=${TEMPLATE_DIR:-$SCRIPTPATH/../templates/$TEMPLATE_VERSION}

export WORKSPACE=${WORKSPACE-`pwd`}

if ((missing_required)); then
   missingRequired
fi

if [ ! -d $TEMPLATE_DIR ]; then
   echo "There doesn't seem to be any templates for this version $TILE_VERSION expected in $TEMPLATE_DIR"
   exit 1
fi

export TEMPLATE_DIR="$( cd $TEMPLATE_DIR && pwd )"

echo "TILE_FILE         $TILE_FILE"
echo "TILE_VERSION      $TILE_VERSION"
echo "TEMPLATE_DIR      $TEMPLATE_DIR"

echo "Extracting contents to $WORKSPACE/releases"

if [ -d $WORKSPACE/releases ]; then
 echo "Clean up of old releases"
 rm -rf $WORKSPACE/releases
fi

unzip -o -d $WORKSPACE $TILE_FILE releases/*.tgz 

## Extract and show the Solace Service Broker version. 
(
 cd $TEMP_DIR
 tar -xzf $WORKSPACE/releases/solace-pubsub-broker-$TILE_VERSION.tgz
 tar -xzf packages/solace_pubsub_broker.tgz 
 cd ./solace_pubsub_broker/ 
 SOLACE_SERVICE_BROKER_VERSION=$(ls *.jar)
 echo " Found Solace Service Broker [ $SOLACE_SERVICE_BROKER_VERSION ]"
)

