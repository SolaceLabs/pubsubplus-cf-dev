#!/bin/bash

export SCRIPT=$(readlink -f "$0")
export SCRIPTPATH=$(dirname "$SCRIPT")

export LOG_FILE="/tmp/bosh_deploy.log"

set -e
echo "Value check: Will use MANIFEST_FILE=$MANIFEST_FILE"

COMMON=${COMMON:-bosh-common.sh}
source $SCRIPTPATH/$COMMON

export SOLACE_VMR_BOSH_RELEASE_FILE=$(ls $WORKSPACE/releases/solace-vmr-*.tgz | tail -1)
export SOLACE_VMR_BOSH_RELEASE_VERSION=$(basename $SOLACE_VMR_BOSH_RELEASE_FILE | sed 's/solace-vmr-//g' | sed 's/.tgz//g' | awk -F\- '{ print $1 }' )

export TEMPLATE_DIR="$MY_HOME/templates/$SOLACE_VMR_BOSH_RELEASE_VERSION"
export MANIFEST_FILE=${MANIFEST_FILE:-"$WORKSPACE/bosh-solace-manifest.yml"}

echo "$0 - Settings"
echo "    SOLACE VMR     $SOLACE_VMR_BOSH_RELEASE_VERSION - $SOLACE_VMR_BOSH_RELEASE_FILE"
echo "    Deployment     $DEPLOYMENT_NAME"
echo

cd $SCRIPTPATH/..

if [ -z "$MANIFEST_FILE" ]; then
  prepareManifest
else
  echo "Will use MANIFEST_FILE=$MANIFEST_FILE"
fi

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

