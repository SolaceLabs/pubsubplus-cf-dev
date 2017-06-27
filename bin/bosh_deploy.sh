#!/bin/bash

export SCRIPT=$(readlink -f "$0")
export SCRIPTPATH=$(dirname "$SCRIPT")

export LOG_FILE="/tmp/bosh_deploy.log"

COMMON=${COMMON:-bosh-common.sh}
source $SCRIPTPATH/$COMMON

cd $SCRIPTPATH/..

prepareManifest

VM_FOUND_COUNT=`bosh vms | grep $VM_JOB | wc -l`
printf "\n"

if [ "$VM_FOUND_COUNT" -eq "1" ]; then
   echo "bosh deployment is already done, the VM was found: $VM_JOB"
   echo
   echo "Will not build and will not DEPLOY"
   echo 
   echo "You should cleanup the deployment with bosh_cleanup.sh ?!"
   echo
   exit 1
fi

echo
echo "You can see deployment logs in $LOG_FILE"

prepareBosh

VM_FOUND_COUNT=`bosh vms | grep $VM_JOB | wc -l`

if [ "$VM_FOUND_COUNT" -eq "0" ]; then
   uploadAndDeployRelease
else
   echo "Skipping deployment as the VM was already found: $VM_JOB"
   echo "You should cleanup the deployment with bosh_cleanup.sh ?!"
fi

setupServiceBrokerEnvironment

VM_FOUND_COUNT=`bosh vms | grep $VM_JOB | wc -l`

# INSTANCE_COUNT=0
# while [ "$INSTANCE_COUNT" -lt "$NUM_INSTANCES" ];  do
#     echo "    VM/$INSTANCE_COUNT           $VMR_JOB_NAME/$INSTANCE_COUNT"
#     let INSTANCE_COUNT=INSTANCE_COUNT+1
# done

if [ "$VM_FOUND_COUNT" -eq "1" ]; then
   echo "bosh deployment is present, VM called $VM_JOB"
   echo "You can ssh to it:"
   echo "  bosh ssh $VM_JOB"
else
   echo "Could not find VM called $VM_JOB"
fi

