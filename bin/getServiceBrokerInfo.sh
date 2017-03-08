#!/bin/bash

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

source $SCRIPTPATH/cf-common.sh

set -e
confirmServiceBrokerRunning

checkServiceBrokerServicePlanStats

checkServiceBrokerRepoStats

getServiceBrokerRouters

showServiceBrokerRouterInventory

showServiceBrokerVMRs

