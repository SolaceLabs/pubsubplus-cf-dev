#!/bin/bash

export MY_BIN_HOME=$(dirname $(readlink -f $0))
export MY_HOME=$MY_BIN_HOME/..

export DEPLOYMENT_NAME=${DEPLOYMENT_NAME:-"solace-vmr-warden-deployment"}
export LOG_FILE=${LOG_FILE:-"/tmp/bosh_deploy.log"}

export SOLACE_DOCKER_BOSH_VERSION="29-solace-2"
export SOLACE_DOCKER_BOSH=${SOLACE_DOCKER_BOSH:-"$WORKSPACE/releases/docker-${SOLACE_DOCKER_BOSH_VERSION}.tgz"}

export STEMCELL_VERSION="3312.7"
export STEMCELL_NAME="bosh-stemcell-$STEMCELL_VERSION-warden-boshlite-ubuntu-trusty-go_agent.tgz"
export STEMCELL_URL="https://s3.amazonaws.com/bosh-core-stemcells/warden/$STEMCELL_NAME"

export NUM_INSTANCES=${NUM_INSTANCES:-"1"}

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

  echo "Uploading stemcell"

  if [ ! -f /tmp/$STEMCELL_NAME ]; then
      wget -O /tmp/$STEMCELL_NAME $STEMCELL_URL
  fi

  FOUND_STEMCELL=`bosh stemcells | grep bosh-warden-boshlite-ubuntu-trusty-go_agent | grep $STEMCELL_VERSION | wc -l`
  if [ "$FOUND_STEMCELL" -eq "0" ]; then
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

function generateManifest() {

local VMR_JOB_NAME_ARG=""
local CERT_ARG=''
local HA_ARG=''
if [ -n "$VMR_JOB_NAME" ]; then
    VMR_JOB_NAME_ARG="-j $VMR_JOB_NAME"
fi
if [ "$CERT_ENABLED" == true ]; then
    CERT_ARG="--cert"
fi
if [ "$HA_ENABLED" == true ]; then
    HA_ARG="--ha"
fi
export PREPARE_MANIFEST_COMMAND="python3 ${MY_BIN_HOME}/prepareManifest.py $CERT_ARG $HA_ARG $VMR_JOB_NAME_ARG -w $WORKSPACE -s $SOLACE_DOCKER_IMAGE -p $POOL_NAME -d $TEMPLATE_DIR -n $DEPLOYMENT_NAME"
>&2 echo "Running: $PREPARE_MANIFEST_COMMAND"
${PREPARE_MANIFEST_COMMAND}

if [ $? -ne 0 ]; then
 >&2 echo
 >&2 echo "Generating the Manifest failed."
 exit 1
fi 
}

function prepareManifest() {

generateManifest > $MANIFEST_FILE

if [ $? -ne 0 ]; then
 >&2 echo
 >&2 echo "Preparing the Manifest failed."
 exit 1
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

function uploadAndDeployRelease() {

SOLACE_VMR_BOSH_RELEASE_FILE=`ls $WORKSPACE/releases/solace-vmr-*.tgz | tail -1`

echo "in function uploadAndDeployRelease. SOLACE_VMR_BOSH_RELEASE_FILE: $SOLACE_VMR_BOSH_RELEASE_FILE"

if [ -f $SOLACE_VMR_BOSH_RELEASE_FILE ]; then

 targetBosh

 echo "Will upload release $SOLACE_VMR_BOSH_RELEASE_FILE"

 bosh upload release $SOLACE_VMR_BOSH_RELEASE_FILE | tee -a $LOG_FILE

 echo "Calling bosh deployment"

 bosh deployment $MANIFEST_FILE | tee -a $LOG_FILE

 echo "Will deploy VMR with name $VMR_JOB_NAME , having POOL_NAME: $POOL_NAME, and using $SOLACE_DOCKER_IMAGE" | tee -a $LOG_FILE

 echo "yes" | bosh deploy | tee -a $LOG_FILE

else
 >&2 echo "Could not locate a release file in $WORKSPACE/releases/solace-vmr-*.tgz"
 exit 1
fi

}



###################### Common parameter processing ########################


export BASIC_USAGE_PARAMS="-p [Shared-VMR|Large-VMR|Community-VMR|Medium-HA-VMR|Large-HA-VMR] -n (To not use a self-signed certificate)"

CMD_NAME=`basename $0`

function showUsage() {
  echo
  echo "Usage: $CMD_NAME $BASIC_USAGE_PARAMS " $1
  echo
}

function missingRequired() {
  >&2 echo
  >&2 echo "Some required argument(s) were missing."
  >&2 echo 

  showUsage
  exit 1
}

# if (($# == 0)); then
#   missingRequired
# fi

while getopts :p:hn opt; do
    case $opt in
      p)
        export POOL_NAME=$OPTARG
      ;;
      n)
        export CERT_ENABLED=false
      ;;
      h)
        showUsage
        exit 0
      ;;
      \?)
      >&2 echo
      >&2 echo "Invalid option: -$OPTARG" >&2
      >&2 echo
      showUsage
      exit 1
      ;;
  esac
