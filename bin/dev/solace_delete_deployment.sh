#!/bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKSPACE=${WORKSPACE:-$SCRIPTPATH/../workspace}

source $SCRIPTPATH/common.sh

export BOSH_NON_INTERACTIVE=${BOSH_NON_INTERACTIVE:-true}

if [ -f $WORKSPACE/bosh_env.sh ]; then
 source $WORKSPACE/bosh_env.sh
fi

cd $SCRIPTPATH/..

DEPLOYMENT_FOUND_COUNT=`bosh deployments | grep solace_messaging | wc -l`
SOLACE_VMR_RELEASE_FOUND_COUNT=`bosh releases | grep solace-vmr | wc -l`
SOLACE_MESSAGING_RELEASE_FOUND_COUNT=`bosh releases | grep solace-messaging | wc -l`

if [ "$DEPLOYMENT_FOUND_COUNT" -eq "1" ]; then

 bosh -d solace_messaging run-errand delete-all

 bosh -d solace_messaging delete-deployment

else
    echo "No solace messaging deployment found: $DEPLOYMENT_FOUND_COUNT"
fi

if [ "$SOLACE_VMR_RELEASE_FOUND_COUNT" -gt "0" ]; then
    # solace-vmr
    echo "Deleting release solace-vmr"
    bosh -n delete-release solace-vmr
else
    echo "No solace-vmr release found: $SOLACE_VMR_RELEASE_FOUND_COUNT"
fi

if [ "$SOLACE_MESSAGING_RELEASE_FOUND_COUNT" -gt "0" ]; then
    # solace-messaging
    echo "Deleting release solace-messaging"
    bosh -n delete-release solace-messaging
else
    echo "No solace-messaging release found: $SOLACE_MESSAGING_RELEASE_FOUND_COUNT"
fi


ORPHANED_DISKS_COUNT=$( bosh disks --orphaned --json | jq '.Tables[].Rows[] | select(.deployment="solace_messaging") | .disk_cid' | sed 's/\"//g' | wc -l )
ORPHANED_DISKS=$( bosh disks --orphaned --json | jq '.Tables[].Rows[] | select(.deployment="solace_messaging") | .disk_cid' | sed 's/\"//g' )


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
