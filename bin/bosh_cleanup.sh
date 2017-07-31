#!/bin/bash

export SCRIPT=$(readlink -f "$0")
export SCRIPTPATH=$(dirname "$SCRIPT")

export LOG_FILE="/tmp/bosh_cleanup.log"

COMMON=${COMMON:-bosh-common.sh}
source $SCRIPTPATH/$COMMON

cd $SCRIPTPATH/..
targetBosh

echo "Logs in file $LOG_FILE"

for I in ${!VM_JOB[@]}; do
     echo
     echo "Cleanup    VM/$I           ${VM_JOB[I]}"
     shutdownVMRJobs ${VM_JOB[I]} | tee $LOG_FILE
done

deleteDeploymentAndRelease | tee $LOG_FILE
deleteOrphanedDisks | tee $LOG_FILE
resetServiceBrokerEnvironment
