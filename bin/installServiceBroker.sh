#!/bin/bash

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

source $SCRIPTPATH/cf-common.sh

export SB_JAR=$WORKSPACE/releases/solace-messaging.jar

export SOLACE_VMR_BOSH_RELEASE_FILE=$(ls $WORKSPACE/releases/solace-vmr-*.tgz | tail -1)
export SOLACE_VMR_BOSH_RELEASE_VERSION=$(basename $SOLACE_VMR_BOSH_RELEASE_FILE | sed 's/solace-vmr-//g' | sed 's/.tgz//g' | awk -F\- '{ print $1 }' )

## Use a specific manifest that matches the tile version.
export SB_MANIFEST=$SCRIPTPATH/../templates/$SOLACE_VMR_BOSH_RELEASE_VERSION/service-broker-manifest.yml

## Check we have the files..

if [ ! -f $SB_JAR ]; then
   echo "Service broker jar seems to be missing $SB_JAR"
   exit 1
fi

if [ ! -f $SB_MANIFEST ]; then
   echo "Service broker pcf-dev deployment manifest seems to be missing $SB_MANIFEST"
   exit 1
fi

export SECURITY_USER_NAME=$( cat $SB_MANIFEST  | grep SECURITY_USER_NAME | sed 's/ //g' | awk -F\: '{ print $2 }' )
export SECURITY_USER_PASSWORD=$( cat $SB_MANIFEST  | grep SECURITY_USER_PASSWORD | sed 's/ //g' | awk -F\: '{ print $2 }' )

## Enable or Disable exit on error
set -e

pcfdev_login

switchToOrgAndSpace $SB_ORG $SB_SPACE

lookupServiceBrokerDetails

if [ $SB_RUNNING -eq "0" ]; then
   cf push -p $SB_JAR -f $SB_MANIFEST 
   lookupServiceBrokerDetails
fi

if [ $SB_RUNNING -eq "0" ]; then
   echo "Service broker should running and should be found, something is wrong..."
   exit 1
fi

FIRST_FREE_PLAN=`cf marketplace -s p-mysql | grep -v "service plan" | grep free | head -1 | awk '{ print $1 }'`
IS_512MB_FOUND=`cf marketplace -s p-mysql | grep -v "service plan" | grep free | grep 512mb | wc -l`
IS_100MB_FOUND=`cf marketplace -s p-mysql | grep -v "service plan" | grep free | grep 100mb | wc -l`

echo "First free Plan: $FIRST_FREE_PLAN"
echo "Found 512mb ?: $IS_512MB_FOUND"
echo "Found 100mb ?: $IS_100MB_FOUND"

if [ -z $PLAN ] && [ "$IS_100MB_FOUND" -eq "1" ]; then
   PLAN=100mb
fi

if [ -z $PLAN ] && [ "$IS_512MB_FOUND" -eq "1" ]; then
   PLAN=512mb
fi
 
if [ -z $PLAN ] && [ ! -z $FIRST_FREE_PLAN ]; then
   PLAN=$FIRST_FREE_PLAN
fi

if [ -z $PLAN ]; then
  echo "Unable to locate a suitable p-mysql plan"
  cf m
  exit 1
fi

echo "Chosen plan $PLAN"

FOUND_BINDING=`cf services | grep solace_messaging-p-mysql | grep solace-messaging | wc -l`
if [ "$FOUND_BINDING" -eq "1" ]; then
   echo "Found binding, will unbind solace-messaging solace_messaging-p-mysql"
   cf unbind-service $SB_APP solace_messaging-p-mysql
fi

FOUND_SERVICE=`cf services | grep solace_messaging-p-mysql | wc -l`
if [ "$FOUND_SERVICE" -eq "1" ]; then
  echo "Found service, will delete-service solace_messaging-p-mysql"
  cf delete-service -f solace_messaging-p-mysql
fi

cf create-service p-mysql $PLAN solace_messaging-p-mysql

cf bind-service $SB_APP solace_messaging-p-mysql

cf restage $SB_APP

## Install solace-messaging as a service if not found in the marketplace

export SOLACE_MESSAGING_FOUND=$( cf m | grep -v Getting | grep solace-messaging | wc -l )

if [ "$SOLACE_MESSAGING_FOUND" -eq "0" ]; then
  cf create-service-broker solace-messaging $SECURITY_USER_NAME $SECURITY_USER_PASSWORD https://solace-messaging.local.pcfdev.io
  cf enable-service-access solace-messaging
fi

echo "Service broker is installed and solace-messaging is now a service"

cf marketplace

