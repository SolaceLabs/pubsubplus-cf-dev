#!/bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKSPACE=${WORKSPACE:-$SCRIPTPATH/../workspace}

source $SCRIPTPATH/common.sh

export VM_MEMORY=${VM_MEMORY:-8192}
export VM_CPUS=${VM_CPUS:-4}
export VM_DISK_SIZE=${VM_DISK_SIZE:-"65_536"}

export BOSH_NON_INTERACTIVE=${BOSH_NON_INTERACTIVE:-true}

if [ ! -d $WORKSPACE ]; then
  mkdir -p $WORKSPACE
fi

cd $WORKSPACE

if [ ! -d bucc ]; then
 git clone https://github.com/starkandwayne/bucc.git
else
 (cd bucc; git pull)
fi

echo "Setting VM MEMORY to $VM_MEMORY, VM_CPUS to $VM_CPUS"
sed -i "/vm_memory:/c\vm_memory: $VM_MEMORY" $WORKSPACE/bucc/state/vars.yml
sed -i "/vm_cpus:/c\vm_cpus: $VM_CPUS/" $WORKSPACE/bucc/state/vars.yml

echo "vm_disk_size: $VM_DISK_SIZE" >> $WORKSPACE/bucc/ops/cpis/virtualbox/vars.tmpl
cp -f $SCRIPTPATH/vm-size.yml $WORKSPACE/bucc/ops/cpis/virtualbox/

$WORKSPACE/bucc/bin/bucc up --cpi virtualbox --lite --debug | tee $WORKSPACE/bucc_up.log
$WORKSPACE/bucc/bin/bucc env > $WORKSPACE/bosh_env.sh

echo
echo "Adding routes, you may need to enter your credentials to grant sudo permissions"
echo
$SCRIPTPATH/setup_bosh_routes.sh
echo
echo "Adding swap. Please accept the The authenticity of host '192.168.50.6' when requested"
echo
$SCRIPTPATH/setup_bosh_swap.sh

