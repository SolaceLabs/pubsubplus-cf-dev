#!/bin/bash

export SCRIPT=$(readlink -f "$0")
export SCRIPTPATH=$(dirname "$SCRIPT")

export LOG_FILE="/tmp/bosh_cleanup.log"

COMMON=${COMMON:-bosh-common.sh}
source $SCRIPTPATH/$COMMON

cd $SCRIPTPATH/..

echo "Logs in file $LOG_FILE"

INSTANCE_COUNT=0
while [ "$INSTANCE_COUNT" -lt "$NUM_INSTANCES" ];  do
     echo "Cleanup    VM/$INSTANCE_COUNT           $VMR_JOB_NAME/$INSTANCE_COUNT"
     shutdownVMRJobs $VMR_JOB_NAME/$INSTANCE_COUNT | tee $LOG_FILE
     let INSTANCE_COUNT=INSTANCE_COUNT+1
done

deleteDeploymentAndRelease | tee $LOG_FILE
deleteOrphanedDisks | tee $LOG_FILE
resetServiceBrokerEnvironment
