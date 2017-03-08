#!/bin/bash

export MY_BIN_HOME=`dirname $0`
export MY_HOME=$MY_BIN_HOME/..
export WORKSPACE=$HOME/workspace

export DEPLOYMENT_NAME=${DEPLOYMENT_NAME:-"solace-vmr-warden-deployment"}
export TEMPLATE_PREFIX=${TEMPLATE_PREFIX:-"solace-vmr-warden-deployment"}
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


function prepareManifest() {

echo "Preparing a deployment manifest from template: $TEMPLATE_FILE "

if [ ! -f $TEMPLATE_FILE ]; then
 echo "Template file not found  $TEMPALTE_FILE"
 exit 1
fi

cp $TEMPLATE_FILE $MANIFEST_FILE

echo "Preparing manifest file $MANIFEST_FILE"

## Template keys to replace
## __VMR_JOB_NAME__
## __POOL_NAME__
## __SOLACE_DOCKER_IMAGE__
## __LIST_NAME__

sed -i "s/__DEPLOYMENT_NAME__/$DEPLOYMENT_NAME/g" $MANIFEST_FILE
sed -i "s/__VMR_JOB_NAME__/$VMR_JOB_NAME/g" $MANIFEST_FILE
sed -i "s/__POOL_NAME__/$POOL_NAME/g" $MANIFEST_FILE
sed -i "s/__SOLACE_DOCKER_IMAGE__/$SOLACE_DOCKER_IMAGE/g" $MANIFEST_FILE
sed -i "s/__LIST_NAME__/$LIST_NAME/g" $MANIFEST_FILE

}

function build() {

echo "Will build the BOSH Release (May take some time)"

./build.sh | tee -a $LOG_FILE

if [ $? -ne 0 ]; then
 echo
 echo "Build failed."
 exit 1
fi 

}

function uploadAndDeployRelease() {

RELEASE_FILE=`ls $WORKSPACE/releases/solace-vmr-*.tgz | tail -1`

echo "in function uploadAndDeployRelease. RELEASE_FILE: $RELEASE_FILE"

if [ -f $RELEASE_FILE ]; then

 targetBosh

 echo "Will upload release $RELEASE_FILE"

 bosh upload release $RELEASE_FILE | tee -a $LOG_FILE

 echo "Calling bosh deployment"

 bosh deployment $MANIFEST_FILE | tee -a $LOG_FILE

 echo "Will deploy VMR with name $VMR_JOB_NAME , having POOL_NAME: $POOL_NAME, and using $SOLACE_DOCKER_IMAGE" | tee -a $LOG_FILE

 echo "yes" | bosh deploy | tee -a $LOG_FILE

else
 echo "Could not locate a release file in $WORKSPACE/releases/solace-vmr-*.tgz"
 exit 1
fi

}



###################### Common parameter processing ########################


export BASIC_USAGE_PARAMS="-p [Shared-VMR|Large-VMR|Community-VMR|Medium-HA-VMR|Large-HA-VMR] -t [cert|no-cert|ha]"

CMD_NAME=`basename $0`

function showUsage() {
  echo
  echo "Usage: $CMD_NAME $BASIC_USAGE_PARAMS " $1
  echo
}

function missingRequired() {
  echo
  echo "Some required argument(s) were missing."
  echo 

  showUsage
  exit 1
}

# if (($# == 0)); then
#   missingRequired
# fi

while getopts :p:t:h opt; do
    case $opt in
      p)
        export POOL_NAME=$OPTARG
      ;;
      t)
        export TEMPLATE_POSTFIX="-${OPTARG}"
      ;;
      h)
        showUsage
        exit 0
      ;;
      \?)
      echo
      echo "Invalid option: -$OPTARG" >&2
      echo
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

if [ -z $TEMPLATE_POSTFIX ]; then
   export TEMPLATE_POSTFIX="-cert"
fi

export VMR_JOB_NAME=${VMR_JOB_NAME:-$POOL_NAME}
export VM_JOB=${VM_JOB:-"$VMR_JOB_NAME/0"}

case $POOL_NAME in

  Shared-VMR)
	export SOLACE_DOCKER_IMAGE="latest-evaluation"
        export LIST_NAME="shared"
    ;;

  Medium-HA-VMR)
	export SOLACE_DOCKER_IMAGE="latest-evaluation"
        export LIST_NAME="medium_ha"
    ;;

  Large-VMR)
	export SOLACE_DOCKER_IMAGE="latest-evaluation"
        export LIST_NAME="large"
    ;;

  Large-HA-VMR)
	export SOLACE_DOCKER_IMAGE="latest-evaluation"
        export LIST_NAME="large_ha"
    ;;

  Community-VMR)
	export SOLACE_DOCKER_IMAGE="latest-community"
        export LIST_NAME="community"
    ;;

  *)
    echo
    echo "Sorry, I don't seem to know about POOL_NAME: $POOL_NAME"
    echo
    showUsage
    exit 1
    ;;
esac

export RELEASE_FILE=$(ls $WORKSPACE/releases/solace-vmr-*.tgz | tail -1)
export RELEASE_VERSION=$(basename $RELEASE_FILE | sed 's/solace-vmr-//g' | sed 's/.tgz//g' | awk -F\- '{ print $1 }' )

export TEMPLATE_FILE="$MY_HOME/templates/$RELEASE_VERSION/${TEMPLATE_PREFIX}${TEMPLATE_POSTFIX}.yml.template"
export MANIFEST_FILE=${MANIFEST_FILE:-"$WORKSPACE/bosh-solace-manifest.yml"}

if [ -f $TEMPLATE_FILE ]; then
 export NUM_INSTANCES=$( grep "instances:" $TEMPLATE_FILE | grep -v _vmr_instances | head -1 | awk '{ print $2 }' )
else
 export NUM_INSTANCES=0
fi


echo "$0 - Settings"
echo "    SOLACE VMR     $RELEASE_VERSION - $RELEASE_FILE"
echo "    Deployment     $DEPLOYMENT_NAME"
echo "    VMR JOB NAME   $VMR_JOB_NAME"
echo "    NUM_INSTANCES  $NUM_INSTANCES"


INSTANCE_COUNT=0
while [ "$INSTANCE_COUNT" -lt "$NUM_INSTANCES" ];  do
     echo "    VM/$INSTANCE_COUNT           $VMR_JOB_NAME/$INSTANCE_COUNT"
     let INSTANCE_COUNT=INSTANCE_COUNT+1
done

