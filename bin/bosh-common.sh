#!/bin/bash

export MY_BIN_HOME=$(dirname $(readlink -f $0))
export PYTHONPATH=$MY_BIN_HOME
export MY_HOME=$MY_BIN_HOME/..

export DEPLOYMENT_NAME=${DEPLOYMENT_NAME:-"solace-vmr-warden-deployment"}
export LOG_FILE=${LOG_FILE:-"/tmp/bosh_deploy.log"}

export SOLACE_DOCKER_BOSH_VERSION="29-solace-2"
export SOLACE_DOCKER_BOSH=${SOLACE_DOCKER_BOSH:-"$WORKSPACE/releases/docker-${SOLACE_DOCKER_BOSH_VERSION}.tgz"}

export STEMCELL_VERSION="3312.24"
export STEMCELL_NAME="bosh-stemcell-$STEMCELL_VERSION-warden-boshlite-ubuntu-trusty-go_agent.tgz"
export STEMCELL_URL="https://s3.amazonaws.com/bosh-core-stemcells/warden/$STEMCELL_NAME"

function targetBosh() {

  bosh target 192.168.50.4 lite

}

function prepareBosh() {

  echo "In function prepareBosh"

  targetBosh

  FOUND_DOCKER_RELEASE=`bosh releases | grep "docker" | grep $SOLACE_DOCKER_BOSH_VERSION | wc -l`
  if [ "$FOUND_DOCKER_RELEASE" -eq "0" ]; then
     echo "Uploading docker bosh"
     bosh upload release $SOLACE_DOCKER_BOSH
  else
     echo "$SOLACE_DOCKER_BOSH was found $FOUND_DOCKER_RELEASE"
  fi

  FOUND_STEMCELL=`bosh stemcells | grep bosh-warden-boshlite-ubuntu-trusty-go_agent | grep $STEMCELL_VERSION | wc -l`
  if [ "$FOUND_STEMCELL" -eq "0" ]; then
    if [ ! -f /tmp/$STEMCELL_NAME ]; then
      echo "Downloading stemcell"
      wget -O /tmp/$STEMCELL_NAME $STEMCELL_URL
    fi
    echo "Uploading stemcell"
    bosh upload stemcell /tmp/$STEMCELL_NAME
  else
     echo "$STEMCELL_NAME was found $FOUND_STEMCELL"
  fi
}

function deleteOrphanedDisks() {

bosh disks --orphaned

ORPHANED_DISKS=`bosh disks --orphaned | grep -v "| Disk"  | grep "^|"  | awk -F\| '{ print $2 }'`

for DISK_ID in $ORPHANED_DISKS; do
	echo "Will delete $DISK_ID"
	bosh delete disk $DISK_ID
done

}

function shutdownVMRJobs() {

 echo "In shutdownVMRJobs"

 VM_JOB=$1

 echo "Looking for VM job $VM_JOB" 
 VM_FOUND_COUNT=`bosh vms | grep $VM_JOB | wc -l`
 VM_RUNNING_FOUND_COUNT=`bosh vms | grep $VM_JOB | grep running |  wc -l`
 DEPLOYMENT_FOUND_COUNT=`bosh deployments | grep $DEPLOYMENT_NAME | wc -l`
 RELEASE_FOUND_COUNT=`bosh releases | grep solace-vmr | wc -l`

 if [ "$VM_RUNNING_FOUND_COUNT" -eq "1" ]; then

   echo "Will stop monit jobs if any are running"
   bosh ssh $VM_JOB "sudo /var/vcap/bosh/bin/monit stop all" 

   RUNNING_COUNT=`bosh ssh $VM_JOB "sudo /var/vcap/bosh/bin/monit summary" | grep running | wc -l`
   MAX_WAIT=60
   while [ "$RUNNING_COUNT" -gt "0" ] && [ "$MAX_WAIT" -gt "0" ]; do
   	echo "Waiting for monit to finish shutdown - found $RUNNING_COUNT still running"
	sleep 5
        let MAX_WAIT=MAX_WAIT-5
        RUNNING_COUNT=`bosh ssh $VM_JOB "sudo /var/vcap/bosh/bin/monit summary " | grep running | wc -l`
   done

 fi

}

function shutdownAllVMRJobs() {
    local DEPLOYED_MANIFEST="$WORKSPACE/deployed-manifest.yml"
    echo "yes" | bosh download manifest $DEPLOYMENT_NAME $DEPLOYED_MANIFEST
    bosh deployment $DEPLOYED_MANIFEST
    bosh deployment
    echo "Shutting down all VMR jobs..."
    VMR_JOBS=$(py "getManifestJobNames" $DEPLOYED_MANIFEST)
    for VMR_JOB_NAME in ${VMR_JOBS[@]}; do
        VM_FOUND_COUNT=$(bosh vms | grep $VMR_JOB_NAME | wc -l)
        echo "$VMR_JOB_NAME: Found $VM_FOUND_COUNT running VMs"
        echo
        I=0
        while [ "$I" -lt "$VM_FOUND_COUNT" ]; do
            echo "Shutting down $VMR_JOB_NAME/$I"
            shutdownVMRJobs $VMR_JOB_NAME/$I | tee $LOG_FILE
            echo
            I=$(($I+1))
        done
    done
    rm $DEPLOYED_MANIFEST
}

