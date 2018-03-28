#!/bin/bash

export DEPLOYMENT_NAME="solace_messaging"
export LOG_FILE=${LOG_FILE:-"$WORKSPACE/bosh_deploy.log"}

######################################

export BOSH_IP=${BOSH_IP:-"192.168.50.4"}
export BOSH_CMD="/usr/local/bin/bosh"
export BOSH_CLIENT=${BOSH_CLIENT:-admin}
export BOSH_CLIENT_SECRET=${BOSH_CLIENT_SECRET:-admin}
export BOSH_NON_INTERACTIVE${BOSH_NON_INTERACTIVE:-true}
export BOSH_ENVIRONMENT=${BOSH_ENVIRONMENT:-"lite"}
export STEMCELL_VERSION=${STEMCELL_VERSION:-"3541.9"}
export STEMCELL_NAME="bosh-stemcell-$STEMCELL_VERSION-warden-boshlite-ubuntu-trusty-go_agent.tgz"
export STEMCELL_URL="https://s3.amazonaws.com/bosh-core-stemcells/warden/$STEMCELL_NAME"

function targetBosh() {

  ## Setup to access target bosh-lite
    
  if [ ! -f $WORKSPACE/.env ] && [ "$BOSH_IP" == "192.168.50.4" ]; then
     # Old bosh-lite
     if [ ! -d $WORKSPACE/bosh-lite ]; then
       (cd $WORKSPACE; git clone https://github.com/cloudfoundry/bosh-lite.git)
     fi 

     # bosh target $BOSH_IP alias as 'lite'
     BOSH_TARGET_LOG=$( $BOSH_CMD alias-env lite -e $BOSH_IP --ca-cert=$WORKSPACE/bosh-lite/ca/certs/ca.crt --client=admin --client-secret=admin  )
  else
     # New bosh-lite
     BOSH_TARGET_LOG=$( $BOSH_CMD alias-env lite -e $BOSH_IP )
  fi

  if [ $? -eq 0 ]; then
     # Login will rely on BOSH_* env vars..
     BOSH_LOGIN_LOG=$( BOSH_CLIENT=$BOSH_CLIENT BOSH_CLIENT_SECRET=$BOSH_CLIENT_SECRET $BOSH_CMD log-in )
     if [ $? -eq 0 ]; then
        export BOSH_ACCESS=1
     else
        export BOSH_ACCESS=0
        echo $BOSH_LOGIN_LOG
     fi
  else
     export BOSH_ACCESS=0
     echo $BOSH_TARGET_LOG
  fi
}


function prepareBosh() { 

echo "Checking stemcell $STEMCELL_NAME"

  FOUND_STEMCELL=`bosh stemcells | grep bosh-warden-boshlite-ubuntu-trusty-go_agent | grep $STEMCELL_VERSION | wc -l`
  if [ "$FOUND_STEMCELL" -eq "0" ]; then
     if [ ! -f $WORKSPACE/$STEMCELL_NAME ]; then
        wget -O $WORKSPACE/$STEMCELL_NAME $STEMCELL_URL
     fi
     bosh upload-stemcell $WORKSPACE/$STEMCELL_NAME
  else
     echo "$STEMCELL_NAME was found $FOUND_STEMCELL"
  fi
}

function deleteOrphanedDisks() {

ORPHANED_DISKS_COUNT=$( bosh disks --orphaned --json | jq '.Tables[].Rows[] | select(.deployment | contains("solace_messaging")) | .disk_cid' | sed 's/\"//g' | wc -l )
ORPHANED_DISKS=$( bosh disks --orphaned --json | jq '.Tables[].Rows[] | select(.deployment | contains("solace_messaging")) | .disk_cid' | sed 's/\"//g' )


if [ "$ORPHANED_DISKS_COUNT" -gt "0" ]; then

 for DISK_ID in $ORPHANED_DISKS; do
        echo "Will delete $DISK_ID"
        bosh -n delete-disk $DISK_ID
        echo
        echo "Orphaned Disk $DISK_ID was deleted"
        echo
 done

else
   echo "No orphaned disks found: $ORPHANED_DISKS_COUNT"
fi

}

#################################

function shutdownVMRJobs() {

 echo "In shutdownVMRJobs"

 VM_JOB=$1

 echo "Looking for VM job $VM_JOB" 
 VM_FOUND_COUNT=`$BOSH_CMD vms | grep $VM_JOB | wc -l`
 VM_RUNNING_FOUND_COUNT=`$BOSH_CMD vms --json | jq '.Tables[].Rows[] | select(.process_state=="running") | .instance' | grep $VM_JOB |  wc -l`
 DEPLOYMENT_FOUND_COUNT=`$BOSH_CMD deployments | grep $DEPLOYMENT_NAME | wc -l`
 RELEASE_FOUND_COUNT=`$BOSH_CMD releases | grep solace-vmr | wc -l`

 if [ "$VM_RUNNING_FOUND_COUNT" -eq "1" ]; then

   echo "Will stop monit jobs if any are running on $DEPLOYMENT_NAME / $VM_JOB"
   $BOSH_CMD ssh $VM_JOB "sudo /var/vcap/bosh/bin/monit stop all" 

   RUNNING_COUNT=`$BOSH_CMD ssh $VM_JOB "sudo /var/vcap/bosh/bin/monit summary" | grep running | wc -l`
   MAX_WAIT=60
   while [ "$RUNNING_COUNT" -gt "0" ] && [ "$MAX_WAIT" -gt "0" ]; do
   	echo "Waiting for monit to finish shutdown - found $RUNNING_COUNT still running"
	sleep 5
        let MAX_WAIT=MAX_WAIT-5
        RUNNING_COUNT=`$BOSH_CMD ssh $VM_JOB "sudo /var/vcap/bosh/bin/monit summary " | grep running | wc -l`
   done
 else
  echo "Did not find running job $VM_JOB"
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
    export SOLACE_VMR_BOSH_RELEASE_VERSION_FULL=$(basename $SOLACE_VMR_BOSH_RELEASE_FILE | sed 's/solace-vmr-//g' | sed 's/.tgz//g' )
    export SOLACE_VMR_BOSH_RELEASE_VERSION=$(basename $SOLACE_VMR_BOSH_RELEASE_FILE | sed 's/solace-vmr-//g' | sed 's/.tgz//g' | awk -F\- '{ print $1 }' )
    export SOLACE_VMR_BOSH_RELEASE_VERSION_DEV=$(basename $SOLACE_VMR_BOSH_RELEASE_FILE | sed 's/solace-vmr-//g' | sed 's/.tgz//g' | awk -F\- '{ print $2 }' )
    echo "Determined SOLACE_VMR_BOSH_RELEASE_VERSION_FULL $SOLACE_VMR_BOSH_RELEASE_VERSION_FULL"
    echo "Determined SOLACE_VMR_BOSH_RELEASE_VERSION $SOLACE_VMR_BOSH_RELEASE_VERSION"
    echo "Determined SOLACE_VMR_BOSH_RELEASE_VERSION_DEV $SOLACE_VMR_BOSH_RELEASE_VERSION_DEV"


    SOLACE_MESSAGING_BOSH_RELEASE_FILE_MATCHER="$WORKSPACE/releases/solace-messaging-*.tgz"
    for f in $SOLACE_MESSAGING_BOSH_RELEASE_FILE_MATCHER; do
      if ! [ -e "$f" ]; then
        echo "Could not find solace-messaging bosh release file: $SOLACE_MESSAGING_BOSH_RELEASE_FILE_MATCHER"
        exit 1
      fi

      export SOLACE_MESSAGING_BOSH_RELEASE_FILE="$f"
      break
    done
    export SOLACE_MESSAGING_BOSH_RELEASE_VERSION_FULL=$(basename $SOLACE_MESSAGING_BOSH_RELEASE_FILE | sed 's/solace-messaging-//g' | sed 's/.tgz//g' )
    export SOLACE_MESSAGING_BOSH_RELEASE_VERSION=$(basename $SOLACE_MESSAGING_BOSH_RELEASE_FILE | sed 's/solace-messaging-//g' | sed 's/.tgz//g' | awk -F\- '{ print $1 }' )
    export SOLACE_MESSAGING_BOSH_RELEASE_VERSION_DEV=$(basename $SOLACE_MESSAGING_BOSH_RELEASE_FILE | sed 's/solace-messaging-//g' | sed 's/.tgz//g' | awk -F\- '{ print $2 }' )
    echo "Determined SOLACE_MESSAGING_BOSH_RELEASE_VERSION_FULL $SOLACE_MESSAGING_BOSH_RELEASE_VERSION_FULL"
    echo "Determined SOLACE_MESSAGING_BOSH_RELEASE_VERSION $SOLACE_MESSAGING_BOSH_RELEASE_VERSION"
    echo "Determined SOLACE_MESSAGING_BOSH_RELEASE_VERSION_DEV $SOLACE_MESSAGING_BOSH_RELEASE_VERSION_DEV"

}

function uploadReleases() {

echo "in function uploadReleases. SOLACE_MESSAGING_BOSH_RELEASE_FILE: $SOLACE_MESSAGING_BOSH_RELEASE_FILE"

SOLACE_MESSAGING_BOSH_RELEASE_FILE=${SOLACE_MESSAGING_BOSH_RELEASE_FILE:-`ls $WORKSPACE/releases/solace-messaging-*.tgz | tail -1`}
SOLACE_MESSAGING_RELEASE_FOUND_COUNT=`$BOSH_CMD releases | grep solace-messaging | wc -l`

if [ -f $SOLACE_MESSAGING_BOSH_RELEASE_FILE ]; then

 targetBosh

 if [ "$SOLACE_MESSAGING_RELEASE_FOUND_COUNT" -gt "0" ]; then
  UPLOADED_RELEASE_VERSION=`$BOSH_CMD releases | grep solace-messaging | awk '{ print $4 }'`
  # remove trailing '*'
  UPLOADED_RELEASE_VERSION="${UPLOADED_RELEASE_VERSION%\*}"
  echo "Determined solace-messaging uploaded version $UPLOADED_RELEASE_VERSION"
 fi

 if [ "$SOLACE_MESSAGING_RELEASE_FOUND_COUNT" -eq "0" ] || \
    [ "$SOLACE_MESSAGING_BOSH_RELEASE_VERSION_FULL" '>' "$UPLOADED_RELEASE_VERSION" ]; then
  echo "Will upload release $SOLACE_MESSAGING_BOSH_RELEASE_FILE"

  $BOSH_CMD upload-release $SOLACE_MESSAGING_BOSH_RELEASE_FILE | tee -a $LOG_FILE
 else
  echo "A solace-messaging release with version greater than or equal to $SOLACE_MESSAGING_BOSH_RELEASE_VERSION_FULL already exists. Skipping release upload..."
 fi

fi

SOLACE_VMR_BOSH_RELEASE_FILE=${SOLACE_VMR_BOSH_RELEASE_FILE:-`ls $WORKSPACE/releases/solace-vmr-*.tgz | tail -1`}
RELEASE_FOUND_COUNT=`$BOSH_CMD releases | grep solace-vmr | wc -l`

echo "in function uploadReleases. SOLACE_VMR_BOSH_RELEASE_FILE: $SOLACE_VMR_BOSH_RELEASE_FILE"

if [ -f $SOLACE_VMR_BOSH_RELEASE_FILE ]; then

 targetBosh

 if [ "$RELEASE_FOUND_COUNT" -gt "0" ]; then
  UPLOADED_RELEASE_VERSION=`$BOSH_CMD releases | grep solace-vmr | awk '{ print $4 }'`
  # remove trailing '*'
  UPLOADED_RELEASE_VERSION="${UPLOADED_RELEASE_VERSION%\*}"
 fi

 if [ "$RELEASE_FOUND_COUNT" -eq "0" ] || \
    [ "$SOLACE_VMR_BOSH_RELEASE_VERSION_FULL" '>' "$UPLOADED_RELEASE_VERSION" ]; then
  echo "Will upload release $SOLACE_VMR_BOSH_RELEASE_FILE"

  $BOSH_CMD upload-release $SOLACE_VMR_BOSH_RELEASE_FILE | tee -a $LOG_FILE
 else
  echo "A solace-vmr release with version greater than or equal to $SOLACE_VMR_BOSH_RELEASE_VERSION_FULL already exists. Skipping release upload..."
 fi

else
 >&2 echo "Could not locate a release file in $WORKSPACE/releases/solace-vmr-*.tgz"
 exit 1
fi

}

function deleteSolaceDeployment() {

 SOLACE_DEPLOYMENT_FOUND_COUNT=`bosh deployments | grep solace_messaging | wc -l`
 if [ "$SOLACE_DEPLOYMENT_FOUND_COUNT" -eq "1" ]; then

  bosh -d solace_messaging run-errand delete-all

  bosh -d solace_messaging delete-deployment

 else
     echo "No solace messaging deployment found: $SOLACE_DEPLOYMENT_FOUND_COUNT"
 fi

}

function deleteSolaceReleases() {

 SOLACE_VMR_RELEASE_FOUND_COUNT=`bosh releases | grep solace-vmr | wc -l`
 if [ "$SOLACE_VMR_RELEASE_FOUND_COUNT" -gt "0" ]; then
     # solace-vmr
     echo "Deleting release solace-vmr"
     bosh -n delete-release solace-vmr
 else
     echo "No solace-vmr release found: $SOLACE_VMR_RELEASE_FOUND_COUNT"
 fi

 SOLACE_MESSAGING_RELEASE_FOUND_COUNT=`bosh releases | grep solace-messaging | wc -l`
 if [ "$SOLACE_MESSAGING_RELEASE_FOUND_COUNT" -gt "0" ]; then
     # solace-messaging
     echo "Deleting release solace-messaging"
     bosh -n delete-release solace-messaging
 else
     echo "No solace-messaging release found: $SOLACE_MESSAGING_RELEASE_FOUND_COUNT"
 fi

}