done

missing_required=0

if ((missing_required)); then
   missingRequired
fi

## Derived and default values

if [ -z $POOL_NAME ]; then
   export POOL_NAME="Shared-VMR"
fi

if [ -z $CERT_ENABLED ]; then
    export CERT_ENABLED=true
fi

export VMR_JOB_NAME=${VMR_JOB_NAME:-$POOL_NAME}
export VM_JOB=${VM_JOB:-"$VMR_JOB_NAME/0"}

case $POOL_NAME in

  Shared-VMR)
	export SOLACE_DOCKER_IMAGE="latest-evaluation"
    ;;

  Medium-HA-VMR)
	export SOLACE_DOCKER_IMAGE="latest-evaluation"
    ;;

  Large-VMR)
	export SOLACE_DOCKER_IMAGE="latest-evaluation"
    ;;

  Large-HA-VMR)
	export SOLACE_DOCKER_IMAGE="latest-evaluation"
    ;;

  Community-VMR)
	export SOLACE_DOCKER_IMAGE="latest-community"
    ;;

  *)
    >&2 echo
    >&2 echo "Sorry, I don't seem to know about POOL_NAME: $POOL_NAME"
    >&2 echo
    showUsage
    exit 1
    ;;
esac

if [[ "$POOL_NAME" == *"HA-VMR" ]]; then
    export HA_ENABLED=true
else
    export HA_ENABLED=false
fi

export SOLACE_VMR_BOSH_RELEASE_FILE=$(ls $WORKSPACE/releases/solace-vmr-*.tgz | tail -1)
export SOLACE_VMR_BOSH_RELEASE_VERSION=$(basename $SOLACE_VMR_BOSH_RELEASE_FILE | sed 's/solace-vmr-//g' | sed 's/.tgz//g' | awk -F\- '{ print $1 }' )

export TEMPLATE_DIR="$MY_HOME/templates/$SOLACE_VMR_BOSH_RELEASE_VERSION"
export MANIFEST_FILE=${MANIFEST_FILE:-"$WORKSPACE/bosh-solace-manifest.yml"}

export NUM_INSTANCES=$(generateManifest | grep "_vmr_instances" | head -n1 | awk '{print $2}')

echo "$0 - Settings"
echo "    SOLACE VMR     $SOLACE_VMR_BOSH_RELEASE_VERSION - $SOLACE_VMR_BOSH_RELEASE_FILE"
echo "    Deployment     $DEPLOYMENT_NAME"
echo "    VMR JOB NAME   $VMR_JOB_NAME"
echo "    CERT_ENABLED   $CERT_ENABLED"
echo "    HA_ENABLED     $HA_ENABLED"
echo "    NUM_INSTANCES  $NUM_INSTANCES"

INSTANCE_COUNT=0
while [ "$INSTANCE_COUNT" -lt "$NUM_INSTANCES" ];  do
     echo "    VM/$INSTANCE_COUNT           $VMR_JOB_NAME/$INSTANCE_COUNT"
     let INSTANCE_COUNT=INSTANCE_COUNT+1
done

