#!/bin/bash

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

source $SCRIPTPATH/cf-common.sh
source $SCRIPTPATH/bosh-common.sh

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
  echo "solace org was not found, no Service Broker to uninstall?!"
  exit 1
fi

switchToOrgAndSpace $SB_ORG $SB_SPACE

getServiceBrokerDetails

if [ "$SB_RUNNING" -eq "1" ]; then
   echo "Service broker is running $SB_APP, will be uninstalled"
fi

DEPLOYMENT_FOUND_COUNT=`bosh deployments | grep $DEPLOYMENT_NAME | wc -l`
SOLACE_VMR_RELEASE_FOUND_COUNT=`bosh releases | grep solace-vmr | wc -l`
SOLACE_MESSAGING_RELEASE_FOUND_COUNT=`bosh releases | grep solace-messaging | wc -l`

if [ "$DEPLOYMENT_FOUND_COUNT" -eq "1" ]; then
   runDeleteAllErrand
else
  if [ "$SB_FOUND" -eq "1" ]; then
	  echo "It seems the bosh deployment is not present, will manually delete the service broker $SB_APP"
	  cf delete -f $SB_APP
	  cf delete-service -f solace_messaging-p-mysql
	  cf delete-service-broker -f solace-messaging
	  cf delete-org -f $SB_ORG
  fi
fi

echo "Service broker is uninstalled, solace-messaging is no longer available as a service."
