#! /bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $SCRIPTPATH/deploy-common.sh

BOSH_CMD="bosh -d solace_messaging deploy solace-deployment.yml $BOSH_PARAMS"

echo
echo $BOSH_CMD
echo

$BOSH_CMD

[[ $? -eq 0 ]] && { 
  $SCRIPTPATH/solace_add_service_broker.sh 
}

exit $? 
