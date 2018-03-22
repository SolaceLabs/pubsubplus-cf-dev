#!/bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKSPACE=${WORKSPACE:-$SCRIPTPATH/../workspace}

source $SCRIPTPATH/common.sh

export VM_MEMORY=${VM_MEMORY:-8192}
export VM_CPUS=${VM_CPUS:-4}
export VM_DISK_SIZE=${VM_DISK_SIZE:-"65_536"}
export VM_EPHEMERAL_DISK_SIZE=${VM_EPHEMERAL_DISK_SIZE:-"32_768"}

export BOSH_NON_INTERACTIVE=${BOSH_NON_INTERACTIVE:-true}

export TEMP_DIR=$(mktemp -d)

function cleanupWorkTemp() {
 if [ -d $TEMP_DIR ]; then
    rm -rf $TEMP_DIR
 fi
}
trap cleanupWorkTemp EXIT INT TERM HUP

if [ -f $WORKSPACE/.boshvm ]; then
   export BOSH_VM=$( cat $WORKSPACE/.boshvm )
   vboxmanage showvminfo $BOSH_VM &> $TEMP_DIR/showvminfo

   if [[ $? -eq 0 ]]; then
	vboxmanage startvm $BOSH_VM --type headless
   else
	echo "Exiting $SCRIPT: There seems to be no existing BOSH-lite VM [$BOSH_VM]"
	exit 1
   fi
else
  echo "Exiting $SCRIPT: cannot detect BOSH-lite VM, $WORKSPACE/.boshvm was not found"
  exit 1
fi
