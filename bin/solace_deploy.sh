#! /bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $SCRIPTPATH/deploy-common.sh

## Good House Cleaning
function cleanupAfterDeploy() {
 source $SCRIPTPATH/bosh-common.sh
 deleteOrphanedDisks
}
trap cleanupAfterDeploy EXIT INT TERM HUP

checkDeploymentRequirements

BOSH_CMD="bosh -d solace_messaging deploy solace-deployment.yml $BOSH_PARAMS"

echo
echo $BOSH_CMD
echo

( cd $CF_SOLACE_MESSAGING_DEPLOYMENT_HOME; $BOSH_CMD )

[[ $? -eq 0 ]] && { 
  $SCRIPTPATH/solace_add_service_broker.sh $ERRAND_PARAMS
  [[ $? -eq 0 ]] && { 
    [[ ! -z "$SKIP_TEST" ]] || {
       $SCRIPTPATH/solace_deployment_tests.sh $ERRAND_PARAMS
    }
  }
}

exit $? 
