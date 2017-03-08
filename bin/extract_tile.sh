#!/bin/bash

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

source $SCRIPTPATH/release-common.sh

export TEMP_DIR=$(mktemp -d)

export TILE_FILE_PATH=$(readlink -f "$TILE_FILE")
export WORKSPACE=$(dirname $TILE_FILE_PATH)

echo "Extracting contents to $WORKSPACE/releases"

unzip -d $WORKSPACE $TILE_FILE releases/*.tgz

( 
  cd $TEMP_DIR
  echo "Looking for $WORKSPACE/releases/solace-messaging-${TILE_VERSION}.tgz"
  tar -xzf $WORKSPACE/releases/solace-messaging-${TILE_VERSION}.tgz ./packages/solace_messaging.tgz 
  SB_JAR=$(tar -tzf ./packages/solace_messaging.tgz | grep jar)
  echo "Detected Solace Service Broker jar path $SB_JAR"
  tar -xOzf ./packages/solace_messaging.tgz $SB_JAR > $WORKSPACE/releases/solace-messaging.jar
  echo "Extracted Solace Service Broker to $WORKSPACE/releases/solace-messaging.jar"
  rm -f $WORKSPACE/releases/solace-messaging-${TILE_VERSION}.tgz
  echo
)

if [ -d $TEMP_DIR ]; then
   rm -rf $TEMP_DIR
fi

