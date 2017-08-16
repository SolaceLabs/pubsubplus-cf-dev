#!/bin/bash

export SCRIPT=$(readlink -f "$0")
export SCRIPTPATH=$(dirname "$SCRIPT")

export LOG_FILE="/tmp/bosh_deploy.log"

source "$SCRIPTPATH/commonUtils.sh"

set -e
unset COMMON_PARAMS

while getopts :m: opt; do
  case $opt in
    m)
      if (echo "$OPTARG" | grep -qE "^/.*"); then
        EXISTING_MANIFEST_FILE="$OPTARG"
      else
        EXISTING_MANIFEST_FILE="`pwd`/$OPTARG"
      fi

      if ! [ -e "$EXISTING_MANIFEST_FILE" ]; then
        echo "Manifest file cannot be found."
        exit 1
      elif ! [ -f "$EXISTING_MANIFEST_FILE" ]; then
        echo "Manifest must be a file."
        exit 1
      fi

      if [ "$(cat $EXISTING_MANIFEST_FILE | grep cert_pem | wc -l)" -le "0" ]; then
        COMMON_PARAMS+=" -n"
      fi

      JOBS_TO_DEPLOY=$(py "getManifestJobNames" $EXISTING_MANIFEST_FILE)
      for JOB_NAME in ${JOBS_TO_DEPLOY[@]}; do
        JOB=$(py "getManifestJobByName" $EXISTING_MANIFEST_FILE $JOB_NAME)
        MANIFEST_INSTANCE_CNT=`echo $JOB | shyaml get-value instances`
        POOL=`echo $JOB | shyaml get-value properties.pool_name`

        if [ "$MANIFEST_INSTANCE_CNT" -gt "0" ]; then
          if [ "$(py "getHaEnabled" $POOL)" -eq "1" ]; then
            MANIFEST_INSTANCE_CNT=$(($MANIFEST_INSTANCE_CNT / 3))
          fi

          COMMON_PARAMS+=" -p $POOL:$MANIFEST_INSTANCE_CNT"
        fi
      done
      ;;
  esac
done

OPTIND=1 #Reset getopts

SOLACE_VMR_BOSH_RELEASE_FILE_MATCHER="$WORKSPACE/releases/solace-vmr-*.tgz"
for f in $SOLACE_VMR_BOSH_RELEASE_FILE_MATCHER; do
  if ! [ -e "$f" ]; then
    echo "Could not find solace-vmr bosh release file: $SOLACE_VMR_BOSH_RELEASE_FILE_MATCHER"
    exit 1
  fi

  export SOLACE_VMR_BOSH_RELEASE_FILE="$f"
  break
done

export SOLACE_VMR_BOSH_RELEASE_VERSION=$(basename $SOLACE_VMR_BOSH_RELEASE_FILE | sed 's/solace-vmr-//g' | sed 's/.tgz//g' | awk -F\- '{ print $1 }' )

export TEMPLATE_DIR="$SCRIPTPATH/../templates/$SOLACE_VMR_BOSH_RELEASE_VERSION"
export MANIFEST_FILE=${MANIFEST_FILE:-"$WORKSPACE/bosh-solace-manifest.yml"}

echo "$0 - Settings"
echo "    SOLACE VMR     $SOLACE_VMR_BOSH_RELEASE_VERSION - $SOLACE_VMR_BOSH_RELEASE_FILE"

COMMON=${COMMON:-bosh-common.sh}
source $SCRIPTPATH/$COMMON $COMMON_PARAMS
cd $SCRIPTPATH/..

echo "Checking for existing deployment..."

DEPLOYMENT_FOUND_COUNT=`bosh deployments | grep $DEPLOYMENT_NAME | wc -l`
if [ "$DEPLOYMENT_FOUND_COUNT" -gt "0" ]; then
   echo "A bosh deployment is already done, will shutdown the running VMs..."
   echo
   POOL_NAMES=$(py "getPoolNames")
   for POOL in ${POOL_NAMES[@]}; do
      VM_FOUND_COUNT=$(bosh vms | grep $POOL | wc -l)
      echo "$POOL: Found $VM_FOUND_COUNT running VMs"
      echo
      I=0
      while [ "$I" -lt "$VM_FOUND_COUNT" ]; do
         echo "Shutting down $POOL/$I"
         shutdownVMRJobs $POOL/$I | tee $LOG_FILE
         echo
         I=$(($I+1))
      done
   done
else
   echo "No existing bosh deployment found. Continuing..."
fi

if [ -n "$EXISTING_MANIFEST_FILE" ]; then
    echo "Using existing MANIFEST_FILE=$EXISTING_MANIFEST_FILE"
    if ! [ "$EXISTING_MANIFEST_FILE" -ef "$MANIFEST_FILE" ]; then
        echo "Copying $EXISTING_MANIFEST_FILE to $MANIFEST_FILE"
        cp $EXISTING_MANIFEST_FILE $MANIFEST_FILE
    fi
    resolveConflictsAndRegenerateManifest
else
    prepareManifest
fi

echo
echo "You can see deployment logs in $LOG_FILE"

prepareBosh

uploadAndDeployRelease

setupServiceBrokerEnvironment

VMS_FOUND_COUNT=`bosh vms | grep -E $(echo ${VM_JOB[@]} | tr " " "|") | wc -l`

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

