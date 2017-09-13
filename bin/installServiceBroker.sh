#!/bin/bash

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

source $SCRIPTPATH/bosh-common.sh

source $SCRIPTPATH/cf-common.sh

export SOLACE_MESSAGING_BOSH_RELEASE_FILE=$(ls $WORKSPACE/releases/solace-messaging-*.tgz | tail -1)

if [ ! -f $SOLACE_VMR_BOSH_RELEASE_FILE ]; then
   echo "Solace VMR Messaging Release file seems to be missing - expected in $WORKSPACE/releases/solace-vmr-*.tgz"
   exit 1
fi
export SOLACE_MESSAGING_BOSH_RELEASE_VERSION=$(basename $SOLACE_MESSAGING_BOSH_RELEASE_FILE | sed 's/solace-messaging-//g' | sed 's/.tgz//g' | awk -F\- '{ print $1 }' )

export SOLACE_VMR_BOSH_RELEASE_FILE=$(ls $WORKSPACE/releases/solace-vmr-*.tgz | tail -1)

if [ ! -f $SOLACE_VMR_BOSH_RELEASE_FILE ]; then
   echo "Solace VMR BOSH Release file seems to be missing - expected in $WORKSPACE/releases/solace-vmr-*.tgz"
   exit 1
fi

export SOLACE_VMR_BOSH_RELEASE_VERSION=$(basename $SOLACE_VMR_BOSH_RELEASE_FILE | sed 's/solace-vmr-//g' | sed 's/.tgz//g' | awk -F\- '{ print $1 }' )

pcfdev_login

getServiceBrokerDetails

if [ "$SB_RUNNING" -eq "1" ]; then
   echo "FYI: Service broker is running, running deploy-all will update the service broker with any changes from bosh manifest"
fi

runDeployAllErrand

getServiceBrokerDetails

if [ "$SB_RUNNING" -ne "1" ]; then
   echo "Service broker does not seem to be running, this may indicate that an error has occured"
   exit 1 
fi

export SOLACE_MESSAGING_FOUND=$( cf m | grep -v Getting | grep solace-messaging | wc -l )

if [ "$SOLACE_MESSAGING_FOUND" -eq "0" ]; then
    echo "solace-messaging not found in the marketplace !?"
    exit 1
fi

## See about getting some info about the installation

echo "Service broker is installed, solace-messaging is a service in the marketplace"
cf marketplace

