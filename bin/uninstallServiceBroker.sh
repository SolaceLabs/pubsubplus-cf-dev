#!/bin/bash

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

source $SCRIPTPATH/cf-common.sh

## Enable or Disable exit on error
set -e

pcfdev_login

FOUND_ORG=0
for ORG in $(cf orgs | grep -v "Getting" | grep -v "^name"); do
  if [ "$ORG" == "solace" ]; then
      FOUND_ORG=1
   fi
done

if [ "$FOUND_ORG" -eq "0" ]; then
  echo "solace org was not found, no Service Broker to uninstall"
  exit 1
fi

switchToOrgAndSpace $SB_ORG $SB_SPACE

lookupServiceBrokerDetails

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

export SOLACE_MESSAGING_FOUND=$( cf m | grep -v Getting | grep solace-messaging | wc -l )

if [ "$SOLACE_MESSAGING_FOUND" -eq "1" ]; then
  cf delete-service-broker -f solace-messaging 
fi

if [ $SB_FOUND -eq "1" ]; then
  echo "Stopping the Solace Service Broker"
  cf stop $SB_APP
  cf delete -f $SB_APP
fi

cf delete-org -f $SB_ORG

echo "Service broker is uninstalled, solace-messaging is no longer available as a service."