function deleteDeploymentAndRelease() {

 DEPLOYMENT_FOUND_COUNT=`bosh deployments | grep $DEPLOYMENT_NAME | wc -l`
 RELEASE_FOUND_COUNT=`bosh releases | grep solace-vmr | wc -l`

 if [ "$DEPLOYMENT_FOUND_COUNT" -eq "1" ]; then
    # Delete the deployment 
    echo "Deleting deployment $DEPLOYMENT_NAME"
    echo "yes" | bosh delete deployment $DEPLOYMENT_NAME
 else
   echo "No deployment found."
 fi

 if [ "$RELEASE_FOUND_COUNT" -eq "1" ]; then
    # solace-vmr
    echo "Deleting release solace-vmr"
    echo "yes" | bosh delete release solace-vmr
 else
    echo "No release found"
 fi

}

function build() {

echo "Will build the BOSH Release (May take some time)"

./build.sh | tee -a $LOG_FILE

if [ $? -ne 0 ]; then
 >&2 echo
 >&2 echo "Build failed."
 exit 1
fi 

}

function getReleaseNameAndVersion() {
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
}

function uploadAndDeployRelease() {

SOLACE_VMR_BOSH_RELEASE_FILE=`ls $WORKSPACE/releases/solace-vmr-*.tgz | tail -1`
RELEASE_FOUND_COUNT=`bosh releases | grep solace-vmr | wc -l`

echo "in function uploadAndDeployRelease. SOLACE_VMR_BOSH_RELEASE_FILE: $SOLACE_VMR_BOSH_RELEASE_FILE"

if [ -f $SOLACE_VMR_BOSH_RELEASE_FILE ]; then

 targetBosh

 if [ "$RELEASE_FOUND_COUNT" -gt "0" ]; then
  local UPLOADED_RELEASE_VERSION=`2>&1 bosh releases | grep solace-vmr | grep -woP "[\w-.]+(?=\*)"`
 fi

 if [ "$RELEASE_FOUND_COUNT" -eq "0" ] || \
    [ "$SOLACE_VMR_BOSH_RELEASE_VERSION" '>' "$UPLOADED_RELEASE_VERSION" ]; then
  echo "Will upload release $SOLACE_VMR_BOSH_RELEASE_FILE"

  bosh upload release $SOLACE_VMR_BOSH_RELEASE_FILE | tee -a $LOG_FILE
 else
  echo "A solace-vmr release with version greater than or equal to $SOLACE_VMR_BOSH_RELEASE_VERSION already exists. Skipping release upload..."
 fi

 echo "Calling bosh deployment"
 echo "MANIFEST_FILE=$MANIFEST_FILE"

 bosh deployment $MANIFEST_FILE | tee -a $LOG_FILE 

 VMR_JOBS=$(py "getManifestJobNames" $MANIFEST_FILE)
 for VMR_JOB_NAME in ${VMR_JOBS[@]}; do
    JOB=$(py "getManifestJobByName" $MANIFEST_FILE $VMR_JOB_NAME)
    if [ "$(echo -n $JOB | wc -c)" -eq "0" ]; then
        continue
    fi

    POOL_NAME="$(echo -n $JOB | shyaml get-value properties.pool_name)"
    SOLACE_DOCKER_IMAGE_NAME="$(py 'getSolaceDockerImageName' $POOL_NAME)"
    echo "Will deploy VMR with name $VMR_JOB_NAME, having POOL_NAME: $POOL_NAME, and using $SOLACE_DOCKER_IMAGE_NAME" | tee -a $LOG_FILE
 done

 echo "yes" | bosh deploy | tee -a $LOG_FILE
 bosh vms
 DEPLOYMENT_FOUND_COUNT=`2>&1 bosh deployments | grep $DEPLOYMENT_NAME | wc -l`
 if [ "$DEPLOYMENT_FOUND_COUNT" -eq "0" ]; then
   >&2 echo "bosh did not find any deployments - deployment likely failed"
   exit 1
 fi

 POOL_NAMES=$(py "getPoolNames")
 FAILED_VMS_COUNT=`2>&1 bosh vms | grep -E "($(echo ${POOL_NAMES[*]} | tr ' ' '|'))/[0-9]+" | grep -v running | wc -l`
 if [ "$FAILED_VMS_COUNT" -gt "0" ]; then
   >&2 echo "Found non-running VMs - deployment likely failed"
   exit 1
 fi

else
 >&2 echo "Could not locate a release file in $WORKSPACE/releases/solace-vmr-*.tgz"
 exit 1
fi

}

function py() {
  local OP=$1 PARAMS=() CURRENT_DIR=`pwd`
  shift

  cd $MY_BIN_HOME

  while (( "$#" )); do
    if [ -n "$1" ] && (echo "$1" | grep -qE "[^0-9]"); then
      PARAMS+=("\"$1\"")
    else
      PARAMS+=($1)
    fi
    shift
  done

  python3 -c "import commonUtils; commonUtils.$OP($(IFS=$','; echo "${PARAMS[*]}"))"

  cd $CURRENT_DIR
}

