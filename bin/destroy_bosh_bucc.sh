#!/bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKSPACE=${WORKSPACE:-$SCRIPTPATH/../workspace}

source $SCRIPTPATH/common.sh

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

if [ ! -d bucc ]; then
 git clone https://github.com/starkandwayne/bucc.git
else
 (cd bucc; git pull)
fi

if [ -d $WORKSPACE/bucc/state ]; then
   $WORKSPACE/bucc/bin/bucc down 
   $WORKSPACE/bucc/bin/bucc clean
fi

if [ -f $WORKSPACE/bosh_env.sh ]; then
   rm -f $WORKSPACE/bosh_env.sh
fi

if [ -f $WORKSPACE/.bosh_env ]; then
   rm -f $WORKSPACE/.bosh_env
fi

if [ -f $WORKSPACE/deployment-vars.yml ]; then
   rm -f $WORKSPACE/deployment-vars.yml
fi

if [ -f $WORKSPACE/.boshvm ]; then
   export BOSH_VM=$( cat $WORKSPACE/.boshvm )
   vboxmanage showvminfo $BOSH_VM &> $TEMP_DIR/showvminfo

   if [[ $? -eq 0 ]]; then
        echo "Exiting $SCRIPT: The BOSH-lite VM [$BOSH_VM] is still running?"
        exit 1
   fi
   rm -f $WORKSPACE/.boshvm
   unset BOSH_VM
fi
