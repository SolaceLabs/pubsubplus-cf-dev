#!/bin/bash

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

source $SCRIPTPATH/cf-common.sh

## Enable or Disable exit on error
set -e
lookupServiceBrokerDetails

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

## TODO: If SB not found, install....

cf bind-service $SB_APP solace_messaging-p-mysql


