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

if [ ! -d $WORKSPACE ]; then
  mkdir -p $WORKSPACE
fi

cd $WORKSPACE

if [ -f $WORKSPACE/.boshvm ]; then
   export BOSH_VM=$( cat $WORKSPACE/.boshvm )
   vboxmanage showvminfo $BOSH_VM &> $TEMP_DIR/showvminfo

   if [[ $? -eq 0 ]]; then
	echo "Exiting $SCRIPT: You seem to already have an existing BOSH-lite VM [$BOSH_VM]"
	exit 1
   fi
   unset BOSH_VM
fi

if [ ! -d bucc ]; then
 git clone https://github.com/starkandwayne/bucc.git
else
 (cd bucc; git pull)
fi

echo "Setting VM MEMORY to $VM_MEMORY, VM_CPUS to $VM_CPUS, VM_EPHEMERAL_DISK_SIZE to $VM_EPHEMERAL_DISK_SIZE"
sed -i "/vm_memory:/c\vm_memory: $VM_MEMORY" $WORKSPACE/bucc/ops/cpis/virtualbox/vars.tmpl
sed -i "/vm_cpus:/c\vm_cpus: $VM_CPUS" $WORKSPACE/bucc/ops/cpis/virtualbox/vars.tmpl
sed -i "/vm_ephemeral_disk:/c\vm_ephemeral_disk: $VM_EPHEMERAL_DISK_SIZE" $WORKSPACE/bucc/ops/cpis/virtualbox/vars.tmpl

echo "vm_disk_size: $VM_DISK_SIZE" >> $WORKSPACE/bucc/ops/cpis/virtualbox/vars.tmpl
cp -f $SCRIPTPATH/vm-size.yml $WORKSPACE/bucc/ops/cpis/virtualbox/

## Capture running VMS before
vboxmanage list runningvms > $TEMP_DIR/running_vms.before

$WORKSPACE/bucc/bin/bucc up --cpi virtualbox --lite --debug | tee $WORKSPACE/bucc_up.log

## Capture running VMS after
vboxmanage list runningvms > $TEMP_DIR/running_vms.after

BOSH_VM=$( diff --changed-group-format='%>' --unchanged-group-format='' $TEMP_DIR/running_vms.before $TEMP_DIR/running_vms.after | awk '{ print $1 }' | sed 's/\"//g' )

vboxmanage showvminfo $BOSH_VM &> $TEMP_DIR/showvminfo

if [[ $? -eq 0 ]]; then
   echo $BOSH_VM > $WORKSPACE/.boshvm
   echo "Running BOSH-lite VM is [$BOSH_VM] : Saved to $WORKSPACE/.boshvm"
fi

$WORKSPACE/bucc/bin/bucc env > $WORKSPACE/bosh_env.sh

source $WORKSPACE/bosh_env.sh

echo
echo "Adding routes, you may need to enter your credentials to grant sudo permissions"
echo
$SCRIPTPATH/setup_bosh_routes.sh
echo
echo "Adding swap of $VM_SWAP. You may need to accept the authenticity of host '192.168.50.6' when requested"
echo
$SCRIPTPATH/setup_bosh_swap.sh

echo
echo "TIP: To access bosh you should \"source $WORKSPACE/bosh_env.sh\""
echo
