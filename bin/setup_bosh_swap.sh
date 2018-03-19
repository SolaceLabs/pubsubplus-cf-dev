#!/bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKSPACE=${WORKSPACE:-$SCRIPTPATH/../workspace}

source $SCRIPTPATH/common.sh

export VM_SWAP=${VM_SWAP:-8192}

if [ ! -d $WORKSPACE ]; then
  mkdir -p $WORKSPACE
fi

cd $WORKSPACE

echo "Adding $VM_SWAP of swap space"
ssh-keygen -f ~/.ssh/known_hosts -R 192.168.50.6
$WORKSPACE/bucc/bin/bucc ssh "sudo fallocate -l ${VM_SWAP}M /var/vcap/store/swapfile"
$WORKSPACE/bucc/bin/bucc ssh "sudo chmod 600 /var/vcap/store/swapfile"
$WORKSPACE/bucc/bin/bucc ssh "sudo mkswap /var/vcap/store/swapfile"
$WORKSPACE/bucc/bin/bucc ssh "sudo swapon /var/vcap/store/swapfile"
$WORKSPACE/bucc/bin/bucc ssh "sudo swapon -s"

