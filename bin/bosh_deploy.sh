#!/bin/bash

export SCRIPT=$(readlink -f "$0")
export SCRIPTPATH=$(dirname "$SCRIPT")

export LOG_FILE="/tmp/bosh_deploy.log"

COMMON=${COMMON:-bosh-common.sh}
source $SCRIPTPATH/$COMMON

cd $SCRIPTPATH/..

prepareManifest

VMS_FOUND_COUNT=`bosh vms | grep -E $(echo ${VM_JOB[@]} | tr " " "|") | wc -l`
printf "\n"

if [ "$VMS_FOUND_COUNT" -gt "0" ]; then
   echo "A bosh deployment is already done, the following VMs were found:"

   for VM in ${VM_JOB[@]}; do
      echo "    $VM"
   done

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

VMS_FOUND_COUNT=`bosh vms | grep -E $(echo ${VM_JOB[@]} | tr " " "|") | wc -l`

if [ "$VMS_FOUND_COUNT" -eq "0" ]; then
   uploadAndDeployRelease
else
   echo "Skipping deployment as there are VMs that were found: $VM_JOB"
   echo "You should cleanup the deployment with bosh_cleanup.sh ?!"
fi

setupServiceBrokerEnvironment

VMS_FOUND_COUNT=`bosh vms | grep -E $(echo ${VM_JOB[@]} | tr " " "|") | wc -l`

# INSTANCE_COUNT=0
# while [ "$INSTANCE_COUNT" -lt "$NUM_INSTANCES" ];  do
#     echo "    VM/$INSTANCE_COUNT           $VMR_JOB_NAME/$INSTANCE_COUNT"
#     let INSTANCE_COUNT=INSTANCE_COUNT+1
# done

if [ "$VMS_FOUND_COUNT" -eq "${#VM_JOB[@]}" ]; then
   echo "bosh deployment is present, VMs called:"

   for VM in ${VM_JOB[@]}; do
      echo "    $VM"
   done

   echo
   echo "You can ssh to them using: bosh ssh [VM_NAME]"
   echo "  e.g. bosh ssh ${VM_JOB[0]}"
else
   for VM in ${VM_JOB[@]}; do
      VM_FOUND_COUNT = `bosh vms | grep $VM | wc -l`
      if [ "$VM_FOUND_COUNT" -eq "0" ]; then
         echo "Could not find VM called $VM"
      fi
   done
fi

