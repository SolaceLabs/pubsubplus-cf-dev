#!/bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $SCRIPTPATH/cf-common.sh

set -e
confirmServiceBrokerRunning

checkServiceBrokerServicePlanStats

showServiceBrokerVMRs

