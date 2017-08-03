#!/bin/bash

export SCRIPT=$(readlink -f "$0")
export SCRIPTPATH=$(dirname "$SCRIPT")

export LOG_FILE="/tmp/bosh_deploy.log"

set -e
unset COMMON_PARAMS

USE_EXISTING_MANIFEST=1

while getopts :m: opt; do
  case $opt in
    m)
      USE_EXISTING_MANIFEST=0
      if (echo "$OPTARG" | grep -qE "^/.*"); then
        MANIFEST_FILE="$OPTARG"
      else
        MANIFEST_FILE="`pwd`/$OPTARG"
      fi

      if ! [ -e "$MANIFEST_FILE" ]; then
        echo "Manifest file cannot be found."
        exit 1
      elif ! [ -f "$MANIFEST_FILE" ]; then
        echo "Manifest must be a file."
        exit 1
      fi

      if [ "$(cat $MANIFEST_FILE | grep cert_pem | wc -l)" -le "0" ]; then
        COMMON_PARAMS+=" -n"
      fi

      JOBS_TO_DEPLOY=$(python3 -c "import commonUtils; commonUtils.getManifestJobNames(\"$MANIFEST_FILE\")")
      for JOB_NAME in ${JOBS_TO_DEPLOY[@]}; do
        JOB=$(python3 -c "import commonUtils; commonUtils.getManifestJobByName(\"$MANIFEST_FILE\", \"$JOB_NAME\")")
        MANIFEST_INSTANCE_CNT=`echo $JOB | shyaml get-value instances`
        POOL=`echo $JOB | shyaml get-value properties.pool_name`

        if [ "$MANIFEST_INSTANCE_CNT" -gt "0" ]; then
          if [ "$(python3 -c "import commonUtils; commonUtils.getHaEnabled(\"$POOL\")")" -eq "1" ]; then
            MANIFEST_INSTANCE_CNT=$(($MANIFEST_INSTANCE_CNT / 3))
          fi

          COMMON_PARAMS+=" -p $POOL:$MANIFEST_INSTANCE_CNT"
        fi
      done
      ;;
  esac
done

OPTIND=1 #Reset getopts

COMMON=${COMMON:-bosh-common.sh}
source $SCRIPTPATH/$COMMON $COMMON_PARAMS
cd $SCRIPTPATH/..

if [ $USE_EXISTING_MANIFEST -eq 1 ]; then
    prepareManifest
else
    echo "Using existing MANIFEST_FILE=$MANIFEST_FILE"
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

